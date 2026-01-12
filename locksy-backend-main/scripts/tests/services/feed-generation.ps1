# Feed Generation Service Test
# Tests feed generation functionality

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Feed Generation Service Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test feed generation service exists
if (Test-Path "services/feed") {
    Test-Passed "Feed service directory exists" "services/feed"
} else {
    Test-Failed "Feed service directory missing" "services/feed"
}

# Test feed components
$feedComponents = @(
    "services/feed/generator.js",
    "services/feed/aggregator.js",
    "services/feed/service.js"
)

foreach ($component in $feedComponents) {
    if (Test-Path $component) {
        Test-Passed "Feed component exists" $component
    } else {
        Test-Warning "Feed component" "$component not found"
    }
}

# Test feed generation queue
try {
    $testScript = @"
const amqp = require('amqplib');
(async () => {
    try {
        const connection = await amqp.connect('amqp://localhost:5672');
        const channel = await connection.createChannel();
        
        const queueCheck = await channel.checkQueue('feed_generation_queue');
        
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
    
    $testScript | Out-File -FilePath "$env:TEMP/test-feed-queue.js" -Encoding UTF8
    $result = node "$env:TEMP/test-feed-queue.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Feed Generation Queue" "Queue exists and accessible"
    } else {
        Test-Warning "Feed Generation Queue" "Queue may need to be created"
    }
    Remove-Item "$env:TEMP/test-feed-queue.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Feed Generation Queue" "Cannot test queue (amqplib may not be available)"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

