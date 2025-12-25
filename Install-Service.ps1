# Install WireGuard Network Monitor as Windows Service
# Run this script as Administrator

#Requires -RunAsAdministrator

$ServiceName = "WireGuardNetworkMonitor"
$ServiceDisplayName = "WireGuard Network Monitor"
$ServiceDescription = "Automatically connects WireGuard VPN when not on home network"
$ScriptPath = "$PSScriptRoot\WireGuardNetworkMonitor.ps1"
$NSSMPath = "$PSScriptRoot\nssm.exe"

Write-Host "=== WireGuard Network Monitor Service Installer ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if script exists
if (!(Test-Path $ScriptPath)) {
    Write-Host "ERROR: WireGuardNetworkMonitor.ps1 not found at: $ScriptPath" -ForegroundColor Red
    exit 1
}

# Check if WireGuard is installed
$wireguardPath = "C:\Program Files\WireGuard\wireguard.exe"
if (!(Test-Path $wireguardPath)) {
    Write-Host "ERROR: WireGuard not found at: $wireguardPath" -ForegroundColor Red
    Write-Host "Please install WireGuard from: https://www.wireguard.com/install/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 1: Checking for existing service..." -ForegroundColor Yellow
$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "Service already exists. Stopping and removing..." -ForegroundColor Yellow
    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    
    if (Test-Path $NSSMPath) {
        & $NSSMPath remove $ServiceName confirm
    } else {
        # Try using sc.exe if NSSM is not available
        sc.exe delete $ServiceName
    }
    Start-Sleep -Seconds 2
}

