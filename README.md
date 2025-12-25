# WireGuard Network Monitor

Automatically connects your WireGuard VPN tunnel when you're not on your home network.

## Features

- Detects when you're on your home network (WiFi SSID or gateway IP)
- Automatically connects WireGuard on external networks
- Automatically disconnects WireGuard when returning home
- Runs as a Windows service (starts on boot)
- Comprehensive logging

## Installation

### Using the Installer (Recommended)

1. **Download** the latest installer from the [Releases](https://github.com/JanisHuser/WireguardTools/releases) page
2. **Run** `WireGuardNetworkMonitor-Setup-x.x.x.exe` as Administrator
3. **Select** your WireGuard `.conf` file when prompted
4. **Configure** your home network settings (auto-detected)
5. Done! The service is now running.

### Prerequisites

- Windows 10/11 (64-bit)
- WireGuard installed ([download here](https://www.wireguard.com/install/))
- WireGuard configuration file (.conf)
- Administrator privileges

### Manual Installation

If you prefer to install manually:

1. Download the source code
2. Open PowerShell as Administrator
3. Run `.\Install-Service.ps1`
4. Follow the prompts

## Usage

All management can be done through the Start Menu shortcuts:

- **Configure WireGuard Monitor** - Reconfigure the service
- **View Logs** - Watch real-time service logs
- **Test WireGuard** - Test your WireGuard connection
- **Uninstall Service** - Remove the service

### PowerShell Commands

```powershell
# Check service status
Get-Service WireGuardNetworkMonitor

# View logs
Get-Content C:\ProgramData\WireGuardMonitor\monitor.log -Tail 50

# Restart service (after config changes)
Restart-Service WireGuardNetworkMonitor
```

## How It Works

1. **Network Detection**: Checks every 30 seconds if you're on your home network
   - Compares WiFi SSID
   - Compares default gateway IP

2. **Automatic Connection**:
   - Home network → Disconnects WireGuard
   - External network → Connects WireGuard

3. **Event-Based**: Responds immediately to network changes

## Troubleshooting

### Service Won't Start

1. Check logs in Start Menu → "View Logs"
2. Verify WireGuard is installed
3. Ensure your .conf file exists in `C:\Program Files\WireGuard\Data\Configurations\`

### WireGuard Not Connecting

1. Test WireGuard manually through the GUI first
2. Check logs for error messages
3. Verify the tunnel name matches your configuration file

### Wrong Network Detection

1. Reconfigure using Start Menu → "Configure WireGuard Monitor"
2. Verify home SSID is correct (case-sensitive)
3. Check logs to see detected values

## Logs Location

- Monitor log: `C:\ProgramData\WireGuardMonitor\monitor.log`
- Service errors: `C:\ProgramData\WireGuardMonitor\service-error.log`

## License

MIT License - See [LICENSE.txt](LICENSE.txt)

## Contributing

Issues and pull requests are welcome at [GitHub](https://github.com/JanisHuser/WireguardTools)
