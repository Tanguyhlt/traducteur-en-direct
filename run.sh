#!/usr/bin/env bash
# Traducteur en direct - lancement Linux / macOS
set -e
cd "$(dirname "$0")"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERREUR] python3 introuvable. Installez Python 3.10+."
    exit 1
fi

if [ ! -d ".venv" ]; then
    echo "Création de l'environnement virtuel..."
    python3 -m venv .venv
fi

echo "Installation des dépendances (une seule fois)..."
.venv/bin/python -m pip install --upgrade pip >/dev/null
.venv/bin/python -m pip install -r requirements.txt

echo "Lancement..."
.venv/bin/python traducteur_live.py
