@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "LOG=%~dp0\_build.log"
echo [%date% %time%] build_exe.bat > "%LOG%"
echo ==========================================
echo   Creation de traducteur_live.exe
echo ==========================================

set "PY="
where python >nul 2>nul && set "PY=python"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )
if not defined PY (
    echo [ERREUR] Aucun Python trouve - installez Python 3.10+ avec "Add python.exe to PATH". >> "%LOG%"
    echo [ERREUR] Aucun Python trouve - installez Python 3.10+ (python.org, cochez "Add python.exe to PATH").
    pause
    exit /b 1
)
%PY% --version >> "%LOG%" 2>&1
%PY% --version

rem --- dependances + pyinstaller, UNE SEULE FOIS, sans venv ---
%PY% -c "import faster_whisper, argostranslate, sounddevice, numpy, PyInstaller" >nul 2>>"%LOG%"
if errorlevel 1 (
    echo Installation dependances + pyinstaller (une seule fois)... >> "%LOG%"
    echo Installation dependances + pyinstaller (une seule fois)...
    %PY% -m pip install --user -r requirements.txt pyinstaller >> "%LOG%" 2>&1
    if errorlevel 1 %PY% -m pip install -r requirements.txt pyinstaller >> "%LOG%" 2>&1
)

echo Compilation de l'exe (plusieurs minutes)... >> "%LOG%"
echo Compilation de l'exe (plusieurs minutes)...
%PY% -m PyInstaller --onefile --noconsole --name traducteur_live traducteur_live.py >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERREUR] Compilation echouee - voir _build.log >> "%LOG%"
    echo [ERREUR] Compilation echouee - lisez _build.log
    pause
    exit /b 1
)

if exist "dist\traducteur_live.exe" (
    echo [OK] Executable cree : %~dp0dist\traducteur_live.exe >> "%LOG%"
    echo [OK] Executable cree : %~dp0dist\traducteur_live.exe
    dir dist\traducteur_live.exe
) else (
    echo [ERREUR] dist\traducteur_live.exe introuvable - voir _build.log >> "%LOG%"
    echo [ERREUR] exe introuvable - lisez _build.log
)
pause
