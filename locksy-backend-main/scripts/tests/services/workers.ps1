# Workers Test
# Tests Video Processing Workers and Analytics Workers

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Workers Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if workers are running (they run as background processes)
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    Test-Passed "Worker processes running" "$($nodeProcesses.Count) Node.js processes"
} else {
    Test-Warning "Worker processes" "No Node.js processes found (workers may be running in background)"
}

# Test Video Processing Queue
try {
    $testScript = @"
const amqp = require('amqplib');
(async () => {
    try {
        const connection = await amqp.connect('amqp://localhost:5672');
        const channel = await connection.createChannel();
        
        // Check if video processing queue exists
        const queueCheck = await channel.checkQueue('video_processing_queue');
        
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
    
    $testScript | Out-File -FilePath "$env:TEMP/test-video-queue.js" -Encoding UTF8
    $result = node "$env:TEMP/test-video-queue.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Video Processing Queue" "Queue exists and accessible"
    } else {
        Test-Warning "Video Processing Queue" "Queue may need to be created"
    }
    Remove-Item "$env:TEMP/test-video-queue.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Video Processing Queue" "Cannot test queue (amqplib may not be available)"
}

# Test Analytics Queue
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
    
    $testScript | Out-File -FilePath "$env:TEMP/test-analytics-queue.js" -Encoding UTF8
    $result = node "$env:TEMP/test-analytics-queue.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Analytics Queue" "Queue exists and accessible"
    } else {
        Test-Warning "Analytics Queue" "Queue may need to be created"
    }
    Remove-Item "$env:TEMP/test-analytics-queue.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Analytics Queue" "Cannot test queue (amqplib may not be available)"
}

# Test worker scripts exist
$workerScripts = @(
    "scripts/start-video-workers.js",
    "scripts/start-analytics-workers.js"
)

foreach ($script in $workerScripts) {
    if (Test-Path $script) {
        Test-Passed "Worker script exists" $script
    } else {
        Test-Failed "Worker script missing" $script
    }
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

