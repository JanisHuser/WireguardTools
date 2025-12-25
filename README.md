# WireGuard Network Monitor Service

Automatically connects your WireGuard VPN tunnel when you're not on your home network.

## Features

- 🏠 Detects when you're connected to your home network (via WiFi SSID or gateway IP)
- 🔒 Automatically connects WireGuard when on external networks
- 🔌 Automatically disconnects WireGuard when returning home
- 📝 Comprehensive logging
- ⚡ Responds quickly to network changes
- 🔧 Runs as a Windows service (starts automatically on boot)

## Prerequisites

1. **WireGuard installed**: Download from https://www.wireguard.com/install/
2. **WireGuard configuration**: Have a working WireGuard configuration file ready
3. **Administrator privileges**: Required for service installation

## Installation Steps

### 1. Prepare WireGuard

First, ensure WireGuard is installed and you have a working configuration:

1. Install WireGuard from https://www.wireguard.com/install/
2. Create your WireGuard tunnel configuration through the WireGuard GUI
3. Note the tunnel name (e.g., "wg0")

### 2. Configure the Script

Open `WireGuardNetworkMonitor.ps1` and modify these settings at the top:

```powershell
$HomeNetworkSSID = "YourHomeWiFiName"      # Your home WiFi SSID
$HomeNetworkGateway = "192.168.1.1"        # Your home router's IP
$WireGuardInterface = "wg0"                # Your WireGuard tunnel name
```

**How to find these values:**

- **Home WiFi SSID**: Run `netsh wlan show interfaces` and look for "SSID"
- **Home Gateway**: Run `ipconfig` and look for "Default Gateway"
- **WireGuard Interface**: Open WireGuard app and check your tunnel name

### 3. Install the Service

1. Open PowerShell as Administrator (right-click → "Run as Administrator")
2. Navigate to the script directory:
   ```powershell
   cd C:\path\to\scripts
   ```
3. Allow script execution (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Run the installer:
   ```powershell
   .\Install-Service.ps1
   ```

The installer will:
- Download NSSM (Non-Sucking Service Manager)
- Install the service
- Start monitoring automatically

## Usage

### Check Service Status

```powershell
Get-Service WireGuardNetworkMonitor
```

### View Logs

```powershell
# View recent logs
Get-Content C:\ProgramData\WireGuardMonitor\monitor.log -Tail 50

# Follow logs in real-time
Get-Content C:\ProgramData\WireGuardMonitor\monitor.log -Tail 50 -Wait
```

### Start/Stop Service

```powershell
# Stop the service
Stop-Service WireGuardNetworkMonitor

# Start the service
Start-Service WireGuardNetworkMonitor

# Restart the service (after config changes)
Restart-Service WireGuardNetworkMonitor
```

### Uninstall

```powershell
.\Uninstall-Service.ps1
```

## How It Works

1. **Network Detection**: The service checks every 30 seconds if you're on your home network by:
   - Checking WiFi SSID
   - Checking default gateway IP
   
2. **WireGuard Control**:
   - If home network detected → Disconnects WireGuard
   - If external network detected → Connects WireGuard

3. **Event-Based**: Also responds immediately to network change events

## Troubleshooting

### Service won't start

1. Check logs: `C:\ProgramData\WireGuardMonitor\service-error.log`
2. Verify WireGuard is installed: `Test-Path "C:\Program Files\WireGuard\wireguard.exe"`
3. Check configuration paths in the script

### WireGuard not connecting/disconnecting

1. Test WireGuard manually first through the GUI
2. Verify the tunnel name matches your configuration
3. Check permissions - service needs admin rights
4. Review logs for errors

### Wrong network detection

1. Verify your home SSID is spelled correctly (case-sensitive)
2. Verify your gateway IP is correct
3. Check logs to see what values are being detected

### View detailed service info

```powershell
Get-WmiObject -Class Win32_Service -Filter "Name='WireGuardNetworkMonitor'" | Format-List *
```

## Advanced Configuration

### Change Check Interval

Edit `WireGuardNetworkMonitor.ps1` and modify:

```powershell
Start-Sleep -Seconds 30  # Change 30 to desired seconds
```

### Add Additional Home Network Checks

You can add more detection methods in the `Test-HomeNetwork` function:

```powershell
# Example: Check for specific DNS server
$dns = (Get-DnsClientServerAddress -AddressFamily IPv4).ServerAddresses
if ($dns -contains "192.168.1.1") {
    return $true
}
```

### Multiple Home Networks

Modify the configuration to support multiple locations:

```powershell
$HomeNetworkSSIDs = @("HomeWiFi", "OfficeWiFi", "ParentsWiFi")
$HomeNetworkGateways = @("192.168.1.1", "10.0.0.1", "192.168.0.1")

# Then modify Test-HomeNetwork to check against arrays
if ($currentSSID -in $HomeNetworkSSIDs) {
    return $true
}
```

## Files

- `WireGuardNetworkMonitor.ps1` - Main monitoring script
- `Install-Service.ps1` - Service installer
- `Uninstall-Service.ps1` - Service uninstaller
- `README.md` - This file

## Logs Location

- Monitor log: `C:\ProgramData\WireGuardMonitor\monitor.log`
- Service output: `C:\ProgramData\WireGuardMonitor\service-output.log`
- Service errors: `C:\ProgramData\WireGuardMonitor\service-error.log`

## Security Notes

- The service runs with SYSTEM privileges (required for network monitoring and WireGuard control)
- WireGuard credentials are managed by WireGuard itself
- Logs contain network information but no sensitive credentials

## License

Free to use and modify.

## Support

For issues:
1. Check the troubleshooting section above
2. Review logs for error messages
3. Verify WireGuard works manually
4. Ensure all prerequisites are met
