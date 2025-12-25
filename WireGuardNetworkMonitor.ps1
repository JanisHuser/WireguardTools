# WireGuard Network Monitor Service
# This script monitors network connections and activates WireGuard when not on home network

# Configuration - MODIFY THESE VALUES
$HomeNetworkSSID = "YourHomeWiFiName"  # Your home WiFi SSID (case-sensitive)
$WireGuardConfigPath = "C:\Program Files\WireGuard\Data\Configurations\wg0.conf"  # Full path to your WireGuard .conf file
$LogPath = "C:\ProgramData\WireGuardMonitor\monitor.log"

# Ensure log directory exists
$logDir = Split-Path -Parent $LogPath
if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $LogPath -Value $logMessage
    Write-Host $logMessage
}

function Test-HomeNetwork {
    try {
        $currentSSID = $null

        # Use netsh to get WiFi info - more reliable than PowerShell cmdlets
        $netshOutput = netsh wlan show interfaces 2>&1 | Out-String

        # Look for the SSID line - handle variations like "SSID" or " SSID"
        if ($netshOutput -match '(?m)^\s*SSID\s*:\s*(.+?)\s*$') {
            $currentSSID = $matches[1]
            Write-Log "Detected SSID: '$currentSSID'"

            # Compare SSIDs (exact match, case-sensitive)
            if ($currentSSID -eq $HomeNetworkSSID) {
                Write-Log "Connected to home network (SSID matches)"
                return $true
            } else {
                Write-Log "Not on home network (current: '$currentSSID', home: '$HomeNetworkSSID')"
                return $false
            }
        } else {
            Write-Log "Could not detect SSID - no WiFi connection or netsh failed"
            Write-Log "Raw netsh output: $($netshOutput.Substring(0, [Math]::Min(200, $netshOutput.Length)))"
            return $false
        }
    } catch {
        Write-Log "ERROR checking network: $_"
        return $false
    }
}

function Get-WireGuardStatus {
    try {
        # Extract tunnel name from config path
        $tunnelName = [System.IO.Path]::GetFileNameWithoutExtension($WireGuardConfigPath)

        # Check if the WireGuard service is running
        $serviceName = "WireGuardTunnel`$$tunnelName"
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

        if ($service -and $service.Status -eq 'Running') {
            return $true
        }

        # Alternative: Check using wg.exe command
        $wgPath = "C:\Program Files\WireGuard\wg.exe"
        if (Test-Path $wgPath) {
            $wgOutput = & $wgPath show $tunnelName 2>&1
            if ($wgOutput -notmatch "Unable to access interface" -and $wgOutput -notmatch "does not exist") {
                return $true
            }
        }

        return $false
    } catch {
        Write-Log "Error checking WireGuard status: $_"
        return $false
    }
}

function Start-WireGuardTunnel {
    try {
        $tunnelName = [System.IO.Path]::GetFileNameWithoutExtension($WireGuardConfigPath)
        Write-Log "Starting WireGuard tunnel: $tunnelName"

        # Use wireguard.exe CLI with /installtunnelservice
        $wireguardCLI = "C:\Program Files\WireGuard\wireguard.exe"
        if (!(Test-Path $wireguardCLI)) {
            Write-Log "ERROR: wireguard.exe not found at $wireguardCLI"
            return $false
        }

        # Verify config file exists
        if (!(Test-Path $WireGuardConfigPath)) {
            Write-Log "ERROR: Config file not found at $WireGuardConfigPath"
            return $false
        }

        $result = & $wireguardCLI /installtunnelservice "`"$WireGuardConfigPath`"" 2>&1
        Write-Log "WireGuard CLI output: $result"

        Start-Sleep -Seconds 5

        if (Get-WireGuardStatus) {
            Write-Log "WireGuard tunnel started successfully"
            return $true
        } else {
            Write-Log "WireGuard tunnel failed to start - checking for errors..."

            # Try to get more error details
            $serviceName = "WireGuardTunnel`$$tunnelName"
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Log "Service status: $($service.Status)"
            } else {
                Write-Log "Service not found. Available WireGuard services:"
                Get-Service -Name "WireGuardTunnel*" -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Log "  - $($_.Name) [$($_.Status)]"
                }
            }

            return $false
        }
    } catch {
        Write-Log "Error starting WireGuard: $_"
        Write-Log "Exception details: $($_.Exception.Message)"
        return $false
    }
}

function Stop-WireGuardTunnel {
    try {
        $tunnelName = [System.IO.Path]::GetFileNameWithoutExtension($WireGuardConfigPath)
        Write-Log "Stopping WireGuard tunnel: $tunnelName"

        # Use wireguard.exe CLI with /uninstalltunnelservice
        $wireguardCLI = "C:\Program Files\WireGuard\wireguard.exe"
        if (!(Test-Path $wireguardCLI)) {
            Write-Log "ERROR: wireguard.exe not found at $wireguardCLI"
            return $false
        }

        $result = & $wireguardCLI /uninstalltunnelservice $tunnelName 2>&1
        Write-Log "WireGuard CLI output: $result"

        Start-Sleep -Seconds 3
        Write-Log "WireGuard tunnel stopped"
        return $true
    } catch {
        Write-Log "Error stopping WireGuard: $_"
        Write-Log "Exception details: $($_.Exception.Message)"
        return $false
    }
}

function Start-NetworkMonitoring {
    Write-Log "=== WireGuard Network Monitor Service Started ==="

    $lastNetworkState = $null
    $lastWireGuardState = $null

    while ($true) {
        try {
            $isHomeNetwork = Test-HomeNetwork
            $wgActive = Get-WireGuardStatus

            # Only take action if state has changed
            if ($isHomeNetwork) {
                # On home network - WireGuard should be OFF
                if ($wgActive) {
                    if ($lastWireGuardState -ne "stopping") {
                        Write-Log "Home network detected - disconnecting WireGuard"
                        Stop-WireGuardTunnel
                        $lastWireGuardState = "stopping"
                    }
                } else {
                    $lastWireGuardState = "stopped"
                }
                $lastNetworkState = "home"
            } else {
                # Not on home network - WireGuard should be ON
                if (!$wgActive) {
                    if ($lastWireGuardState -ne "starting") {
                        Write-Log "External network detected - connecting WireGuard"
                        Start-WireGuardTunnel
                        $lastWireGuardState = "starting"
                    }
                } else {
                    $lastWireGuardState = "running"
                }
                $lastNetworkState = "external"
            }

            # Check every 30 seconds
            Start-Sleep -Seconds 30

        } catch {
            Write-Log "Error in monitoring loop: $_"
            Start-Sleep -Seconds 60
        }
    }
}

# Register network change event (for immediate response)
function Register-NetworkChangeEvent {
    $action = {
        # This will trigger the main loop to check faster
        Write-Log "Network change detected"
    }
    
    Register-WmiEvent -Query "SELECT * FROM __InstanceModificationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_NetworkAdapter'" -Action $action
}

# Main execution
Write-Log "Initializing WireGuard Network Monitor"
Register-NetworkChangeEvent
Start-NetworkMonitoring
