#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Traducteur en direct — sous-titres traduits en temps réel, 100 % local.

Principe :
    micro -> reconnaissance vocale (Whisper, hors ligne)
          -> traduction (Argos Translate, hors ligne)
          -> fenêtre de sous-titres toujours affichée à l'écran.

Au premier lancement, les modèles sont téléchargés une seule fois
(dossier cache de l'utilisateur). Ensuite, tout fonctionne HORS LIGNE.

Paires de langues : japonais, anglais, espagnol, allemand, italien,
portugais, chinois -> français (voir la liste PAIRS ci-dessous).
"""

import math
import os
import queue
import sys
import threading
import time
import tkinter as tk
from tkinter import messagebox, ttk

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

LANGUE_CIBLE = "fr"  # les sous-titres sont affichés en français

# (code langue source, libellé affiché) — le code est compatible Whisper + Argos
PAIRS = [
    ("ja", "🇯🇵 Japonais  →  🇫🇷 Français"),
    ("en", "🇬🇧 Anglais   →  🇫🇷 Français"),
    ("es", "🇪🇸 Espagnol  →  🇫🇷 Français"),
    ("de", "🇩🇪 Allemand  →  🇫🇷 Français"),
    ("it", "🇮🇹 Italien   →  🇫🇷 Français"),
    ("pt", "🇵🇹 Portugais →  🇫🇷 Français"),
    ("zh", "🇨🇳 Chinois   →  🇫🇷 Français"),
]

# Sources audio possibles
SOURCES = [
    ("micro", "🎙️ Microphone (ce qui est dit)"),
    ("boucle", "🔊 Son du PC (vidéos, musique, appels…)"),
]

# Taille du modèle Whisper : tiny / base / small / medium (small = bon compromis)
MODEL_WHISPER = os.environ.get("WHISPER_MODEL", "small")

SAMPLE_RATE = 16000          # Hz, ce que Whisper attend
TAILLE_FENETRE = 8.0         # secondes d'audio analysées à chaque passe
INTERVALLE = 2.0             # secondes entre deux analyses
CHEVAUCHEMENT = 1.0          # secondes de chevauchement pour ne rien rater
MIN_AUDIO = 1.2              # durée minimale de nouveau son pour lancer une passe


# ---------------------------------------------------------------------------
# Traduction hors ligne (Argos Translate)
# ---------------------------------------------------------------------------

def assurer_packages_argos(maj_statut):
    """Télécharge (une seule fois) les modèles de traduction nécessaires.

    Stratégie : on installe « anglais -> français » plus « source -> anglais »
    pour chaque langue source ; Argos chaine alors automatiquement
    source -> anglais -> français, même sans paquet direct.
    """
    from argostranslate import package

    maj_statut("Vérification des modèles de traduction (Argos)...")
    package.update_package_index()
    installes = {(p.from_code, p.to_code) for p in package.get_installed_packages()}

    paires_requises = {("en", LANGUE_CIBLE)}
    for code, _ in PAIRS:
        if code != "en":
            paires_requises.add((code, "en"))

    manquantes = sorted(paires_requises - installes)
    total = len(manquantes)
    for i, (src, dst) in enumerate(manquantes, 1):
        maj_statut(f"Modèle de traduction {src} → {dst} ({i}/{total}) — téléchargement...")
        if hasattr(package, "install_package_for_language_pair"):
            package.install_package_for_language_pair(src, dst)
        else:  # anciennes versions d'argostranslate
            pkg = next(p for p in package.get_available_packages()
                       if p.from_code == src and p.to_code == dst)
            package.install_from_path(package.download_available_package(pkg))
    if not manquantes:
        maj_statut("Modèles de traduction déjà à jour ✔")


def traduire(texte, code_source):
    """Traduit `texte` de `code_source` vers la langue cible, hors ligne."""
    from argostranslate import translate
    return translate.translate(texte, code_source, LANGUE_CIBLE).strip()


# ---------------------------------------------------------------------------
# Reconnaissance vocale hors ligne (faster-whisper)
# ---------------------------------------------------------------------------

class ReconnaissanceVocale:
    def __init__(self, maj_statut):
        maj_statut(f"Chargement du modèle Whisper « {MODEL_WHISPER} » "
                   "(téléchargé au 1er lancement, puis hors ligne)...")
        from faster_whisper import WhisperModel
        self.modele = WhisperModel(MODEL_WHISPER, device="cpu", compute_type="int8")
        maj_statut("Modèle vocal prêt ✔")

    def transcrire(self, audio, langue):
        import numpy as np
        audio = np.asarray(audio, dtype=np.float32).reshape(-1)  # Whisper exige un 1D
        segments, _ = self.modele.transcribe(audio, language=langue, vad_filter=True)
        return " ".join(s.text.strip() for s in segments).strip()


# ---------------------------------------------------------------------------
# Capture audio (micro ou son du PC en loopback)
# ---------------------------------------------------------------------------

def lister_peripheriques(sd, source):
    """Liste (index, libellé) des périphériques utilisables pour la source."""
    retour = []
    for i, d in enumerate(sd.query_devices()):
        if source == "boucle" and d.get("max_output_channels", 0) > 0:
            retour.append((i, "🔊 " + str(d["name"])))
        elif source == "micro" and d.get("max_input_channels", 0) > 0:
            retour.append((i, "🎙️ " + str(d["name"])))
    return retour


class CaptureMicro:
    def __init__(self):
        import sounddevice as sd
        self.sd = sd
        self.file_chunks = queue.Queue()
        self.stream = None
        self._verrou = threading.Lock()
        self._tampon = []          # morceaux audio accumulés (16 kHz mono)
        self._traite = 0           # nombre d'échantillons déjà analysés
        self._rate = SAMPLE_RATE   # fréquence réelle du périphérique

    def _callback(self, indata, frames, time_info, status):
        # indata est 2D (frames, canaux) -> mono 1D, puis rééchantillonné à 16 kHz
        import numpy as np
        x = indata.astype(np.float32)
        if x.ndim == 2 and x.shape[1] > 1:
            x = x.mean(axis=1)
        else:
            x = x.reshape(-1)
        if self._rate != SAMPLE_RATE and len(x) > 1:
            n_out = max(1, int(round(len(x) * SAMPLE_RATE / self._rate)))
            x = np.interp(np.linspace(0, len(x), n_out, endpoint=False),
                          np.arange(len(x)), x).astype(np.float32)
        self.file_chunks.put(x)

    def demarrer(self, source="micro", device_index=None):
        if source == "boucle" and device_index is None:
            device_index = self.sd.default.device[1]  # sortie par défaut
        if source == "micro" and device_index is None:
            device_index = self.sd.default.device[0]  # entrée par défaut
        dev = self.sd.query_devices(device_index)
        rate = int(dev.get("default_samplerate") or SAMPLE_RATE)
        if source == "boucle":
            # loopback WASAPI : on ouvre le rendu avec SES canaux (souvent 2 / 48 kHz)
            channels = max(1, int(dev.get("max_output_channels") or 2))
        else:
            channels = 1
        try:
            self.stream = self.sd.InputStream(
                samplerate=rate, channels=channels, dtype="float32",
                blocksize=1024, device=device_index, callback=self._callback)
        except Exception:
            # repli : 2 canaux / 48 kHz (config loopback la plus courante)
            rate, channels = 48000, 2
            try:
                self.stream = self.sd.InputStream(
                    samplerate=rate, channels=channels, dtype="float32",
                    blocksize=1024, device=device_index, callback=self._callback)
            except Exception as exc:
                raise RuntimeError(
                    "Capture impossible sur « " + str(dev.get("name")) + " » (" + str(exc) + "). "
                    "Solutions : (1) activez « Mixage stéréo » (Panneau de son → Enregistrement), ou "
                    "(2) installez VB-Cable et choisissez « CABLE Output » dans la liste des périphériques.") from exc
        self._rate = rate
        self.stream.start()

    def arreter(self):
        if self.stream is not None:
            self.stream.stop()
            self.stream.close()
            self.stream = None

    def nouveau_audio(self):
        """Retourne (fenêtre à analyser, nouveau son disponible) en float32."""
        import numpy as np
        with self._verrou:
            while not self.file_chunks.empty():
                self._tampon.append(self.file_chunks.get())
            if not self._tampon:
                return None, 0.0
            audio = np.concatenate(self._tampon).reshape(-1)  # toujours 1D pour Whisper
            # on garde seulement la fenêtre utile
            max_ech = int(SAMPLE_RATE * TAILLE_FENETRE)
            if len(audio) > max_ech:
                audio = audio[-max_ech:]
                self._traite = max(self._traite, len(audio) - max_ech)
            nouveau = audio[self._traite:]
            if len(nouveau) >= int(SAMPLE_RATE * MIN_AUDIO):
                # chevauchement d'une seconde pour ne rien couper
                self._traite = max(0, len(audio) - int(SAMPLE_RATE * CHEVAUCHEMENT))
                return audio, len(nouveau) / SAMPLE_RATE
            return None, 0.0


# ---------------------------------------------------------------------------
# Application (interface + boucle de travail)
# ---------------------------------------------------------------------------

class Application:
    def __init__(self, root):
        self.root = root
        self.root.title("Traducteur en direct — 100 % local")
        self.root.geometry("460x400")
        self.root.resizable(False, False)

        self.en_marche = False
        self._stop = threading.Event()
        self.fil_ui = queue.Queue()
        self.capture = None
        self.stt = None
        self.langue = PAIRS[0][0]
        self.source = SOURCES[0][0]

        # --- panneau de contrôle ---
        tk.Label(root, text="🎙️ Traducteur en direct",
                 font=("Segoe UI", 14, "bold")).pack(pady=(12, 4))
        tk.Label(root, text="Sous-titres traduits en français, hors ligne",
                 font=("Segoe UI", 9)).pack()

        tk.Label(root, text="Source audio :", font=("Segoe UI", 9)).pack(pady=(6, 0))
        self.choix_source = ttk.Combobox(root, state="readonly", width=38,
                                         values=[lib for _, lib in SOURCES])
        self.choix_source.current(1)  # son du PC par défaut (vidéos)
        self.choix_source.pack(pady=2)
        self.choix_source.bind("<<ComboboxSelected>>", self._changer_source)

        tk.Label(root, text="Périphérique audio :", font=("Segoe UI", 9)).pack(pady=(6, 0))
        self.choix_device = ttk.Combobox(root, state="readonly", width=38, values=[])
        self.choix_device.pack(pady=2)
        self.choix_device.bind("<<ComboboxSelected>>", self._changer_device)
        self._devices = []
        self.device_index = None

        tk.Label(root, text="Langue parlée :", font=("Segoe UI", 9)).pack(pady=(6, 0))
        self.choix = ttk.Combobox(root, state="readonly", width=38,
                                  values=[lib for _, lib in PAIRS])
        self.choix.current(1)  # anglais par défaut
        self.choix.pack(pady=2)
        self.choix.bind("<<ComboboxSelected>>", self._changer_langue)
        self._changer_source()  # initialise la source + la liste des périphériques

        self.bouton = tk.Button(root, text="▶  Démarrer", width=20,
                                font=("Segoe UI", 11, "bold"),
                                command=self._basculer)
        self.bouton.pack(pady=4)

        self.statut = tk.Label(root, text="Prêt. Choisissez une langue puis démarrez.",
                               font=("Segoe UI", 9), fg="#555", wraplength=420)
        self.statut.pack(pady=6)

        self.dernier = tk.Label(root, text="", font=("Segoe UI", 9, "italic"),
                                fg="#333", wraplength=420)
        self.dernier.pack(pady=(0, 8))

        # --- fenêtre de sous-titres (toujours au-dessus) ---
        self.fenetre_sous_titres = tk.Toplevel(root)
        self.fenetre_sous_titres.withdraw()
        self.fenetre_sous_titres.attributes("-topmost", True)
        self.fenetre_sous_titres.attributes("-alpha", 0.88)
        self.fenetre_sous_titres.configure(bg="black")
        self.texte_st = tk.Label(self.fenetre_sous_titres, text="",
                                 bg="black", fg="white",
                                 font=("Segoe UI", 22, "bold"),
                                 wraplength=900, justify="center", padx=24, pady=14)
        self.texte_st.pack()
        self._placer_sous_titres()

        self.root.protocol("WM_DELETE_WINDOW", self._quitter)
        self.root.after(100, self._poll_ui)

    def _placer_sous_titres(self):
        self.fenetre_sous_titres.update_idletasks()
        largeur = self.root.winfo_screenwidth()
        x = max(0, (largeur - 960) // 2)
        y = self.root.winfo_screenheight() - 220
        self.fenetre_sous_titres.geometry(f"960x180+{x}+{max(0, y)}")

    def _changer_langue(self, _event=None):
        idx = self.choix.current()
        if 0 <= idx < len(PAIRS):
            self.langue = PAIRS[idx][0]

    def _changer_source(self, _event=None):
        idx = self.choix_source.current()
        if 0 <= idx < len(SOURCES):
            self.source = SOURCES[idx][0]
        self._remplir_devices()

    def _remplir_devices(self):
        import sounddevice as sd
        self._devices = lister_peripheriques(sd, self.source)
        self.choix_device["values"] = [lib for _, lib in self._devices]
        defaut = sd.default.device[1] if self.source == "boucle" else sd.default.device[0]
        choix = None
        for i, (idx, _lib) in enumerate(self._devices):
            if idx == defaut:
                choix = i
        if choix is None and self._devices:
            choix = 0
        if choix is not None:
            self.choix_device.current(choix)
            self.device_index = self._devices[choix][0]

    def _changer_device(self, _event=None):
        idx = self.choix_device.current()
        if 0 <= idx < len(self._devices):
            self.device_index = self._devices[idx][0]

    def _maj_statut(self, texte):
        self.fil_ui.put(("statut", texte))

    def _basculer(self):
        if self.en_marche:
            self._arreter()
        else:
            self._demarrer()

    def _demarrer(self):
        self._stop.clear()
        self.en_marche = True
        self.bouton.config(text="⏹  Arrêter")
        self.fenetre_sous_titres.deiconify()
        self.texte_st.config(text="Écoute en cours…")
        threading.Thread(target=self._boucle, daemon=True).start()

    def _arreter(self):
        self.en_marche = False
        self._stop.set()
        if self.capture is not None:
            self.capture.arreter()
        self.bouton.config(text="▶  Démarrer")
        self.fenetre_sous_titres.withdraw()
        self._maj_statut("Arrêté.")

    def _boucle(self):
        try:
            assurer_packages_argos(self._maj_statut)
            self.stt = ReconnaissanceVocale(self._maj_statut)
            self.capture = CaptureMicro()
            if self.source == "boucle":
                self._maj_statut("🔊 Capture du son du PC (vidéos)… lancez une vidéo !")
            else:
                self._maj_statut("🎙️ Micro ouvert — parlez !")
            self.capture.demarrer(self.source, self.device_index)
            while not self._stop.is_set():
                time.sleep(INTERVALLE)
                if not self.en_marche or self.capture is None:
                    continue
                fenetre, nouveau = self.capture.nouveau_audio()
                if fenetre is None:
                    continue
                import numpy as np
                rms = float(np.sqrt(np.mean(fenetre.astype(np.float64) ** 2)))
                self.fil_ui.put(("niveau", 20 * math.log10(rms + 1e-9)))
                texte_src = self.stt.transcrire(fenetre, self.langue)
                if not texte_src:
                    continue
                texte_fr = traduire(texte_src, self.langue)
                self.fil_ui.put(("sous_titre", texte_src, texte_fr))
        except Exception as exc:  # ex : pas de micro, pas de son
            self.fil_ui.put(("erreur", str(exc)))

    def _poll_ui(self):
        try:
            while True:
                msg = self.fil_ui.get_nowait()
                if msg[0] == "statut":
                    self.statut.config(text=msg[1])
                elif msg[0] == "niveau":
                    db = msg[1]
                    if db < -55:
                        self.statut.config(text=f"⚠️ Aucun son détecté ({db:.0f} dB) — la vidéo joue-t-elle ? Bon périphérique choisi ?")
                    else:
                        self.statut.config(text=f"🔊 Niveau audio : {db:.0f} dB — écoute en cours…")
                elif msg[0] == "sous_titre":
                    _, src, fr = msg
                    self.texte_st.config(text=fr)
                    self.dernier.config(text=f"{src}  →  {fr}")
                elif msg[0] == "erreur":
                    self.en_marche = False
                    self.bouton.config(text="▶  Démarrer")
                    messagebox.showerror("Erreur", msg[1])
        except queue.Empty:
            pass
        self.root.after(100, self._poll_ui)

    def _quitter(self):
        self._arreter()
        self.root.destroy()


def main():
    try:
        import numpy  # noqa: F401
        import sounddevice  # noqa: F401
        import faster_whisper  # noqa: F401
        import argostranslate  # noqa: F401
    except ImportError:
        print("Dépendances manquantes. Lancez d'abord :  pip install -r requirements.txt")
        print("Ou double-cliquez simplement sur run.bat (Windows) / run.sh (Linux, Mac).")
        input("Appuyez sur Entrée pour quitter...")
        sys.exit(1)
    root = tk.Tk()
    Application(root)
    root.mainloop()


if __name__ == "__main__":
    main()
