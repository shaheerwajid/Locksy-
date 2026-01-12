# Start All Services Script
# Starts all infrastructure and microservices in the correct order

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting All Services" -ForegroundColor Cyan
Write-Host "Locksy Backend - Distributed System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$global:ServicesStatus = @{
    Docker = @{}
    Microservices = @{}
    Workers = @{}
}

# ========================================
# STEP 1: Start Docker Services
# ========================================
Write-Host "STEP 1: Starting Docker Services..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Check if Docker is running
try {
    $dockerVersion = docker --version 2>&1
    Write-Host "  [OK] Docker installed: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Docker is not installed or not running" -ForegroundColor Red
    exit 1
}

# Check if docker-compose is available
try {
    $composeVersion = docker-compose --version 2>&1
    Write-Host "  [OK] Docker Compose available: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "  [WARN] docker-compose not found, trying 'docker compose'" -ForegroundColor Yellow
    $useDockerCompose = $false
}

# Start Docker services
Write-Host ""
Write-Host "  Starting Docker Compose services..." -ForegroundColor Cyan

if (Test-Path "docker-compose.yml") {
    try {
        # Stop existing containers first
        Write-Host "    Stopping existing containers..." -ForegroundColor Gray
        if ($useDockerCompose -ne $false) {
            docker-compose down 2>&1 | Out-Null
        } else {
            docker compose down 2>&1 | Out-Null
        }
        
        # Start services
        Write-Host "    Starting services..." -ForegroundColor Gray
        if ($useDockerCompose -ne $false) {
            docker-compose up -d 2>&1 | Out-Null
        } else {
            docker compose up -d 2>&1 | Out-Null
        }
        
        Write-Host "  [OK] Docker services started" -ForegroundColor Green
    } catch {
        Write-Host "  [ERROR] Failed to start Docker services: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [WARN] docker-compose.yml not found" -ForegroundColor Yellow
}

# Wait for Docker services to be ready
Write-Host ""
Write-Host "  Waiting for Docker services to be ready..." -ForegroundColor Cyan
Start-Sleep -Seconds 10

# Check Docker service health
$dockerServices = @(
    @{Name="MongoDB Primary"; Port=27017; Container="locksy-mongodb-primary"},
    @{Name="MongoDB Secondary1"; Port=27018; Container="locksy-mongodb-secondary1"},
    @{Name="MongoDB Secondary2"; Port=27019; Container="locksy-mongodb-secondary2"},
    @{Name="Redis"; Port=6379; Container="locksy-redis"},
    @{Name="RabbitMQ"; Port=5672; Container="locksy-rabbitmq"},
    @{Name="Elasticsearch"; Port=9200; Container="locksy-elasticsearch"},
    @{Name="Zookeeper"; Port=2181; Container="locksy-zookeeper"},
    @{Name="Jaeger"; Port=16686; Container="locksy-jaeger"},
    @{Name="MinIO"; Port=9000; Container="locksy-minio"}
)

foreach ($service in $dockerServices) {
    Write-Host "    Checking $($service.Name)..." -NoNewline -ForegroundColor Gray
    
    # Check if container is running
    $containerStatus = docker ps --filter "name=$($service.Container)" --format "{{.Status}}" 2>&1
    if ($containerStatus -match "Up") {
        Write-Host " [OK]" -ForegroundColor Green
        $global:ServicesStatus.Docker[$service.Name] = "Running"
    } else {
        Write-Host " [WARN] Container not running" -ForegroundColor Yellow
        $global:ServicesStatus.Docker[$service.Name] = "Not Running"
    }
}

# Initialize MongoDB Replica Set
Write-Host ""
Write-Host "  Initializing MongoDB Replica Set..." -ForegroundColor Cyan
if (Test-Path "scripts/init-replica-set.ps1") {
    try {
        & "scripts/init-replica-set.ps1" 2>&1 | Out-Null
        Write-Host "  [OK] Replica set initialization attempted" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Replica set initialization may need manual setup" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARN] Replica set init script not found" -ForegroundColor Yellow
}

Write-Host ""

# ========================================
# STEP 2: Start Main API Servers
# ========================================
Write-Host "STEP 2: Starting Main API Servers..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$ports = @(3001, 3002, 3003)
$basePort = 3001

# Stop existing servers
Write-Host "  Stopping existing servers..." -ForegroundColor Gray
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    foreach ($proc in $nodeProcesses) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 2

# Create logs directory
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Start servers
foreach ($port in $ports) {
    Write-Host "  Starting server on port $port..." -NoNewline -ForegroundColor Cyan
    
    $scriptContent = @"
`$env:PORT = '$port'
`$env:USE_GATEWAY = 'true'
`$env:ENABLE_CLUSTER = 'false'
`$env:NODE_ENV = 'development'
cd '$PWD'
Write-Host 'Starting API Gateway on port $port...' -ForegroundColor Cyan
node index.js
Write-Host '`nAPI Gateway is running. Close this window to stop it.' -ForegroundColor Yellow
"@
    
    $scriptPath = "logs\start-server-$port.ps1"
    $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force
    
    Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Normal | Out-Null
    Write-Host " [OK]" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Write-Host "  Waiting for servers to initialize..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Verify servers
foreach ($port in $ports) {
    Write-Host "    Checking server on port $port..." -NoNewline -ForegroundColor Gray
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$port/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host " [OK]" -ForegroundColor Green
            $global:ServicesStatus.Microservices["API-Server-$port"] = "Running"
        } else {
            Write-Host " [WARN] HTTP $($response.StatusCode)" -ForegroundColor Yellow
            $global:ServicesStatus.Microservices["API-Server-$port"] = "Warning"
        }
    } catch {
        Write-Host " [WARN] Not responding yet" -ForegroundColor Yellow
        $global:ServicesStatus.Microservices["API-Server-$port"] = "Starting"
    }
}

Write-Host ""

# ========================================
# STEP 3: Start Metadata Server
# ========================================
Write-Host "STEP 3: Starting Metadata Server..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Metadata Server (port 3004)..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
`$env:METADATA_SERVER_ENABLED = 'true'
`$env:METADATA_SERVER_PORT = '3004'
`$env:USE_GATEWAY = 'false'
`$env:ENABLE_CLUSTER = 'false'
`$env:SKIP_MAIN_SERVER = 'true'
cd '$PWD'
Write-Host 'Starting Metadata Server on port 3004...' -ForegroundColor Cyan
node scripts/start-metadata-server.js
Write-Host '`nMetadata Server is running. Close this window to stop it.' -ForegroundColor Yellow
"@

$scriptPath = "logs\start-metadata-server.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

Start-Sleep -Seconds 5

# Verify Metadata Server
Write-Host "    Checking Metadata Server..." -NoNewline -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3004/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor Green
        $global:ServicesStatus.Microservices["Metadata-Server"] = "Running"
    } else {
        Write-Host " [WARN]" -ForegroundColor Yellow
        $global:ServicesStatus.Microservices["Metadata-Server"] = "Warning"
    }
} catch {
    Write-Host " [WARN] Not responding yet" -ForegroundColor Yellow
    $global:ServicesStatus.Microservices["Metadata-Server"] = "Starting"
}

