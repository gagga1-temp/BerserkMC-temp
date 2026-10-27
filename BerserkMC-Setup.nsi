; BerserkMC Windows Installer (NSIS 3.x)
; Compile with: makensis.exe BerserkMC-Setup.nsi
; Produces: BerserkMC-Setup.exe

!include "MUI2.nsh"

;--------------------------------
; General

Name "BerserkMC"
OutFile "dist\BerserkMC-Setup.exe"
Unicode True
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\BerserkMC"
InstallDirRegKey HKCU "Software\BerserkMC" "InstallDir"

;--------------------------------
; Version info

VIProductVersion "1.6.0.0"
VIAddVersionKey "ProductName" "BerserkMC"
VIAddVersionKey "CompanyName" "BerserkMC Contributors"
VIAddVersionKey "LegalCopyright" "Apache License 2.0"
VIAddVersionKey "FileDescription" "BerserkMC Installer"
VIAddVersionKey "FileVersion" "1.6.0.0"

;--------------------------------
; Interface Settings

!define MUI_ABORTWARNING
!define MUI_ICON "branding\BerserkMC.ico"
!define MUI_UNICON "branding\BerserkMC.ico"

;--------------------------------
; Pages

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "COPYING.md"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
; Languages

!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Installer Sections

Section "BerserkMC (required)" SecMain
  SectionIn RO

  SetOutPath "$INSTDIR"

  ; Copy all files from dist\BerserkMC
  File /r "dist\BerserkMC\*.*"

  ; Store install dir
  WriteRegStr HKCU "Software\BerserkMC" "InstallDir" "$INSTDIR"

  ; Create uninstaller
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Add to Add/Remove Programs
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "DisplayName" "BerserkMC"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "DisplayIcon" "$INSTDIR\BerserkMC.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "Publisher" "BerserkMC Contributors"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC" "NoRepair" 1

  ; Create shortcuts
  CreateDirectory "$SMPROGRAMS\BerserkMC"
  CreateShortCut "$SMPROGRAMS\BerserkMC\BerserkMC.lnk" "$INSTDIR\BerserkMC.exe" "" "$INSTDIR\BerserkMC.exe" 0
  CreateShortCut "$SMPROGRAMS\BerserkMC\Desinstaller.lnk" "$INSTDIR\Uninstall.exe"

  ; Desktop shortcut (optional, ask user)
  CreateShortCut "$DESKTOP\BerserkMC.lnk" "$INSTDIR\BerserkMC.exe" "" "$INSTDIR\BerserkMC.exe" 0

SectionEnd

;--------------------------------
; Uninstaller Section

Section "Uninstall"
  ; Stop running process
  ExecWait 'taskkill /F /IM BerserkMC.exe' $0

  ; Remove files
  RMDir /r "$INSTDIR\qml"
  RMDir /r "$INSTDIR\jars"
  RMDir /r "$INSTDIR\platforms"
  RMDir /r "$INSTDIR\imageformats"
  RMDir /r "$INSTDIR\iconengines"
  RMDir /r "$INSTDIR\translations"

  ; Remove main exe and dlls
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\*.exe"
  Delete "$INSTDIR\*.txt"
  Delete "$INSTDIR\*.md"

  ; Remove entire install dir
  RMDir /r "$INSTDIR"

  ; Remove shortcuts
  Delete "$DESKTOP\BerserkMC.lnk"
  RMDir /r "$SMPROGRAMS\BerserkMC"

  ; Remove registry
  DeleteRegKey HKCU "Software\BerserkMC"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\BerserkMC"

SectionEnd
