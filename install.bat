@echo off
REM BerserkMC Windows Installer Launcher
REM Double-click this file to install BerserkMC

powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if %ERRORLEVEL% neq 0 (
    echo.
    echo Installation echouee. Appuyez sur une touche pour fermer.
    pause >nul
)
