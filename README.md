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

**View Logs:**
- Start Menu → "WireGuard Network Monitor" → "View Logs"
- Or: `C:\ProgramData\WireGuardMonitor\monitor.log`

**PowerShell Commands:**
```powershell
Get-Service WireGuardNetworkMonitor          # Check status
Restart-Service WireGuardNetworkMonitor      # Restart service
Stop-Service WireGuardNetworkMonitor         # Stop service
```

## Troubleshooting

**Service won't start?**
- Check logs in Start Menu → "View Logs"
- Verify WireGuard is installed

**VPN not connecting?**
- Test WireGuard tunnel manually first
- Check logs for error messages

**Need to reconfigure?**
- Edit `C:\Program Files (x86)\WireGuardMonitor\WireGuardNetworkMonitor.ps1`
- Update these values:
  - `$HomeNetworkSSID` - Your home WiFi name
  - `$HomeNetworkGateway` - Your home router IP
  - `$WireGuardConfigPath` - Path to your .conf file
- Restart: `Restart-Service WireGuardNetworkMonitor`

## License

MIT License - [LICENSE.txt](LICENSE.txt)
