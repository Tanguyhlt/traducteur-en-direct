@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Lancement direct de l'application...
where python >nul 2>nul && (python traducteur_live.py) || (py -3 traducteur_live.py)
pause
