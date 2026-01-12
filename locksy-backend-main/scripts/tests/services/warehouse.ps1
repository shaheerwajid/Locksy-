# Data Warehouse & Analytics Test
# Tests data warehouse, ETL, and analytics functionality

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Warehouse & Analytics Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Data Warehouse service health
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3009/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    if ($health.ok -and $health.status -eq "healthy") {
        Test-Passed "Data Warehouse service health" "http://localhost:3009/health"
    } else {
        Test-Warning "Data Warehouse service health" "Service may not be fully ready"
    }
} catch {
    Test-Failed "Data Warehouse service health" "Service not responding"
}

# Test warehouse service exists
if (Test-Path "services/warehouse") {
    Test-Passed "Warehouse service directory exists" "services/warehouse"
} else {
    Test-Failed "Warehouse service directory missing" "services/warehouse"
}

# Test ETL components
$etlComponents = @(
    "services/warehouse/extractor.js",
    "services/warehouse/processor.js",
    "services/warehouse/loader.js"
)

foreach ($component in $etlComponents) {
    if (Test-Path $component) {
        Test-Passed "ETL component exists" $component
    } else {
        Test-Warning "ETL component" "$component not found"
    }
}

# Test scheduler
if (Test-Path "services/warehouse/scheduler.js") {
    Test-Passed "Distributed Scheduler exists" "services/warehouse/scheduler.js"
} else {
    Test-Warning "Distributed Scheduler" "services/warehouse/scheduler.js not found"
}

# Test warehouse service
if (Test-Path "services/warehouse/service.js") {
    Test-Passed "Warehouse service exists" "services/warehouse/service.js"
} else {
    Test-Warning "Warehouse service" "services/warehouse/service.js not found"
}

# Test analytics queue
try {
    $testScript = @"
const amqp = require('amqplib');
(async () => {
    try {
        const connection = await amqp.connect('amqp://localhost:5672');
        const channel = await connection.createChannel();
        
        const queueCheck = await channel.checkQueue('analytics_queue');
        
        await channel.close();
        await connection.close();
        console.log('SUCCESS');
        process.exit(0);
    } catch (err) {
        if (err.message.includes('404')) {
            console.log('QUEUE_NOT_FOUND');
        } else {
            console.error('ERROR:', err.message);
        }
        process.exit(1);
    }
})();
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-analytics-queue-warehouse.js" -Encoding UTF8
    $result = node "$env:TEMP/test-analytics-queue-warehouse.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Analytics Queue for Warehouse" "Queue exists and accessible"
    } else {
        Test-Warning "Analytics Queue for Warehouse" "Queue may need to be created"
    }
    Remove-Item "$env:TEMP/test-analytics-queue-warehouse.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Analytics Queue for Warehouse" "Cannot test queue (amqplib may not be available)"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

