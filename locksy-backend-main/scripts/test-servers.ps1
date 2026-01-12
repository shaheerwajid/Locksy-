# Test Servers - Start, Test, and Report Status
# Comprehensive test of all backend servers

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Server Test & Start Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Stop existing servers first
Write-Host "Step 1: Stopping existing servers..." -ForegroundColor Yellow
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [OK] Stopped existing servers" -ForegroundColor Green
} else {
    Write-Host "  [INFO] No existing servers to stop" -ForegroundColor Gray
}

Start-Sleep -Seconds 2

# Start servers
Write-Host ""
Write-Host "Step 2: Starting servers..." -ForegroundColor Yellow
$ports = @(3001, 3002, 3003)

if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

foreach ($port in $ports) {
    Write-Host "  Starting server on port $port..." -NoNewline
    
    $script = @"
`$env:PORT = '$port'
`$env:USE_GATEWAY = 'true'
`$env:ENABLE_CLUSTER = 'false'
`$env:NODE_ENV = 'development'
cd '$PWD'
node index.js
"@
    
    $scriptPath = "logs\start-$port.ps1"
    $script | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
    
    Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized
    Write-Host " [OK]" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Write-Host ""
Write-Host "Step 3: Waiting for servers to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Test servers
Write-Host ""
Write-Host "Step 4: Testing servers..." -ForegroundColor Yellow

$allOK = $true
foreach ($port in $ports) {
    Write-Host "  Port $port..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -TimeoutSec 5 -UseBasicParsing
        $json = $response.Content | ConvertFrom-Json
        if ($json.ok -eq $true) {
            Write-Host " [OK] Healthy" -ForegroundColor Green
        } else {
            Write-Host " [ERROR]" -ForegroundColor Red
            $allOK = $false
        }
    } catch {
        Write-Host " [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        $allOK = $false
    }
}

# Test health endpoints
Write-Host ""
Write-Host "Step 5: Testing health endpoints..." -ForegroundColor Yellow

$healthEndpoints = @(
    @{Path="/health"; Name="Basic health"},
    @{Path="/health/ready"; Name="Readiness probe"},
    @{Path="/health/live"; Name="Liveness probe"}
)

foreach ($endpoint in $healthEndpoints) {
    Write-Host "  $($endpoint.Name)..." -NoNewline
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3001$($endpoint.Path)" -TimeoutSec 3 -UseBasicParsing
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 503) {
            Write-Host " [OK] HTTP $($response.StatusCode)" -ForegroundColor Green
        } else {
            Write-Host " [WARNING] HTTP $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($allOK) {
    Write-Host "[SUCCESS] All servers are running!" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Some servers had issues" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Servers running on:" -ForegroundColor Cyan
foreach ($port in $ports) {
    Write-Host "  http://localhost:$port/health" -ForegroundColor White
}

Write-Host ""
Write-Host "To stop servers: .\scripts\stop-servers.ps1" -ForegroundColor Yellow
Write-Host ""

