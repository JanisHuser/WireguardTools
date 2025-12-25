# WireGuard Network Monitor Service
# This script monitors network connections and activates WireGuard when not on home network

# Configuration - MODIFY THESE VALUES
$HomeNetworkSSID = "YourHomeWiFiName"  # Your home WiFi SSID
$HomeNetworkGateway = "192.168.1.1"    # Your home router's IP (alternative check)
$WireGuardInterface = "wg0"            # Your WireGuard interface name (must match tunnel name in WireGuard app)
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
    # Method 1: Check WiFi SSID using multiple approaches
    try {
        $currentSSID = $null

        # Try netsh first
        $wifiOutput = netsh wlan show interfaces 2>&1
        if ($wifiOutput) {
            # Match SSID line more flexibly (handles "SSID" and " SSID")
            if ($wifiOutput -match "^\s*SSID\s*:\s*(.+)$") {
                $currentSSID = $matches[1].Trim()
                Write-Log "Detected SSID via netsh: $currentSSID"
            }
        }

        # If netsh failed, try PowerShell cmdlet
        if (!$currentSSID) {
            try {
                $wlanInterface = Get-NetAdapter | Where-Object { $_.MediaType -eq "802.11" -and $_.Status -eq "Up" } | Select-Object -First 1
                if ($wlanInterface) {
                    $ssidQuery = (netsh wlan show interfaces name="$($wlanInterface.Name)") -match "^\s*SSID\s*:\s*(.+)$"
                    if ($ssidQuery) {
                        $currentSSID = $matches[1].Trim()
                        Write-Log "Detected SSID via adapter query: $currentSSID"
                    }
                }
            } catch {
                Write-Log "PowerShell SSID detection failed: $_"
            }
        }

        # Check if we found the home SSID
        if ($currentSSID -and $currentSSID -eq $HomeNetworkSSID) {
            Write-Log "Connected to home network via WiFi: $currentSSID"
            return $true
        } elseif ($currentSSID) {
            Write-Log "Connected to different WiFi: $currentSSID (home is: $HomeNetworkSSID)"
        }
    } catch {
        Write-Log "Could not check WiFi SSID: $_"
    }

    # Method 2: Check default gateway
    try {
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                   Select-Object -First 1).NextHop
        if ($gateway -eq $HomeNetworkGateway) {
            Write-Log "Connected to home network via gateway: $gateway"
            return $true
        } elseif ($gateway) {
            Write-Log "Gateway is $gateway (home is: $HomeNetworkGateway)"
        }
    } catch {
        Write-Log "Could not check gateway: $_"
    }

    Write-Log "Not on home network"
    return $false
}

function Get-WireGuardStatus {
    try {
        # Check if the WireGuard service is running
        $serviceName = "WireGuardTunnel`$$WireGuardInterface"
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($service -and $service.Status -eq 'Running') {
            return $true
        }
        
        # Alternative: Check using wg.exe command
        $wgPath = "C:\Program Files\WireGuard\wg.exe"
        if (Test-Path $wgPath) {
            $wgOutput = & $wgPath show $WireGuardInterface 2>&1
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
        Write-Log "Starting WireGuard tunnel: $WireGuardInterface"

        # Use wireguard.exe CLI with /installtunnelservice
        $wireguardCLI = "C:\Program Files\WireGuard\wireguard.exe"
        if (!(Test-Path $wireguardCLI)) {
            Write-Log "ERROR: wireguard.exe not found at $wireguardCLI"
            return $false
        }

        # Build the full path to the config file
        $configPath = "C:\Program Files\WireGuard\Data\Configurations\$WireGuardInterface.conf"
        if (!(Test-Path $configPath)) {
            Write-Log "ERROR: Config file not found at $configPath"
            return $false
        }

        $result = & $wireguardCLI /installtunnelservice "`"$configPath`"" 2>&1
        Write-Log "WireGuard CLI output: $result"

        Start-Sleep -Seconds 5

        if (Get-WireGuardStatus) {
            Write-Log "WireGuard tunnel started successfully"
            return $true
        } else {
            Write-Log "WireGuard tunnel failed to start - checking for errors..."

            # Try to get more error details
            $serviceName = "WireGuardTunnel`$$WireGuardInterface"
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
        Write-Log "Stopping WireGuard tunnel: $WireGuardInterface"

        # Use wireguard.exe CLI with /uninstalltunnelservice
        $wireguardCLI = "C:\Program Files\WireGuard\wireguard.exe"
        if (!(Test-Path $wireguardCLI)) {
            Write-Log "ERROR: wireguard.exe not found at $wireguardCLI"
            return $false
        }

        $result = & $wireguardCLI /uninstalltunnelservice $WireGuardInterface 2>&1
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
    
    while ($true) {
        try {
            $isHomeNetwork = Test-HomeNetwork
            $wgActive = Get-WireGuardStatus
            
            # State change logic
            if ($isHomeNetwork) {
                # On home network - WireGuard should be OFF
                if ($wgActive) {
                    Write-Log "Home network detected - disconnecting WireGuard"
                    Stop-WireGuardTunnel
                }
                $lastNetworkState = "home"
            } else {
                # Not on home network - WireGuard should be ON
                if (!$wgActive) {
                    Write-Log "External network detected - connecting WireGuard"
                    Start-WireGuardTunnel
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
