# 🎙️ Traducteur en direct — sous-titres traduits en temps réel, 100 % local

Application Windows qui **écoute le micro**, reconnaît la parole, **traduit en direct** et affiche des **sous-titres en français** dans une fenêtre toujours visible à l'écran.

> 🔒 **Aucune donnée ne quitte votre PC** : la reconnaissance vocale (Whisper) et la traduction (Argos Translate) tournent entièrement en local. Au tout premier lancement, les modèles sont téléchargés une seule fois ; ensuite, l'application fonctionne **hors ligne**.

## 🗣️ Paires de langues disponibles (sous-titres toujours en français)

| Source | Sous-titres |
|---|---|
| 🇯🇵 Japonais | 🇫🇷 Français |
| 🇬🇧 Anglais | 🇫🇷 Français |
| 🇪🇸 Espagnol | 🇫🇷 Français |
| 🇩🇪 Allemand | 🇫🇷 Français |
| 🇮🇹 Italien | 🇫🇷 Français |
| 🇵🇹 Portugais | 🇫🇷 Français |
| 🇨🇳 Chinois | 🇫🇷 Français |

La paire se change dans la liste déroulante, même pendant l'écoute.
Pour ajouter d'autres langues : modifiez la liste `PAIRS` dans `traducteur_live.py`.

## ▶️ Utilisation (Windows — le plus simple)

1. Téléchargez le **ZIP de la release** (bouton *Releases* → dernière version → asset `.zip`) et décompressez-le dans `D:\projet traducteur`.
2. **Prérequis** : Python 3.10+ installé depuis [python.org](https://www.python.org/downloads/) (case « Add Python to PATH » cochée).
3. Double-cliquez sur **`run.bat`** : l'environnement s'installe automatiquement, puis l'application se lance.
4. Choisissez la langue parlée, cliquez sur **▶ Démarrer**, parlez : les sous-titres traduits s'affichent en bas de l'écran.

> Linux / macOS : `chmod +x run.sh && ./run.sh`

## 🧊 Créer un vrai fichier .exe (optionnel)

Double-cliquez sur **`build_exe.bat`** sur votre PC Windows :
l'exécutable autonome `dist\traducteur_live.exe` est alors créé (aucun Python requis ensuite, les modèles se téléchargent au 1er lancement du .exe).

## ⚙️ Fonctionnement

```
micro ──▶ faster-whisper (reconnaissance vocale, local)
      ──▶ argostranslate (traduction, local, chaînage via l'anglais si besoin)
      ──▶ fenêtre de sous-titres tkinter (toujours au-dessus)
```

- Fenêtre d'analyse : 8 s d'audio, nouvelle passe toutes les 2 s.
- Taille du modèle vocal : variable d'environnement `WHISPER_MODEL` (`tiny`, `base`, `small`, `medium`…), `small` par défaut.

## 📁 Fichiers

| Fichier | Rôle |
|---|---|
| `traducteur_live.py` | Application complète (une seule fichier) |
| `requirements.txt` | Dépendances Python |
| `run.bat` / `run.sh` | Lancement en un double-clic |
| `build_exe.bat` | Compilation en `.exe` autonome (Windows) |

## 📝 Licence

Projet personnel — libre d'utilisation et de modification.
