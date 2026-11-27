@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Lancement direct de l'application...
if exist ".venv\Scripts\python.exe" (
    ".venv\Scripts\python.exe" traducteur_live.py
) else (
    python traducteur_live.py
)
echo Code retour: %errorlevel% - si l'app ne s'est pas ouverte, relancez run.bat et envoyez _lancement.log
pause
