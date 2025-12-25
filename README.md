# WireGuard Network Monitor

Automatically connects WireGuard VPN when you leave your home network.

## Installation

1. Download the installer from [Releases](https://github.com/JanisHuser/WireguardTools/releases)
2. Run `WireGuardNetworkMonitor-Setup.exe` as Administrator
3. Select your WireGuard `.conf` file
4. Confirm your home network settings (auto-detected)
5. Done!

**Requirements:** Windows 10/11 (64-bit), WireGuard installed

## How It Works

- Detects home network by WiFi SSID or gateway IP
- Automatically connects WireGuard on external networks
- Automatically disconnects WireGuard when home
- Runs as a Windows service (starts on boot)

## Usage

Use Start Menu shortcuts:
- **View Logs** - Real-time monitoring
- **Configure** - Change settings
- **Uninstall** - Remove service

Or use PowerShell:
```powershell
Get-Service WireGuardNetworkMonitor          # Check status
Restart-Service WireGuardNetworkMonitor      # Restart
```

## Troubleshooting

**Service won't start?**
- Check logs: Start Menu → "View Logs"
- Verify WireGuard is installed

**VPN not connecting?**
- Test WireGuard manually first
- Check logs for errors

**Wrong network detection?**
- Reconfigure from Start Menu
- Verify home SSID is correct (case-sensitive)

Logs: `C:\ProgramData\WireGuardMonitor\monitor.log`

## License

MIT License - [LICENSE.txt](LICENSE.txt)
