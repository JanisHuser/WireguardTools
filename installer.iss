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

; Architecture
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; PowerShell Scripts
Source: "WireGuardNetworkMonitor.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Uninstall-Service.ps1"; DestDir: "{app}"; Flags: ignoreversion

; Documentation
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
; Start Menu Shortcuts
Name: "{group}\View Logs"; Filename: "powershell.exe"; Parameters: "-NoExit -Command ""Get-Content 'C:\ProgramData\WireGuardMonitor\monitor.log' -Tail 50 -Wait"""; IconFilename: "{sys}\imageres.dll"; IconIndex: 2; Comment: "View service logs in real-time"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; IconFilename: "{sys}\imageres.dll"; IconIndex: 78

[Code]
var
  ConfigFilePage: TInputFileWizardPage;
  NetworkConfigPage: TInputQueryWizardPage;
  ResultCode: Integer;
  WireGuardConfigPath: String;
  TunnelName: String;
  DetectedSSID: String;

function DetectSSID: String;
var
  ResultCode: Integer;
  OutputFile: String;
  Lines: TArrayOfString;
  I: Integer;
  Line: String;
begin
  Result := '';
  OutputFile := ExpandConstant('{tmp}\ssid_output.txt');

  if Exec('cmd.exe', '/c netsh wlan show interfaces > "' + OutputFile + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if LoadStringsFromFile(OutputFile, Lines) then
    begin
      for I := 0 to GetArrayLength(Lines) - 1 do
      begin
        Line := Trim(Lines[I]);
        if Pos('SSID', Line) = 1 then
        begin
          Delete(Line, 1, Pos(':', Line));
          Result := Trim(Line);
          Break;
        end;
      end;
    end;
    DeleteFile(OutputFile);
  end;
end;

procedure InitializeWizard;
begin
  // Create a page to select WireGuard config file
  ConfigFilePage := CreateInputFilePage(wpSelectTasks,
    'WireGuard Configuration', 'Select your WireGuard tunnel configuration file',
    'Please select the .conf file for your WireGuard tunnel. This will be installed and used by the monitor service.');
  ConfigFilePage.Add('WireGuard configuration file:',
    'WireGuard Config Files|*.conf|All Files|*.*',
    '.conf');

  // Create network configuration page
  NetworkConfigPage := CreateInputQueryPage(ConfigFilePage.ID,
    'Network Configuration', 'Configure your home WiFi network',
    'The service will connect WireGuard when you are NOT on this WiFi network.');

  NetworkConfigPage.Add('Home WiFi SSID (case-sensitive):', False);
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = NetworkConfigPage.ID then
  begin
    // Auto-detect SSID when the page is shown
    DetectedSSID := DetectSSID;

    if DetectedSSID <> '' then
      NetworkConfigPage.Values[0] := DetectedSSID
    else
      NetworkConfigPage.Values[0] := 'YourHomeWiFiName';
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  SourceConfigFile: String;
  DestConfigFile: String;
  FileName: String;
begin
  Result := '';

  // Check if WireGuard is installed
  if not FileExists(ExpandConstant('{pf}\WireGuard\wireguard.exe')) then
  begin
    Result := 'WireGuard is not installed on this system.' + #13#10 +
              'Please install WireGuard first from: https://www.wireguard.com/install/' + #13#10#13#10 +
              'Installation will continue, but the service will not work until WireGuard is installed.';
    Exit;
  end;

  // Get the selected config file
  SourceConfigFile := ConfigFilePage.Values[0];

  if SourceConfigFile <> '' then
  begin
    // Extract filename without extension for tunnel name
    FileName := ExtractFileName(SourceConfigFile);
    TunnelName := Copy(FileName, 1, Length(FileName) - Length(ExtractFileExt(FileName)));

    // Create WireGuard config directory if it doesn't exist
    WireGuardConfigPath := ExpandConstant('{pf}\WireGuard\Data\Configurations');
    if not DirExists(WireGuardConfigPath) then
      ForceDirectories(WireGuardConfigPath);

    // Copy the config file
    DestConfigFile := WireGuardConfigPath + '\' + FileName;

    if FileExists(DestConfigFile) then
    begin
      if MsgBox('A configuration file with the name "' + FileName + '" already exists. Do you want to overwrite it?',
                mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := 'Installation cancelled. Configuration file already exists.';
        Exit;
      end;
    end;

    try
      FileCopy(SourceConfigFile, DestConfigFile, False);
      Log('Config file copied from: ' + SourceConfigFile + ' to: ' + DestConfigFile);
    except
      Result := 'Failed to copy configuration file. Please check permissions.';
      Exit;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigPath: String;
  UpdateScript: String;
  BackupConfigPath: String;
  InstallServiceScript: String;
  HomeSSID: String;
begin
  if CurStep = ssPostInstall then
  begin
    HomeSSID := NetworkConfigPage.Values[0];

    // Update WireGuardNetworkMonitor.ps1 with all configuration
    if TunnelName <> '' then
    begin
      ConfigPath := WireGuardConfigPath + '\' + TunnelName + '.conf';

      // Copy the config file to the installation directory as backup
      BackupConfigPath := ExpandConstant('{app}\' + TunnelName + '.conf');
      if FileExists(ConfigPath) then
      begin
        FileCopy(ConfigPath, BackupConfigPath, False);
        Log('Config file backed up to: ' + BackupConfigPath);
      end;

      // Create a temporary PowerShell script to update all configuration
      UpdateScript := ExpandConstant('{tmp}\update_config.ps1');
      SaveStringToFile(UpdateScript,
        '$configFile = "' + ExpandConstant('{app}\WireGuardNetworkMonitor.ps1') + '"' + #13#10 +
        '$configPath = "' + ConfigPath + '"' + #13#10 +
        '$content = Get-Content $configFile -Raw' + #13#10 +
        '$content = $content -replace ''\$HomeNetworkSSID = ".*?"'', ''$HomeNetworkSSID = "' + HomeSSID + '"''' + #13#10 +
        '$content = $content -replace ''\$WireGuardConfigPath = ".*?"'', ''$WireGuardConfigPath = "'' + $configPath + ''"''' + #13#10 +
        'Set-Content -Path $configFile -Value $content', False);

      Exec('powershell.exe',
           '-ExecutionPolicy Bypass -NoProfile -File "' + UpdateScript + '"',
           '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

      DeleteFile(UpdateScript);

      // Create installation script
      InstallServiceScript := ExpandConstant('{tmp}\install_service.ps1');
      SaveStringToFile(InstallServiceScript,
        '$ErrorActionPreference = "Continue"' + #13#10 +
        '$ServiceName = "WireGuardNetworkMonitor"' + #13#10 +
        '$ScriptPath = "' + ExpandConstant('{app}\WireGuardNetworkMonitor.ps1') + '"' + #13#10 +
        '$NSSMPath = "' + ExpandConstant('{app}\nssm.exe') + '"' + #13#10 +
        '$LogFile = "C:\ProgramData\WireGuardMonitor\install.log"' + #13#10 +
        'New-Item -ItemType Directory -Path "C:\ProgramData\WireGuardMonitor" -Force | Out-Null' + #13#10 +
        'function Write-InstallLog { param($msg) "$(Get-Date -f ''yyyy-MM-dd HH:mm:ss'') - $msg" | Out-File -Append $LogFile }' + #13#10 +
        'Write-InstallLog "Starting service installation"' + #13#10 +
        '' + #13#10 +
        'if (!(Test-Path $NSSMPath)) {' + #13#10 +
        '    Write-InstallLog "Downloading NSSM..."' + #13#10 +
        '    try {' + #13#10 +
        '        $nssmZip = "' + ExpandConstant('{tmp}') + '\nssm.zip"' + #13#10 +
        '        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip -UseBasicParsing' + #13#10 +
        '        Expand-Archive -Path $nssmZip -DestinationPath "' + ExpandConstant('{tmp}') + '" -Force' + #13#10 +
        '        Copy-Item "' + ExpandConstant('{tmp}') + '\nssm-2.24\win64\nssm.exe" -Destination $NSSMPath' + #13#10 +
        '        Write-InstallLog "NSSM downloaded successfully"' + #13#10 +
        '    } catch {' + #13#10 +
        '        Write-InstallLog "ERROR downloading NSSM: $_"' + #13#10 +
        '        exit 1' + #13#10 +
        '    }' + #13#10 +
        '}' + #13#10 +
        '' + #13#10 +
        '$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue' + #13#10 +
        'if ($existing) {' + #13#10 +
        '    Write-InstallLog "Removing existing service"' + #13#10 +
        '    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue' + #13#10 +
        '    Start-Sleep -Seconds 2' + #13#10 +
        '    & $NSSMPath remove $ServiceName confirm' + #13#10 +
        '    Start-Sleep -Seconds 2' + #13#10 +
        '}' + #13#10 +
        '' + #13#10 +
        'Write-InstallLog "Installing service with NSSM"' + #13#10 +
        '& $NSSMPath install $ServiceName powershell.exe "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`""' + #13#10 +
        '& $NSSMPath set $ServiceName DisplayName "WireGuard Network Monitor"' + #13#10 +
        '& $NSSMPath set $ServiceName Description "Automatically connects WireGuard VPN when not on home network"' + #13#10 +
        '& $NSSMPath set $ServiceName Start SERVICE_AUTO_START' + #13#10 +
        '& $NSSMPath set $ServiceName AppStdout "C:\ProgramData\WireGuardMonitor\service.log"' + #13#10 +
        '& $NSSMPath set $ServiceName AppStderr "C:\ProgramData\WireGuardMonitor\error.log"' + #13#10 +
        '& $NSSMPath set $ServiceName AppRotateFiles 1' + #13#10 +
        '& $NSSMPath set $ServiceName AppRotateBytes 1048576' + #13#10 +
        'Write-InstallLog "Starting service"' + #13#10 +
        'Start-Service -Name $ServiceName' + #13#10 +
        '$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue' + #13#10 +
        'if ($svc.Status -eq "Running") { Write-InstallLog "Service started successfully" } else { Write-InstallLog "WARNING: Service status is $($svc.Status)" }', False);
    end;
  end;
end;

function GetTunnelName(Param: String): String;
begin
  Result := TunnelName;
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
; Install and start service after installation
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{tmp}\install_service.ps1"""; Description: "Install and start the WireGuard Network Monitor service"; Flags: postinstall runhidden

[UninstallDelete]
; Clean up downloaded NSSM if it exists
Type: files; Name: "{app}\nssm.exe"
Type: files; Name: "{app}\nssm.zip"
Type: dirifempty; Name: "{app}"
