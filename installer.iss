; WireGuard Network Monitor Installer
; InnoSetup Script
; Compile with InnoSetup 6 or later (https://jrsoftware.org/isdl.php)

#define MyAppName "WireGuard Network Monitor"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Janis Huser"
#define MyAppURL "https://github.com/JanisHuser/WireguardTools"

[Setup]
; Application Information
AppId={{A3F8E9C1-2D4B-4A5C-8E7F-1B2C3D4E5F6A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Installation Directories
DefaultDirName={autopf}\WireGuardMonitor
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Privileges and Requirements
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Output Configuration
OutputDir=installer_output
OutputBaseFilename=WireGuardNetworkMonitor-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes

; Visual Configuration
WizardStyle=modern
SetupIconFile=compiler:SetupClassicIcon.ico
UninstallDisplayIcon={app}\WireGuardNetworkMonitor.ps1

; License and Information
LicenseFile=LICENSE.txt
InfoBeforeFile=README.md

; Architecture
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; PowerShell Scripts
Source: "WireGuardNetworkMonitor.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Install-Service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Uninstall-Service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Test-WireGuard.ps1"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
; Start Menu Shortcuts
Name: "{group}\Configure WireGuard Monitor"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Install-Service.ps1"""; IconFilename: "{sys}\imageres.dll"; IconIndex: 1; Comment: "Install and configure the WireGuard Network Monitor service"
Name: "{group}\Uninstall Service"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Uninstall-Service.ps1"""; IconFilename: "{sys}\imageres.dll"; IconIndex: 78; Comment: "Remove the WireGuard Network Monitor service"
Name: "{group}\View Logs"; Filename: "powershell.exe"; Parameters: "-NoExit -Command ""Get-Content 'C:\ProgramData\WireGuardMonitor\monitor.log' -Tail 50 -Wait"""; IconFilename: "{sys}\imageres.dll"; IconIndex: 2; Comment: "View service logs in real-time"
Name: "{group}\Test WireGuard"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\Test-WireGuard.ps1"""; IconFilename: "{sys}\imageres.dll"; IconIndex: 76; Comment: "Test WireGuard connection"
Name: "{group}\Open Installation Folder"; Filename: "{app}"; IconFilename: "{sys}\imageres.dll"; IconIndex: 3
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; IconFilename: "{sys}\imageres.dll"; IconIndex: 78

[Code]
var
  InstallServicePage: TInputOptionWizardPage;
  ResultCode: Integer;

procedure InitializeWizard;
begin
  // Create a custom page asking if user wants to install service now
  InstallServicePage := CreateInputOptionPage(wpSelectTasks,
    'Service Installation', 'Do you want to install and configure the service now?',
    'The installer can automatically configure and start the WireGuard Network Monitor service. ' +
    'If you choose "No", you can run the installation later from the Start Menu.',
    True, False);
  InstallServicePage.Add('Install and configure the service now (Recommended)');
  InstallServicePage.Add('Skip service installation (I will configure it manually later)');
  InstallServicePage.Values[0] := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';

  // Check if WireGuard is installed
  if not FileExists(ExpandConstant('{pf}\WireGuard\wireguard.exe')) then
  begin
    Result := 'WireGuard is not installed on this system.' + #13#10 +
              'Please install WireGuard first from: https://www.wireguard.com/install/' + #13#10#13#10 +
              'Installation will continue, but the service will not work until WireGuard is installed.';
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // If user chose to install service now
    if InstallServicePage.Values[0] then
    begin
      // Run Install-Service.ps1 with admin privileges
      if Exec('powershell.exe',
              '-ExecutionPolicy Bypass -NoProfile -File "' + ExpandConstant('{app}\Install-Service.ps1') + '"',
              '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      begin
        if ResultCode = 0 then
          MsgBox('Service installation completed successfully!', mbInformation, MB_OK)
        else
          MsgBox('Service installation encountered some issues. Please check the installation window for details.', mbError, MB_OK);
      end
      else
        MsgBox('Failed to run service installation script.', mbError, MB_OK);
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  UninstallResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    // Ask user if they want to remove the service
    if MsgBox('Do you want to remove the WireGuard Network Monitor service?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      Exec('powershell.exe',
           '-ExecutionPolicy Bypass -NoProfile -File "' + ExpandConstant('{app}\Uninstall-Service.ps1') + '"',
           '', SW_SHOW, ewWaitUntilTerminated, UninstallResultCode);
    end;

    // Ask if user wants to remove logs
    if MsgBox('Do you want to remove log files from C:\ProgramData\WireGuardMonitor?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      DelTree(ExpandConstant('{commonappdata}\WireGuardMonitor'), True, True, True);
    end;
  end;
end;

[Run]
; Open README after installation (optional)
Filename: "{app}\README.md"; Description: "View the README file"; Flags: postinstall shellexec skipifsilent unchecked

[UninstallDelete]
; Clean up downloaded NSSM if it exists
Type: files; Name: "{app}\nssm.exe"
Type: files; Name: "{app}\nssm.zip"
Type: dirifempty; Name: "{app}"
