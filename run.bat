@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ==========================================
echo   Traducteur en direct - 100 %% local
echo ==========================================

where python >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Python n'est pas installe ou n'est pas dans le PATH.
    echo Installez Python 3.10+ depuis https://www.python.org/downloads/
    echo (cochez "Add Python to PATH" pendant l'installation)
    pause
    exit /b 1
)

if not exist ".venv\Scripts\python.exe" (
    echo Creation de l'environnement virtuel...
    python -m venv .venv
)

echo Installation des dependances (une seule fois)...
".venv\Scripts\python.exe" -m pip install --upgrade pip >nul
".venv\Scripts\python.exe" -m pip install -r requirements.txt

echo Lancement...
".venv\Scripts\python.exe" traducteur_live.py
pause
