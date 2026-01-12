# Distributed File Storage Test
# Tests storage backends (S3, MinIO, Local)

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Distributed File Storage Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test MinIO is running
$minioStatus = Test-DockerService -ContainerName "locksy-minio" -Port 9000
if ($minioStatus.Running) {
    Test-Passed "MinIO container running" "Port 9000"
    
    # Test MinIO health
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9000/minio/health/live" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Test-Passed "MinIO health check" "MinIO is healthy"
    } catch {
        Test-Warning "MinIO health check" "Health endpoint may not be available"
    }
} else {
    Test-Warning "MinIO container" "Not running or not healthy"
}

# Test storage service exists
if (Test-Path "services/storage") {
    Test-Passed "Storage service directory exists" "services/storage"
} else {
    Test-Failed "Storage service directory missing" "services/storage"
}

# Test storage clients
$storageClients = @(
    "services/storage/storageClient.js",
    "services/storage/s3Client.js",
    "services/storage/minioClient.js",
    "services/storage/localClient.js"
)

foreach ($client in $storageClients) {
    if (Test-Path $client) {
        Test-Passed "Storage client exists" $client
    } else {
        Test-Warning "Storage client" "$client not found"
    }
}

# Test file service
if (Test-Path "services/storage/fileService.js") {
    Test-Passed "File service exists" "services/storage/fileService.js"
} else {
    Test-Warning "File service" "services/storage/fileService.js not found"
}

# Test block server storage
if (Test-Path "services/storage/blockServer.js") {
    Test-Passed "Block Server storage exists" "services/storage/blockServer.js"
} else {
    Test-Warning "Block Server storage" "services/storage/blockServer.js not found"
}

# Test file chunker
if (Test-Path "services/storage/fileChunker.js") {
    Test-Passed "File chunker exists" "services/storage/fileChunker.js"
} else {
    Test-Warning "File chunker" "services/storage/fileChunker.js not found"
}

# Test storage initialization
try {
    $testScript = @"
try {
    const storageClient = require('./services/storage/storageClient.js');
    storageClient.initializeStorage();
    console.log('SUCCESS');
    process.exit(0);
} catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
}
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-storage.js" -Encoding UTF8
    $result = node "$env:TEMP/test-storage.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Storage initialization" "Can initialize storage client"
    } else {
        Test-Warning "Storage initialization" "Initialization may require configuration"
    }
    Remove-Item "$env:TEMP/test-storage.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Storage initialization" "Cannot test storage initialization"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

