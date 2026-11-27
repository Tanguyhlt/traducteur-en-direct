@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "LOG=%~dp0\_tout.log"
echo [%date% %time%] TOUT_EN_UN.bat > "%LOG%"
echo ==========================================
echo   Traducteur en direct - 100 %% local
echo ==========================================

rem --- trouve un Python 3.10+ : d'abord 'python', sinon le lanceur 'py -3' ---
set "PY="
where python >nul 2>nul && set "PY=python"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )
if not defined PY (
    echo [ERREUR] Aucun Python trouve. >> "%LOG%"
    echo [ERREUR] Aucun Python trouve (ni 'python' ni 'py').
    echo Installez Python 3.10+ depuis https://www.python.org/downloads/ en cochant "Add python.exe to PATH".
    pause
    exit /b 1
)
%PY% --version >> "%LOG%" 2>&1
%PY% --version
%PY% -c "import sys; assert sys.version_info >= (3,10)" >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERREUR] Python 3.10+ requis (version ci-dessus). >> "%LOG%"
    echo [ERREUR] Python 3.10+ requis.
    pause
    exit /b 1
)

rem --- installe les dependances UNE SEULE FOIS (mode utilisateur, pas de venv) ---
%PY% -c "import faster_whisper, argostranslate, sounddevice, numpy" >nul 2>>"%LOG%"
if errorlevel 1 (
    echo Installation des dependances (une seule fois, quelques minutes)... >> "%LOG%"
    echo Installation des dependances (une seule fois, quelques minutes)...
    %PY% -m pip install --user -r requirements.txt >> "%LOG%" 2>&1
    if errorlevel 1 %PY% -m pip install -r requirements.txt >> "%LOG%" 2>&1
    if errorlevel 1 (
        %PY% -m ensurepip --upgrade >> "%LOG%" 2>&1
        %PY% -m pip install -r requirements.txt >> "%LOG%" 2>&1
    )
    %PY% -c "import faster_whisper, argostranslate, sounddevice, numpy" >nul 2>>"%LOG%"
    if errorlevel 1 (
        echo [ERREUR] Dependances non installees - voir _tout.log >> "%LOG%"
        echo [ERREUR] Installation echouee - lisez _tout.log dans ce dossier.
        pause
        exit /b 1
    )
) else (
    echo Dependances deja OK - lancement direct. >> "%LOG%"
    echo Dependances deja OK - lancement direct.
)

echo Lancement de l'application... >> "%LOG%"
%PY% traducteur_live.py >> "%LOG%" 2>&1
echo Code retour: %errorlevel% >> "%LOG%"
echo Si l'application ne s'est pas ouverte, lisez _tout.log dans ce dossier.
pause
