; Inno Setup Script for AI Agent Desktop Notifier (anoti)
#define MyAppName "AI Agent Desktop Notifier"
#define MyAppVersion "1.3.1"
#define MyAppPublisher "SonNX24042005"
#define MyAppURL "https://github.com/SonNX24042005/agent-notifier"
#define MyAppExeName "anoti.exe"

[Setup]
AppId={{E6F7A189-9A0B-48F2-B2A8-4A59CE90D2C1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\ai-agent-desktop-notifier
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=anoti-setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\dist\anoti\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
; Add {app} to User Path in HKCU
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Check: NeedsAddPath(ExpandConstant('{app}'))

[Code]
function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Uppercase(Param) + ';', ';' + Uppercase(OrigPath) + ';') = 0;
end;

[Run]
Filename: "{app}\anoti.exe"; Parameters: "setup-hooks"; Flags: runhidden

[UninstallRun]
Filename: "{app}\anoti.exe"; Parameters: "uninstall"; Flags: runhidden

