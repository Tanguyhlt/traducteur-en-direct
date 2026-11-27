@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "LOG=%~dp0\_build.log"
echo [%date% %time%] Lancement build_exe.bat > "%LOG%"
echo ==========================================
echo   Creation de traducteur_live.exe
echo ==========================================

where python >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Python introuvable dans le PATH. >> "%LOG%"
    echo [ERREUR] Python introuvable dans le PATH - installez Python 3.10+ avec "Add Python to PATH".
    pause
    exit /b 1
)
python --version >> "%LOG%" 2>&1
python --version

set "PY=python"
if not exist ".venv\Scripts\python.exe" python -m venv .venv >> "%LOG%" 2>&1
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if errorlevel 1 ".venv\Scripts\python.exe" -m ensurepip --upgrade >> "%LOG%" 2>nul
    ".venv\Scripts\python.exe" -m pip --version >nul 2>nul
    if not errorlevel 1 set "PY=.venv\Scripts\python.exe"
)

rem --- installe UNIQUEMENT si manquant ---
%PY% -c "import faster_whisper, argostranslate, sounddevice, numpy, PyInstaller" >nul 2>>"%LOG%"
if errorlevel 1 (
    echo Installation des dependances + pyinstaller (une seule fois)... >> "%LOG%"
    echo Installation des dependances + pyinstaller (une seule fois)...
    %PY% -m pip install -r requirements.txt pyinstaller >> "%LOG%" 2>&1
    if errorlevel 1 (
        echo [ATTENTION] venv inutilisable - reessai en mode utilisateur... >> "%LOG%"
        python -m pip install --user -r requirements.txt pyinstaller >> "%LOG%" 2>&1
        if errorlevel 1 (
            echo [ERREUR] Installation echouee - journal: %LOG% >> "%LOG%"
            echo [ERREUR] Installation echouee - voir _build.log
            pause
            exit /b 1
        )
        set "PY=python"
    )
) else (
    echo Dependances deja presentes - compilation directe. >> "%LOG%"
    echo Dependances deja presentes - compilation directe.
)

echo Compilation de l'exe (plusieurs minutes)... >> "%LOG%"
echo Compilation de l'exe (plusieurs minutes)...
%PY% -m PyInstaller --onefile --noconsole --name traducteur_live traducteur_live.py >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERREUR] Compilation echouee - journal: %LOG% >> "%LOG%"
    echo [ERREUR] Compilation echouee - voir _build.log
    pause
    exit /b 1
)

if exist "dist\traducteur_live.exe" (
    echo [OK] Executable cree : %~dp0dist\traducteur_live.exe >> "%LOG%"
    echo [OK] Executable cree : %~dp0dist\traducteur_live.exe
    dir dist\traducteur_live.exe
) else (
    echo [ERREUR] dist\traducteur_live.exe introuvable - voir _build.log >> "%LOG%"
    echo [ERREUR] exe introuvable - voir _build.log
)
pause