Write-Host ""

# ========================================
# STEP 4: Start Block Server
# ========================================
Write-Host "STEP 4: Starting Block Server..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Block Server (port 3005)..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
`$env:BLOCK_SERVER_ENABLED = 'true'
`$env:BLOCK_SERVER_PORT = '3005'
`$env:USE_GATEWAY = 'false'
`$env:ENABLE_CLUSTER = 'false'
`$env:SKIP_MAIN_SERVER = 'true'
cd '$PWD'
Write-Host 'Starting Block Server on port 3005...' -ForegroundColor Cyan
node scripts/start-block-server.js
Write-Host '`nBlock Server is running. Close this window to stop it.' -ForegroundColor Yellow
"@

$scriptPath = "logs\start-block-server.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

Start-Sleep -Seconds 5

# Verify Block Server
Write-Host "    Checking Block Server..." -NoNewline -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3005/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor Green
        $global:ServicesStatus.Microservices["Block-Server"] = "Running"
    } else {
        Write-Host " [WARN]" -ForegroundColor Yellow
        $global:ServicesStatus.Microservices["Block-Server"] = "Warning"
    }
} catch {
    Write-Host " [WARN] Not responding yet" -ForegroundColor Yellow
    $global:ServicesStatus.Microservices["Block-Server"] = "Starting"
}

Write-Host ""

# ========================================
# STEP 5: Start Shard Manager
# ========================================
Write-Host "STEP 5: Starting Shard Manager..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Shard Manager..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
cd '$PWD'
node scripts/start-shard-manager.js
"@

$scriptPath = "logs\start-shard-manager.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

$global:ServicesStatus.Microservices["Shard-Manager"] = "Running"
Start-Sleep -Seconds 3

Write-Host ""

# ========================================
# STEP 6: Start Data Warehouse
# ========================================
Write-Host "STEP 6: Starting Data Warehouse..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Data Warehouse (port 3009)..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
`$env:WAREHOUSE_PORT = '3009'
`$env:ENABLE_SCHEDULER = 'true'
`$env:USE_GATEWAY = 'false'
`$env:ENABLE_CLUSTER = 'false'
`$env:SKIP_MAIN_SERVER = 'true'
cd '$PWD'
Write-Host 'Starting Data Warehouse on port 3009...' -ForegroundColor Cyan
node scripts/start-warehouse.js
Write-Host '`nData Warehouse is running. Close this window to stop it.' -ForegroundColor Yellow
"@

