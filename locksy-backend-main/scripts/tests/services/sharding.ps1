# Sharding and Partitioning Test
# Tests Shard Manager and Directory-based Partitioning

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sharding and Partitioning Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Shard Manager service
try {
    # Shard Manager runs as a background process, check if script exists
    if (Test-Path "scripts/start-shard-manager.js") {
        Test-Passed "Shard Manager script exists" "scripts/start-shard-manager.js"
    } else {
        Test-Failed "Shard Manager script missing" "scripts/start-shard-manager.js"
    }
} catch {
    Test-Warning "Shard Manager script" "Cannot verify script"
}

# Test shard manager service exists
if (Test-Path "services/shard-manager") {
    Test-Passed "Shard Manager service directory exists" "services/shard-manager"
} else {
    Test-Failed "Shard Manager service directory missing" "services/shard-manager"
}

# Test shard manager components
$shardComponents = @(
    "services/shard-manager/shardRouter.js",
    "services/shard-manager/shardManager.js",
    "services/shard-manager/index.js"
)

foreach ($component in $shardComponents) {
    if (Test-Path $component) {
        Test-Passed "Shard Manager component exists" $component
    } else {
        Test-Warning "Shard Manager component" "$component not found"
    }
}

# Test partitioning service
if (Test-Path "services/partitioning") {
    Test-Passed "Partitioning service directory exists" "services/partitioning"
} else {
    Test-Warning "Partitioning service directory" "services/partitioning not found"
}

# Test partitioning components
$partitioningComponents = @(
    "services/partitioning/directoryPartitioning.js",
    "services/partitioning/replicationLayer.js"
)

foreach ($component in $partitioningComponents) {
    if (Test-Path $component) {
        Test-Passed "Partitioning component exists" $component
    } else {
        Test-Warning "Partitioning component" "$component not found"
    }
}

# Test MongoDB replica set (for sharding)
try {
    $primaryStatus = Test-DockerService -ContainerName "locksy-mongodb-primary" -Port 27017
    $secondary1Status = Test-DockerService -ContainerName "locksy-mongodb-secondary1" -Port 27018
    $secondary2Status = Test-DockerService -ContainerName "locksy-mongodb-secondary2" -Port 27019
    
    if ($primaryStatus.Running -and $secondary1Status.Running -and $secondary2Status.Running) {
        Test-Passed "MongoDB Replica Set" "All 3 instances running (required for sharding)"
    } else {
        Test-Warning "MongoDB Replica Set" "Some instances may not be running"
    }
} catch {
    Test-Warning "MongoDB Replica Set" "Cannot verify replica set status"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

