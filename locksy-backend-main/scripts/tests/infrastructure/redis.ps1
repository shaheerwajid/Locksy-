# Test Redis Connection & Operations
# Verifies Redis connectivity and cache operations

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Redis Connection & Operations Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Redis container is running
Write-Host "Checking Redis container..." -ForegroundColor Yellow

$redisRunning = Test-DockerContainer -ContainerName "locksy-redis"
if ($redisRunning) {
    Test-Passed "Redis container running" "locksy-redis"
} else {
    Test-Failed "Redis container running" "Container not found"
    exit 1
}

# Test Redis port
Write-Host ""
Write-Host "Testing Redis port..." -ForegroundColor Yellow

$portOpen = Test-Port -Port 6379
if ($portOpen) {
    Test-Passed "Redis port accessible" "Port 6379"
} else {
    Test-Failed "Redis port accessible" "Port 6379 not accessible"
}

# Test Redis connection using redis-cli
Write-Host ""
Write-Host "Testing Redis connection..." -ForegroundColor Yellow

try {
    $pingResult = docker exec locksy-redis redis-cli ping 2>&1
    if ($pingResult -match "PONG") {
        Test-Passed "Redis connection" "PING/PONG successful"
    } else {
        Test-Failed "Redis connection" "PING failed: $pingResult"
    }
} catch {
    Test-Failed "Redis connection" $_.Exception.Message
}

# Test Redis SET operation
Write-Host ""
Write-Host "Testing Redis SET operation..." -ForegroundColor Yellow

try {
    $testKey = "test:key:$(Get-Date -Format 'yyyyMMddHHmmss')"
    $testValue = "test-value-123"
    
    $setResult = docker exec locksy-redis redis-cli SET "$testKey" "$testValue" 2>&1
    if ($setResult -match "OK") {
        Test-Passed "Redis SET operation" "Key set successfully"
    } else {
        Test-Failed "Redis SET operation" "SET failed: $setResult"
    }
} catch {
    Test-Failed "Redis SET operation" $_.Exception.Message
}

# Test Redis GET operation
Write-Host ""
Write-Host "Testing Redis GET operation..." -ForegroundColor Yellow

try {
    $getResult = docker exec locksy-redis redis-cli GET "$testKey" 2>&1
    if ($getResult -eq $testValue) {
        Test-Passed "Redis GET operation" "Value retrieved correctly"
    } else {
        Test-Failed "Redis GET operation" "GET failed or value mismatch: $getResult"
    }
} catch {
    Test-Failed "Redis GET operation" $_.Exception.Message
}

# Test Redis TTL functionality
Write-Host ""
Write-Host "Testing Redis TTL functionality..." -ForegroundColor Yellow

try {
    $ttlKey = "test:ttl:$(Get-Date -Format 'yyyyMMddHHmmss')"
    docker exec locksy-redis redis-cli SET "$ttlKey" "ttl-test" EX 10 2>&1 | Out-Null
    
    $ttlResult = docker exec locksy-redis redis-cli TTL "$ttlKey" 2>&1
    if ($ttlResult -match "^\d+$" -and [int]$ttlResult -gt 0 -and [int]$ttlResult -le 10) {
        Test-Passed "Redis TTL functionality" "TTL set correctly: $ttlResult seconds"
    } else {
        Test-Warning "Redis TTL functionality" "TTL result: $ttlResult"
    }
    
    # Clean up
    docker exec locksy-redis redis-cli DEL "$ttlKey" 2>&1 | Out-Null
} catch {
    Test-Warning "Redis TTL functionality" $_.Exception.Message
}

# Test Redis cache invalidation (DELETE)
Write-Host ""
Write-Host "Testing Redis cache invalidation..." -ForegroundColor Yellow

try {
    $delResult = docker exec locksy-redis redis-cli DEL "$testKey" 2>&1
    if ($delResult -match "^\d+$" -and [int]$delResult -eq 1) {
        Test-Passed "Redis cache invalidation" "Key deleted successfully"
    } else {
        Test-Warning "Redis cache invalidation" "Delete result: $delResult"
    }
} catch {
    Test-Warning "Redis cache invalidation" $_.Exception.Message
}

# Test Redis connection from Node.js (if redis package available)
Write-Host ""
Write-Host "Testing Redis connection from Node.js..." -ForegroundColor Yellow

try {
    $testScript = @"
const redis = require('redis');
(async () => {
    try {
        const client = redis.createClient({ url: 'redis://localhost:6379' });
        await client.connect();
        await client.set('nodejs:test', 'success');
        const value = await client.get('nodejs:test');
        await client.del('nodejs:test');
        await client.quit();
        if (value === 'success') {
            console.log('SUCCESS');
            process.exit(0);
        } else {
            console.error('ERROR: Value mismatch');
            process.exit(1);
        }
    } catch (err) {
        console.error('ERROR:', err.message);
        process.exit(1);
    }
})();
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-redis-nodejs.js" -Encoding UTF8
    $result = node "$env:TEMP/test-redis-nodejs.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Redis Node.js connection" "Can connect and perform operations"
    } else {
        Test-Warning "Redis Node.js connection" "redis package may not be available or connection failed"
    }
    Remove-Item "$env:TEMP/test-redis-nodejs.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Redis Node.js connection" "Cannot test Node.js connection (redis package may not be available)"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






