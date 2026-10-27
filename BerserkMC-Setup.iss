; BerserkMC Windows Installer Script (Inno Setup 6)
; Compile with: ISCC.exe BerserkMC-Setup.iss
; Produces: BerserkMC-Setup.exe
;
; Requirements:
;   - Inno Setup 6 installed (https://jrsoftware.org/isdl.php)
;   - dist\BerserkMC\ populated by package-release.sh

#define MyAppName "BerserkMC"
#define MyAppVersion "1.6"
#define MyAppPublisher "BerserkMC Contributors"
#define MyAppURL "https://github.com/gagga1/BerserkMC"
#define MyAppExeName "BerserkMC.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
LicenseFile=COPYING.md
OutputDir=dist
OutputBaseFilename=BerserkMC-Setup
SetupIconFile=branding\BerserkMC.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
Source: "dist\BerserkMC\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\jars"
Type: filesandordirs; Name: "{app}\platforms"
Type: filesandordirs; Name: "{app}\imageformats"
Type: filesandordirs; Name: "{app}\iconengines"

[Code]
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
