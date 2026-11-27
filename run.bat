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
    echo Cochez "Add Python to PATH" pendant l'installation.
    pause
    exit /b 1
)

rem --- Choix de l'interpreteur : venv si pip y fonctionne, sinon python direct ---
set "PY=python"
if not exist ".venv\Scripts\python.exe" (
    echo Creation de l'environnement virtuel...
    python -m venv .venv
)
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if errorlevel 1 ".venv\Scripts\python.exe" -m ensurepip --upgrade >nul 2>nul
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if not errorlevel 1 set "PY=.venv\Scripts\python.exe"
)

echo Installation des dependances (une seule fois)...
%PY% -m pip install --upgrade pip
%PY% -m pip install -r requirements.txt
if errorlevel 1 (
    echo [ATTENTION] pip inutilisable avec %PY% - reessai en mode utilisateur...
    python -m pip install --user -r requirements.txt
    if errorlevel 1 (
        echo [ERREUR] pip introuvable. Lancez d'abord : python -m ensurepip --upgrade
        pause
        exit /b 1
    )
    set "PY=python"
)

echo Lancement...
%PY% traducteur_live.py
pause
