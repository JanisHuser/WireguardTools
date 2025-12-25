# WireGuard Diagnostic Script
# Run this as Administrator to diagnose WireGuard connection issues

#Requires -RunAsAdministrator

Write-Host "=== WireGuard Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host ""

# Configuration - UPDATE THESE TO MATCH YOUR SETUP
$WireGuardInterface = "wg0"  # Change this to your tunnel name

Write-Host "Step 1: Checking WireGuard Installation..." -ForegroundColor Yellow
$wireguardExe = "C:\Program Files\WireGuard\wireguard.exe"
$wgExe = "C:\Program Files\WireGuard\wg.exe"

if (Test-Path $wireguardExe) {
    Write-Host "  ✓ WireGuard GUI found at: $wireguardExe" -ForegroundColor Green
} else {
    Write-Host "  ✗ WireGuard GUI NOT found at: $wireguardExe" -ForegroundColor Red
}

if (Test-Path $wgExe) {
    Write-Host "  ✓ WireGuard CLI found at: $wgExe" -ForegroundColor Green
} else {
    Write-Host "  ✗ WireGuard CLI NOT found at: $wgExe" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 2: Checking WireGuard Services..." -ForegroundColor Yellow
$services = Get-Service -Name "WireGuard*" -ErrorAction SilentlyContinue

if ($services) {
    foreach ($service in $services) {
        $status = $service.Status
        $color = if ($status -eq "Running") { "Green" } else { "Yellow" }
        Write-Host "  Service: $($service.Name)" -ForegroundColor $color
        Write-Host "    Status: $status" -ForegroundColor $color
        Write-Host "    Display Name: $($service.DisplayName)" -ForegroundColor Gray
    }
} else {
    Write-Host "  ✗ No WireGuard services found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 3: Checking for Your Tunnel..." -ForegroundColor Yellow
$tunnelService = "WireGuardTunnel`$$WireGuardInterface"
$service = Get-Service -Name $tunnelService -ErrorAction SilentlyContinue

if ($service) {
    Write-Host "  ✓ Tunnel service found: $tunnelService" -ForegroundColor Green
    Write-Host "    Status: $($service.Status)" -ForegroundColor $(if ($service.Status -eq "Running") { "Green" } else { "Yellow" })
} else {
    Write-Host "  ✗ Tunnel service NOT found: $tunnelService" -ForegroundColor Red
    Write-Host "    This usually means the tunnel needs to be created in WireGuard first" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 4: Checking WireGuard Configuration Files..." -ForegroundColor Yellow
$configDir = "C:\Program Files\WireGuard\Data\Configurations"

if (Test-Path $configDir) {
    Write-Host "  ✓ Configuration directory found" -ForegroundColor Green
    $configs = Get-ChildItem -Path $configDir -Filter "*.dpapi" -ErrorAction SilentlyContinue
    
    if ($configs) {
        Write-Host "  Available tunnels:" -ForegroundColor Cyan
        foreach ($config in $configs) {
            $tunnelName = $config.BaseName -replace '\.conf$', ''
            Write-Host "    - $tunnelName" -ForegroundColor Gray
            
            if ($tunnelName -eq $WireGuardInterface) {
                Write-Host "      ✓ This matches your configured tunnel!" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  ✗ No tunnel configurations found" -ForegroundColor Red
        Write-Host "    You need to create a tunnel in the WireGuard GUI first" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ Configuration directory not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 5: Testing WireGuard Commands..." -ForegroundColor Yellow

if (Test-Path $wgExe) {
    Write-Host "  Testing 'wg show'..." -ForegroundColor Gray
    try {
        $wgOutput = & $wgExe show 2>&1
        if ($wgOutput) {
            Write-Host "  Output:" -ForegroundColor Cyan
            $wgOutput | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        } else {
            Write-Host "  ✗ No active tunnels" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ✗ Error running wg.exe: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Step 6: Attempting Manual Tunnel Control..." -ForegroundColor Yellow

# Test starting the tunnel
Write-Host "  Attempting to start tunnel '$WireGuardInterface'..." -ForegroundColor Gray
try {
    if (Test-Path $wireguardExe) {
        $result = & $wireguardExe /installtunnelservice $WireGuardInterface 2>&1
        Write-Host "  Result: $result" -ForegroundColor Cyan
        
        Start-Sleep -Seconds 3
        
        # Check if it worked
        $service = Get-Service -Name $tunnelService -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Host "  ✓ Tunnel started successfully!" -ForegroundColor Green
            
            # Show tunnel info
            if (Test-Path $wgExe) {
                Write-Host ""
                Write-Host "  Tunnel details:" -ForegroundColor Cyan
                & $wgExe show $WireGuardInterface
            }
            
            # Stop it again
            Write-Host ""
            Write-Host "  Stopping tunnel for cleanup..." -ForegroundColor Gray
            & $wireguardExe /uninstalltunnelservice $WireGuardInterface
            Write-Host "  ✓ Tunnel stopped" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Tunnel did not start" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "  ✗ Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Diagnostic Summary ===" -ForegroundColor Cyan
Write-Host ""

# Determine the issue
$issues = @()
$suggestions = @()

if (!(Test-Path $wireguardExe)) {
    $issues += "WireGuard is not installed"
    $suggestions += "Install WireGuard from https://www.wireguard.com/install/"
}

if (!$service) {
    $issues += "Tunnel '$WireGuardInterface' not found"
    $suggestions += "Create the tunnel in WireGuard GUI first:"
    $suggestions += "  1. Open WireGuard application"
    $suggestions += "  2. Click 'Add Tunnel' or import your .conf file"
    $suggestions += "  3. Name it '$WireGuardInterface' (or update the script config)"
    $suggestions += "  4. Test it manually first before using the service"
}

if ($issues.Count -gt 0) {
    Write-Host "Issues Found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  ✗ $issue" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Suggestions:" -ForegroundColor Yellow
    foreach ($suggestion in $suggestions) {
        Write-Host "  • $suggestion" -ForegroundColor Yellow
    }
} else {
    Write-Host "✓ All checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "If you're still having issues:" -ForegroundColor Yellow
    Write-Host "  1. Make sure the tunnel name in the script matches exactly (case-sensitive)" -ForegroundColor Gray
    Write-Host "  2. Test the tunnel manually in WireGuard GUI first" -ForegroundColor Gray
    Write-Host "  3. Check the service logs at C:\ProgramData\WireGuardMonitor\monitor.log" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Current Configuration:" -ForegroundColor Cyan
Write-Host "  WireGuardInterface = '$WireGuardInterface'" -ForegroundColor Gray
Write-Host "  Expected service name = '$tunnelService'" -ForegroundColor Gray
