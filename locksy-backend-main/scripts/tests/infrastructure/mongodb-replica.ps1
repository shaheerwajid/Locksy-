# Test MongoDB Replica Set
# Verifies MongoDB replica set configuration and operations

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MongoDB Replica Set Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if MongoDB containers are running
Write-Host "Checking MongoDB containers..." -ForegroundColor Yellow

$containers = @(
    @{Name="Primary"; Container="locksy-mongodb-primary"; Port=27017},
    @{Name="Secondary1"; Container="locksy-mongodb-secondary1"; Port=27018},
    @{Name="Secondary2"; Container="locksy-mongodb-secondary2"; Port=27019}
)

foreach ($container in $containers) {
    $running = Test-DockerContainer -ContainerName $container.Container
    if ($running) {
        Test-Passed "$($container.Name) container running" "Port $($container.Port)"
    } else {
        Test-Failed "$($container.Name) container running" "Container not found"
    }
}

# Test connection strings
Write-Host ""
Write-Host "Testing connection strings..." -ForegroundColor Yellow

$connectionStrings = @(
    @{Name="Primary"; Connection="mongodb://localhost:27017/cryptochat"},
    @{Name="Secondary1"; Connection="mongodb://localhost:27018/cryptochat"},
    @{Name="Secondary2"; Connection="mongodb://localhost:27019/cryptochat"},
    @{Name="Replica Set"; Connection="mongodb://localhost:27017,localhost:27018,localhost:27019/cryptochat?replicaSet=rs0"}
)

foreach ($conn in $connectionStrings) {
    $portOpen = Test-Port -Port ($conn.Connection -match '(\d{5})' | ForEach-Object { $matches[1] })
    if ($portOpen) {
        Test-Passed "$($conn.Name) connection port accessible"
    } else {
        Test-Warning "$($conn.Name) connection port accessible" "Port may not be ready"
    }
}

# Test replica set status (requires mongosh or mongo client)
Write-Host ""
Write-Host "Testing replica set status..." -ForegroundColor Yellow

try {
    # Try to check replica set status using mongosh
    $rsStatus = docker exec locksy-mongodb-primary mongosh --quiet --eval "rs.status().members.length" 2>&1
    
    if ($rsStatus -match "^\d+$") {
        $memberCount = [int]$rsStatus
        if ($memberCount -ge 3) {
            Test-Passed "Replica set has $memberCount members" "Expected at least 3"
        } else {
            Test-Warning "Replica set has $memberCount members" "Expected 3"
        }
    } else {
        # Try alternative method
        $rsStatus = docker exec locksy-mongodb-primary mongosh --quiet --eval "rs.status()" 2>&1
        if ($rsStatus -match "members") {
            Test-Passed "Replica set status accessible"
        } else {
            Test-Warning "Replica set status" "Could not verify member count"
        }
    }
} catch {
    Test-Warning "Replica set status check" "mongosh may not be available, replica set may need manual initialization"
}

# Test read preference configuration
Write-Host ""
Write-Host "Testing read preference..." -ForegroundColor Yellow

# Check if environment variable is set
if ($env:MONGODB_READ_PREFERENCE) {
    Test-Passed "Read preference configured" $env:MONGODB_READ_PREFERENCE
} else {
    Test-Warning "Read preference configured" "Using default (primary)"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })


