# Docker Helper Functions
# Utilities for managing Docker services

function Start-DockerServices {
    Write-Host "Starting Docker services..." -ForegroundColor Cyan
    
    if (-not (Test-Path "docker-compose.yml")) {
        Write-Host "  [ERROR] docker-compose.yml not found" -ForegroundColor Red
        return $false
    }
    
    try {
        # Check if docker-compose or docker compose
        $useDockerCompose = $true
        try {
            docker-compose --version 2>&1 | Out-Null
        } catch {
            $useDockerCompose = $false
        }
        
        if ($useDockerCompose) {
            docker-compose up -d 2>&1 | Out-Null
        } else {
            docker compose up -d 2>&1 | Out-Null
        }
        
        Write-Host "  [OK] Docker services started" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERROR] Failed to start Docker services: $_" -ForegroundColor Red
        return $false
    }
}

function Stop-DockerServices {
    Write-Host "Stopping Docker services..." -ForegroundColor Cyan
    
    if (-not (Test-Path "docker-compose.yml")) {
        return $false
    }
    
    try {
        $useDockerCompose = $true
        try {
            docker-compose --version 2>&1 | Out-Null
        } catch {
            $useDockerCompose = $false
        }
        
        if ($useDockerCompose) {
            docker-compose down 2>&1 | Out-Null
        } else {
            docker compose down 2>&1 | Out-Null
        }
        
        Write-Host "  [OK] Docker services stopped" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "  [ERROR] Failed to stop Docker services: $_" -ForegroundColor Red
        return $false
    }
}

function Test-DockerService {
    param(
        [string]$ContainerName,
        [int]$Port = 0,
        [string]$HealthCheck = ""
    )
    
    $containerRunning = Test-DockerContainer -ContainerName $ContainerName
    
    if (-not $containerRunning) {
        return @{
            Running = $false
            Healthy = $false
            Message = "Container not running"
        }
    }
    
    $result = @{
        Running = $true
        Healthy = $false
        Message = ""
    }
    
    # If port specified, test port
    if ($Port -gt 0) {
        $portOpen = Test-Port -Port $Port
        if (-not $portOpen) {
            $result.Message = "Port $Port not accessible"
            return $result
        }
    }
    
    # If health check specified, test it
    if ($HealthCheck) {
        try {
            $response = Invoke-WebRequest -Uri $HealthCheck -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $result.Healthy = ($response.StatusCode -eq 200)
            $result.Message = if ($result.Healthy) { "Healthy" } else { "Health check failed" }
        } catch {
            $result.Message = "Health check error: $($_.Exception.Message)"
        }
    } else {
        $result.Healthy = $true
        $result.Message = "Running"
    }
    
    return $result
}

function Wait-ForDockerService {
    param(
        [string]$ContainerName,
        [int]$Port = 0,
        [string]$HealthCheck = "",
        [int]$MaxWait = 60,
        [int]$Interval = 2
    )
    
    $elapsed = 0
    
    while ($elapsed -lt $MaxWait) {
        $result = Test-DockerService -ContainerName $ContainerName -Port $Port -HealthCheck $HealthCheck
        
        if ($result.Running -and $result.Healthy) {
            return $true
        }
        
        Start-Sleep -Seconds $Interval
        $elapsed += $Interval
    }
    
    return $false
}

function Get-DockerServiceStatus {
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
    
    $status = @{}
    
    foreach ($service in $services) {
        $result = Test-DockerService `
            -ContainerName $service.Container `
            -Port $service.Port `
            -HealthCheck $service.HealthCheck
        
        $status[$service.Name] = $result
    }
    
    return $status
}

function Show-DockerServiceStatus {
    $status = Get-DockerServiceStatus
    
    Write-Host ""
    Write-Host "Docker Services Status:" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    foreach ($service in $status.GetEnumerator()) {
        $color = if ($service.Value.Healthy) { "Green" } elseif ($service.Value.Running) { "Yellow" } else { "Red" }
        $statusText = if ($service.Value.Healthy) { "Healthy" } elseif ($service.Value.Running) { "Running" } else { "Not Running" }
        
        Write-Host "  $($service.Key): $statusText" -ForegroundColor $color
        if ($service.Value.Message -and -not $service.Value.Healthy) {
            Write-Host "    $($service.Value.Message)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}


