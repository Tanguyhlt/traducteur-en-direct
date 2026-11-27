@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ==========================================
echo   Creation de traducteur_live.exe
echo   (application Windows autonome, 1 fichier)
echo ==========================================

where python >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Python introuvable dans le PATH.
    echo Installez Python 3.10+ depuis https://www.python.org/downloads/ (cochez "Add Python to PATH")
    pause
    exit /b 1
)

set "PY=python"
if not exist ".venv\Scripts\python.exe" python -m venv .venv
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if errorlevel 1 ".venv\Scripts\python.exe" -m ensurepip --upgrade >nul 2>nul
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if not errorlevel 1 set "PY=.venv\Scripts\python.exe"
)

rem --- Installe UNIQUEMENT si manquant (1ere fois seulement) ---
%PY% -c "import faster_whisper, argostranslate, sounddevice, numpy, PyInstaller" >nul 2>nul
if errorlevel 1 (
    echo Installation des dependances + pyinstaller (une seule fois)...
    %PY% -m pip install -r requirements.txt pyinstaller
    if errorlevel 1 (
        echo [ATTENTION] echec avec %PY% - reessai en mode utilisateur...
        python -m pip install --user -r requirements.txt pyinstaller
        if errorlevel 1 (
            echo [ERREUR] pip indisponible. Lancez d'abord : python -m ensurepip --upgrade
            pause
            exit /b 1
        )
        set "PY=python"
    )
) else (
    echo Dependances deja presentes - compilation directe.
)

echo Compilation de l'exe (peut prendre plusieurs minutes)...
%PY% -m PyInstaller --onefile --noconsole --name traducteur_live traducteur_live.py
if errorlevel 1 (
    echo [ERREUR] Compilation echouee.
    pause
    exit /b 1
)

if exist "dist\traducteur_live.exe" (
    echo [OK] Executable cree : dist\traducteur_live.exe
) else (
    echo [ERREUR] dist\traducteur_live.exe introuvable.
)
pause
