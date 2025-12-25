# Uninstall WireGuard Network Monitor Service
# Run this script as Administrator

#Requires -RunAsAdministrator

$ServiceName = "WireGuardNetworkMonitor"
$NSSMPath = "$PSScriptRoot\nssm.exe"

Write-Host "=== WireGuard Network Monitor Service Uninstaller ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check if service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (!$service) {
    Write-Host "Service '$ServiceName' is not installed." -ForegroundColor Yellow
    exit 0
}

Write-Host "Step 1: Stopping service..." -ForegroundColor Yellow
Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Step 2: Removing service..." -ForegroundColor Yellow
if (Test-Path $NSSMPath) {
    & $NSSMPath remove $ServiceName confirm
} else {
    # Fallback to sc.exe
    sc.exe delete $ServiceName
}

Start-Sleep -Seconds 2

# Verify removal
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if (!$service) {
    Write-Host ""
    Write-Host "=== Service Uninstalled Successfully ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Log files are still present at C:\ProgramData\WireGuardMonitor\" -ForegroundColor Yellow
    Write-Host "You can delete them manually if desired." -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "WARNING: Service may not have been fully removed." -ForegroundColor Red
    Write-Host "Try running 'sc.exe delete $ServiceName' manually." -ForegroundColor Yellow
}
