@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "LOG=%~dp0\_lancement.log"
echo [%date% %time%] Lancement run.bat > "%LOG%"

where python >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Python introuvable dans le PATH. >> "%LOG%"
    echo [ERREUR] Python introuvable dans le PATH.
    echo Installez Python 3.10+ (https://www.python.org/downloads/) et cochez "Add Python to PATH".
    pause
    exit /b 1
)
python --version >> "%LOG%" 2>&1
python --version

rem --- venv si possible ---
set "PY=python"
if not exist ".venv\Scripts\python.exe" (
    echo Creation du venv... >> "%LOG%"
    python -m venv .venv >> "%LOG%" 2>&1
)
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if errorlevel 1 ".venv\Scripts\python.exe" -m ensurepip --upgrade >> "%LOG%" 2>nul
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if not errorlevel 1 set "PY=.venv\Scripts\python.exe"
)

rem --- Python 3.10+ requis ---
%PY% -c "import sys; assert sys.version_info >= (3,10), sys.version" >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERREUR] Python 3.10+ requis (version ci-dessus). >> "%LOG%"
    echo [ERREUR] Python 3.10+ requis - voir %LOG%
    pause
    exit /b 1
)

rem --- installe les dependances UNIQUEMENT si elles manquent ---
%PY% -c "import faster_whisper, argostranslate, sounddevice, numpy" >nul 2>>"%LOG%"
if errorlevel 1 (
    echo Installation des dependances (une seule fois)... >> "%LOG%"
    echo Installation des dependances (une seule fois)...
    %PY% -m pip install -r requirements.txt >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo [ATTENTION] venv inutilisable - reessai en mode utilisateur... >> "%LOG%"
        python -m pip install --user -r requirements.txt >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo [ERREUR] Installation pip echouee - journal: %LOG% >> "%LOG%"
            echo [ERREUR] Installation echouee - voir le fichier _lancement.log
            pause
            exit /b 1
        )
        set "PY=python"
    )
) else (
    echo Dependances deja presentes - lancement direct. >> "%LOG%"
    echo Dependances deja presentes - lancement direct.
)

echo Lancement de l'application... >> "%LOG%"
%PY% traducteur_live.py >> "%LOG%" 2>&1
echo Code retour application: %errorlevel% >> "%LOG%"
echo Journal enregistre dans: %LOG%
pause
