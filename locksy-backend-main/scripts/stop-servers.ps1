# Stop All Backend Servers

Write-Host "Stopping all backend servers..." -ForegroundColor Yellow

# Stop Node.js processes
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
        Write-Host "  Stopping Node.js process (PID: $($proc.Id))..." -ForegroundColor Gray
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "  No Node.js processes found" -ForegroundColor Gray
}

# Also kill processes on common ports
$ports = @(3001, 3002, 3003, 3004, 3005)
foreach ($port in $ports) {
    $connections = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}

Start-Sleep -Seconds 2

Write-Host "[OK] All servers stopped" -ForegroundColor Green