$scriptPath = "logs\start-warehouse.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

Start-Sleep -Seconds 5

# Verify Data Warehouse
Write-Host "    Checking Data Warehouse..." -NoNewline -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3009/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor Green
        $global:ServicesStatus.Microservices["Data-Warehouse"] = "Running"
    } else {
        Write-Host " [WARN]" -ForegroundColor Yellow
        $global:ServicesStatus.Microservices["Data-Warehouse"] = "Warning"
    }
} catch {
    Write-Host " [WARN] Not responding yet" -ForegroundColor Yellow
    $global:ServicesStatus.Microservices["Data-Warehouse"] = "Starting"
}

Write-Host ""

# ========================================
# STEP 7: Start Video Workers
# ========================================
Write-Host "STEP 7: Starting Video Processing Workers..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Video Workers (3 instances)..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
cd '$PWD'
node scripts/start-video-workers.js
"@

$scriptPath = "logs\start-video-workers.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

$global:ServicesStatus.Workers["Video-Workers"] = "Running"
Start-Sleep -Seconds 3

Write-Host ""

# ========================================
# STEP 8: Start Analytics Workers
# ========================================
Write-Host "STEP 8: Starting Analytics Workers..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Starting Analytics Workers..." -NoNewline -ForegroundColor Cyan

$scriptContent = @"
`$env:NODE_ENV = 'development'
cd '$PWD'
node scripts/start-analytics-workers.js
"@

$scriptPath = "logs\start-analytics-workers.ps1"
$scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8 -Force

Start-Process powershell -ArgumentList "-NoExit", "-File", "$PWD\$scriptPath" -WindowStyle Minimized | Out-Null
Write-Host " [OK]" -ForegroundColor Green

$global:ServicesStatus.Workers["Analytics-Workers"] = "Running"
Start-Sleep -Seconds 3

Write-Host ""

# ========================================
# STEP 9: Final Health Verification
# ========================================
Write-Host "STEP 9: Final Health Verification..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "  Waiting for all services to stabilize..." -ForegroundColor Gray
Start-Sleep -Seconds 10

$allHealthy = $true

# Check all microservices
$servicesToCheck = @(
    @{Name="API Server 3001"; Port=3001},
    @{Name="API Server 3002"; Port=3002},
    @{Name="API Server 3003"; Port=3003},
    @{Name="Metadata Server"; Port=3004},
    @{Name="Block Server"; Port=3005},
    @{Name="Data Warehouse"; Port=3009}
)

foreach ($service in $servicesToCheck) {
    Write-Host "    Checking $($service.Name)..." -NoNewline -ForegroundColor Gray
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$($service.Port)/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [WARN] HTTP $($response.StatusCode)" -ForegroundColor Yellow
            $allHealthy = $false
        }
    } catch {
        Write-Host " [WARN] Not responding" -ForegroundColor Yellow
        $allHealthy = $false
    }
}

Write-Host ""

# ========================================
# Summary Report
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Service Startup Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Docker Services:" -ForegroundColor Yellow
foreach ($service in $global:ServicesStatus.Docker.GetEnumerator()) {
    $status = if ($service.Value -eq "Running") { "Running" } else { "Not Running" }
    $color = if ($service.Value -eq "Running") { "Green" } else { "Yellow" }
    Write-Host "  $($service.Key): $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "Microservices:" -ForegroundColor Yellow
foreach ($service in $global:ServicesStatus.Microservices.GetEnumerator()) {
    $color = switch ($service.Value) {
        "Running" { "Green" }
        "Warning" { "Yellow" }
        default { "Yellow" }
    }
    Write-Host "  $($service.Key): $($service.Value)" -ForegroundColor $color
}

Write-Host ""
Write-Host "Workers:" -ForegroundColor Yellow
foreach ($worker in $global:ServicesStatus.Workers.GetEnumerator()) {
    Write-Host "  $($worker.Key): $($worker.Value)" -ForegroundColor Green
}

Write-Host ""

if ($allHealthy) {
    Write-Host "[SUCCESS] All services started successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Service URLs:" -ForegroundColor Cyan
    Write-Host "  API Gateway: http://localhost:3001" -ForegroundColor White
    Write-Host "  Metadata Server: http://localhost:3004" -ForegroundColor White
    Write-Host "  Block Server: http://localhost:3005" -ForegroundColor White
    Write-Host "  Data Warehouse: http://localhost:3009" -ForegroundColor White
    Write-Host "  Jaeger UI: http://localhost:16686" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now run tests using: scripts/tests/run-all.ps1" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "[WARNING] Some services may not be fully ready yet." -ForegroundColor Yellow
    Write-Host "Please wait a few more seconds and check service health manually." -ForegroundColor Yellow
    exit 1
}


