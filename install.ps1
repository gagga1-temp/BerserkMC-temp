# BerserkMC Windows Installer (PowerShell)
# Usage: .\install.ps1 [-InstallDir "C:\Program Files\BerserkMC"] [-CreateDesktopShortcut] [-CreateStartMenuShortcut]
#
# This script installs BerserkMC from the portable dist\BerserkMC folder
# without requiring Inno Setup or NSIS.

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\BerserkMC",
    [switch]$CreateDesktopShortcut,
    [switch]$CreateStartMenuShortcut,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$SourceDir = Join-Path $PSScriptRoot "dist\BerserkMC"
$ExeName = "BerserkMC.exe"

if ($Uninstall) {
    Write-Host "Desinstallation de BerserkMC..." -ForegroundColor Yellow
    if (Test-Path $InstallDir) {
        # Stop running process
        Get-Process -Name "BerserkMC" -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
        Remove-Item -Recurse -Force $InstallDir
        Write-Host "Dossier supprime: $InstallDir" -ForegroundColor Green
    }
    # Remove shortcuts
    $desktopLink = Join-Path $env:USERPROFILE "Desktop\BerserkMC.lnk"
    if (Test-Path $desktopLink) { Remove-Item $desktopLink }
    $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\BerserkMC"
    if (Test-Path $startMenuDir) { Remove-Item -Recurse -Force $startMenuDir }
    Write-Host "Desinstallation terminee." -ForegroundColor Green
    exit 0
}

# Validate source
if (-not (Test-Path (Join-Path $SourceDir $ExeName))) {
    Write-Host "ERREUR: $SourceDir\$ExeName introuvable." -ForegroundColor Red
    Write-Host "Lancez d'abord package-release.sh pour generer le dossier portable." -ForegroundColor Yellow
    exit 1
}

Write-Host "Installation de BerserkMC dans $InstallDir..." -ForegroundColor Cyan

# Stop running process
Get-Process -Name "BerserkMC" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# Create install directory
if (Test-Path $InstallDir) {
    Write-Host "Dossier existant, mise a jour..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $InstallDir
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# Copy files
Write-Host "Copie des fichiers..." -ForegroundColor Cyan
Copy-Item -Path "$SourceDir\*" -Destination $InstallDir -Recurse -Force
Write-Host "Fichiers copies." -ForegroundColor Green

# Create desktop shortcut
if ($CreateDesktopShortcut -or $true) {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut((Join-Path $env:USERPROFILE "Desktop\BerserkMC.lnk"))
    $sc.TargetPath = Join-Path $InstallDir $ExeName
    $sc.WorkingDirectory = $InstallDir
    $sc.IconLocation = (Join-Path $InstallDir $ExeName) + ",0"
    $sc.Save()
    Write-Host "Raccourci bureau cree." -ForegroundColor Green
}

# Create Start Menu shortcut
if ($CreateStartMenuShortcut -or $true) {
    $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\BerserkMC"
    New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut((Join-Path $startMenuDir "BerserkMC.lnk"))
    $sc.TargetPath = Join-Path $InstallDir $ExeName
    $sc.WorkingDirectory = $InstallDir
    $sc.IconLocation = (Join-Path $InstallDir $ExeName) + ",0"
    $sc.Save()
    Write-Host "Raccourci menu Demarrer cree." -ForegroundColor Green
}

# Create uninstaller registry entry
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
Set-ItemProperty -Path $regPath -Name "DisplayName" -Value "BerserkMC"
Set-ItemProperty -Path $regPath -Name "UninstallString" -Value "powershell -ExecutionPolicy Bypass -File `"$PSScriptRoot\install.ps1`" -Uninstall -InstallDir `"$InstallDir`""
Set-ItemProperty -Path $regPath -Name "InstallLocation" -Value $InstallDir
Set-ItemProperty -Path $regPath -Name "DisplayIcon" -Value (Join-Path $InstallDir $ExeName)
Set-ItemProperty -Path $regPath -Name "Publisher" -Value "BerserkMC Contributors"
Set-ItemProperty -Path $regPath -Name "NoModify" -Value 1
Set-ItemProperty -Path $regPath -Name "NoRepair" -Value 1

Write-Host ""
Write-Host "Installation terminee avec succes !" -ForegroundColor Green
Write-Host "BerserkMC est installe dans: $InstallDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pour desinstaller: .\install.ps1 -Uninstall" -ForegroundColor Yellow