Write-Host "Step 2: Downloading NSSM (Non-Sucking Service Manager)..." -ForegroundColor Yellow
if (!(Test-Path $NSSMPath)) {
    try {
        # Download NSSM
        $nssmZip = "$PSScriptRoot\nssm.zip"
        $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        
        Write-Host "Downloading NSSM from $nssmUrl..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
        
        # Extract NSSM
        Expand-Archive -Path $nssmZip -DestinationPath $PSScriptRoot -Force
        
        # Copy the appropriate version
        if ([Environment]::Is64BitOperatingSystem) {
            Copy-Item "$PSScriptRoot\nssm-2.24\win64\nssm.exe" -Destination $NSSMPath
        } else {
            Copy-Item "$PSScriptRoot\nssm-2.24\win32\nssm.exe" -Destination $NSSMPath
        }
        
        # Cleanup
        Remove-Item $nssmZip -Force
        Remove-Item "$PSScriptRoot\nssm-2.24" -Recurse -Force
        
        Write-Host "NSSM downloaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to download NSSM: $_" -ForegroundColor Red
        Write-Host "Please download NSSM manually from https://nssm.cc/download and place nssm.exe in: $PSScriptRoot" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Step 3: Installing service with NSSM..." -ForegroundColor Yellow
$nssmInstallArgs = @(
    "install",
    $ServiceName,
    "powershell.exe",
    "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`""
)

& $NSSMPath @nssmInstallArgs

# Configure service
& $NSSMPath set $ServiceName DisplayName "$ServiceDisplayName"
& $NSSMPath set $ServiceName Description "$ServiceDescription"
& $NSSMPath set $ServiceName Start SERVICE_AUTO_START
& $NSSMPath set $ServiceName AppStdout "C:\ProgramData\WireGuardMonitor\service-output.log"
& $NSSMPath set $ServiceName AppStderr "C:\ProgramData\WireGuardMonitor\service-error.log"
& $NSSMPath set $ServiceName AppRotateFiles 1
& $NSSMPath set $ServiceName AppRotateBytes 1048576

Write-Host "Step 4: Configuring network settings..." -ForegroundColor Yellow
Write-Host ""

# Detect current network SSID
$detectedSSID = "Unknown"
try {
    $wifiProfiles = netsh wlan show interfaces
    if ($wifiProfiles -match "SSID\s+:\s+(.+)") {
        $detectedSSID = $matches[1].Trim()
    }
} catch {
    Write-Host "Warning: Could not detect WiFi SSID" -ForegroundColor Yellow
}

# Detect current gateway
$detectedGateway = "Unknown"
try {
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
               Select-Object -First 1).NextHop
    if ($gateway) {
        $detectedGateway = $gateway
    }
} catch {
    Write-Host "Warning: Could not detect gateway" -ForegroundColor Yellow
}

# Display detected settings
Write-Host "Detected Network Settings:" -ForegroundColor Cyan
Write-Host "  Current WiFi SSID: $detectedSSID" -ForegroundColor White
Write-Host "  Current Gateway: $detectedGateway" -ForegroundColor White
Write-Host ""

# Confirm with user
$useDetected = Read-Host "Use these settings as your home network? (Y/N)"
if ($useDetected -eq "Y" -or $useDetected -eq "y") {
    $homeSSID = $detectedSSID
    $homeGateway = $detectedGateway
} else {
    Write-Host ""
    $homeSSID = Read-Host "Enter your home WiFi SSID"
    $homeGateway = Read-Host "Enter your home gateway IP (e.g., 192.168.1.1)"
}

# Get WireGuard interface name
Write-Host ""
Write-Host "Available WireGuard tunnels:" -ForegroundColor Cyan
$wgServices = Get-Service -Name "WireGuardTunnel*" -ErrorAction SilentlyContinue
if ($wgServices) {
    foreach ($svc in $wgServices) {
        $tunnelName = $svc.Name -replace "WireGuardTunnel\$", ""
        Write-Host "  - $tunnelName" -ForegroundColor White
    }
} else {
    Write-Host "  No WireGuard tunnels found" -ForegroundColor Yellow
}
Write-Host ""
$wgInterface = Read-Host "Enter your WireGuard tunnel name (e.g., wg0)"

# Update WireGuardNetworkMonitor.ps1 with detected settings
Write-Host ""
Write-Host "Updating configuration in WireGuardNetworkMonitor.ps1..." -ForegroundColor Yellow

$configContent = Get-Content $ScriptPath -Raw
$configContent = $configContent -replace '\$HomeNetworkSSID = ".*?"', "`$HomeNetworkSSID = `"$homeSSID`""
$configContent = $configContent -replace '\$HomeNetworkGateway = ".*?"', "`$HomeNetworkGateway = `"$homeGateway`""
$configContent = $configContent -replace '\$WireGuardInterface = ".*?"', "`$WireGuardInterface = `"$wgInterface`""
Set-Content -Path $ScriptPath -Value $configContent

Write-Host "Configuration updated successfully!" -ForegroundColor Green
Write-Host ""

Write-Host "Step 5: Starting service..." -ForegroundColor Yellow
Start-Service -Name $ServiceName

Start-Sleep -Seconds 2

$service = Get-Service -Name $ServiceName
if ($service.Status -eq "Running") {
    Write-Host ""
    Write-Host "=== Installation Complete ===" -ForegroundColor Green
    Write-Host "Service Name: $ServiceName" -ForegroundColor Cyan
    Write-Host "Status: Running" -ForegroundColor Green
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Home WiFi SSID: $homeSSID" -ForegroundColor White
    Write-Host "  Home Gateway: $homeGateway" -ForegroundColor White
    Write-Host "  WireGuard Interface: $wgInterface" -ForegroundColor White
    Write-Host ""
    Write-Host "Log Location: C:\ProgramData\WireGuardMonitor\monitor.log" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "WARNING: Service installed but not running!" -ForegroundColor Yellow
    Write-Host "Status: $($service.Status)" -ForegroundColor Red
    Write-Host "Check logs at: C:\ProgramData\WireGuardMonitor\" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Cyan
Write-Host "  View service status: Get-Service $ServiceName" -ForegroundColor Gray
Write-Host "  Stop service: Stop-Service $ServiceName" -ForegroundColor Gray
Write-Host "  Start service: Start-Service $ServiceName" -ForegroundColor Gray
Write-Host "  View logs: Get-Content C:\ProgramData\WireGuardMonitor\monitor.log -Tail 50 -Wait" -ForegroundColor Gray
Write-Host "  Uninstall: .\Uninstall-Service.ps1" -ForegroundColor Gray
