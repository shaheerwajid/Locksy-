# Test Docker Services
# Verifies all Docker Compose services are running and healthy

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker Services Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker is available
Write-Host "Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>&1
    Test-Passed "Docker installed" $dockerVersion
} catch {
    Test-Failed "Docker installed" "Docker not found"
    exit 1
}

# Check docker-compose
Write-Host ""
Write-Host "Checking Docker Compose..." -ForegroundColor Yellow
try {
    $composeVersion = docker-compose --version 2>&1
    Test-Passed "Docker Compose available" $composeVersion
} catch {
    try {
        $composeVersion = docker compose version 2>&1
        Test-Passed "Docker Compose available (docker compose)" $composeVersion
    } catch {
        Test-Failed "Docker Compose available" "docker-compose not found"
        exit 1
    }
}

# Check docker-compose.yml exists
Write-Host ""
Write-Host "Checking docker-compose.yml..." -ForegroundColor Yellow
if (Test-Path "docker-compose.yml") {
    Test-Passed "docker-compose.yml exists"
} else {
    Test-Failed "docker-compose.yml exists" "File not found"
    exit 1
}

# Get service status
Write-Host ""
Write-Host "Checking Docker services..." -ForegroundColor Yellow
$status = Get-DockerServiceStatus

# Test each service
$services = @(
    @{Name="MongoDB Primary"; Container="locksy-mongodb-primary"; Port=27017},
    @{Name="MongoDB Secondary1"; Container="locksy-mongodb-secondary1"; Port=27018},
    @{Name="MongoDB Secondary2"; Container="locksy-mongodb-secondary2"; Port=27019},
    @{Name="Redis"; Container="locksy-redis"; Port=6379},
    @{Name="RabbitMQ"; Container="locksy-rabbitmq"; Port=5672},
    @{Name="Elasticsearch"; Container="locksy-elasticsearch"; Port=9200; HealthCheck="http://localhost:9200/_cluster/health"},
    @{Name="Zookeeper"; Container="locksy-zookeeper"; Port=2181},
    @{Name="Jaeger"; Container="locksy-jaeger"; Port=16686; HealthCheck="http://localhost:16686"},
    @{Name="MinIO"; Container="locksy-minio"; Port=9000}
)

foreach ($service in $services) {
    $serviceStatus = $status[$service.Name]
    
    if ($serviceStatus.Running) {
        if ($serviceStatus.Healthy) {
            Test-Passed "$($service.Name) is running and healthy" "Port $($service.Port)"
        } else {
            Test-Warning "$($service.Name) is running but not healthy" $serviceStatus.Message
        }
    } else {
        Test-Failed "$($service.Name) is not running" $serviceStatus.Message
    }
}

# Test Elasticsearch health
Write-Host ""
Write-Host "Testing Elasticsearch cluster health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    
    if ($health.status -eq "green" -or $health.status -eq "yellow") {
        Test-Passed "Elasticsearch cluster health" "Status: $($health.status)"
    } else {
        Test-Warning "Elasticsearch cluster health" "Status: $($health.status)"
    }
} catch {
    Test-Failed "Elasticsearch cluster health" $_.Exception.Message
}

# Test Jaeger UI
Write-Host ""
Write-Host "Testing Jaeger UI..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:16686" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Test-Passed "Jaeger UI accessible" "http://localhost:16686"
    } else {
        Test-Warning "Jaeger UI accessible" "HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Jaeger UI accessible" $_.Exception.Message
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })


