# Start Multiple Backend Servers for Load Balancing
# This script starts multiple Node.js instances on different ports

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Backend Servers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "[OK] Node.js installed: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Node.js is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Check if we're in the right directory
if (-not (Test-Path "index.js")) {
    Write-Host "[ERROR] index.js not found. Please run from locksy-backend-main directory" -ForegroundColor Red
    exit 1
}

# Number of servers to start (default: 3)
$numServers = 3
if ($args[0]) {
    $numServers = [int]$args[0]
}

# Base port (default: 3001)
$basePort = 3001
if ($args[1]) {
    $basePort = [int]$args[1]
}

# Kill any existing processes on these ports
Write-Host "Stopping existing servers..." -ForegroundColor Yellow
for ($i = 0; $i -lt $numServers; $i++) {
    $port = $basePort + $i
    $connections = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    foreach ($conn in $connections) {
        if ($conn.State -eq "Listen") {
            Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            Write-Host "  Stopped process on port $port" -ForegroundColor Gray
        }
    }
}

Start-Sleep -Seconds 2

# Create logs directory if it doesn't exist
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Start servers
Write-Host ""
Write-Host "Starting $numServers servers..." -ForegroundColor Yellow
$pids = @()

for ($i = 0; $i -lt $numServers; $i++) {
    $port = $basePort + $i
    
    Write-Host "  Starting server on port $port..." -NoNewline
    
    # Create startup script for each server
    $scriptContent = @"
`$env:PORT = '$port'
`$env:USE_GATEWAY = 'true'
`$env:ENABLE_CLUSTER = 'false'
`$env:NODE_ENV = 'development'
cd '$PWD'
node index.js
"@
    
    $scriptPath = "logs\start-server-$port.ps1"
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
    
    # Start server in new window
    $process = Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized -PassThru
    $pids += $process.Id
    
    Write-Host " [OK] (PID: $($process.Id))" -ForegroundColor Green
    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Waiting for servers to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check if servers are running
Write-Host ""
Write-Host "Checking server health..." -ForegroundColor Yellow
$allHealthy = $true

for ($i = 0; $i -lt $numServers; $i++) {
    $port = $basePort + $i
    Write-Host "  Testing port $port..." -NoNewline
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $json = $response.Content | ConvertFrom-Json
            Write-Host " [OK] Healthy" -ForegroundColor Green
        } else {
            Write-Host " [ERROR] HTTP $($response.StatusCode)" -ForegroundColor Red
            $allHealthy = $false
        }
    } catch {
        Write-Host " [ERROR] Not responding" -ForegroundColor Red
        $allHealthy = $false
    }
}

Write-Host ""
if ($allHealthy) {
    Write-Host "[SUCCESS] All servers are running and healthy!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Server Information:" -ForegroundColor Cyan
    Write-Host ("  Port {0}: http://localhost:{0}/health" -f $basePort) -ForegroundColor White
    for ($i = 1; $i -lt $numServers; $i++) {
        $port = $basePort + $i
        Write-Host ("  Port {0}: http://localhost:{0}/health" -f $port) -ForegroundColor White
    }
    Write-Host ""
    Write-Host "To stop servers:" -ForegroundColor Yellow
    Write-Host "  .\scripts\stop-servers.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "To view logs:" -ForegroundColor Yellow
    Write-Host "  Get-Content logs\server-*.log -Tail 20" -ForegroundColor White
} else {
    Write-Host "[WARNING] Some servers may not be ready yet. Check logs in logs\ directory" -ForegroundColor Yellow
}

