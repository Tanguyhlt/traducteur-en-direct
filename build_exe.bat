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
    pause
    exit /b 1
)

if not exist ".venv\Scripts\python.exe" python -m venv .venv
".venv\Scripts\python.exe" -m pip install -r requirements.txt pyinstaller

".venv\Scripts\pyinstaller.exe" --onefile --noconsole --name traducteur_live traducteur_live.py

echo.
echo [OK] Executable cree : dist\traducteur_live.exe
pause
