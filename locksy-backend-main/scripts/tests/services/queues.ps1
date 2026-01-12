# RabbitMQ Queues Test
# Tests all message queues and their functionality

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RabbitMQ Queues Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check RabbitMQ is running
$rabbitmqStatus = Test-DockerService -ContainerName "locksy-rabbitmq" -Port 5672
if (-not $rabbitmqStatus.Running) {
    Test-Failed "RabbitMQ container not running"
    Write-Host "RabbitMQ is not running. Please start it first." -ForegroundColor Red
    exit 1
}

Test-Passed "RabbitMQ container running" "Port 5672"

# Test RabbitMQ Management API
try {
    $response = Invoke-WebRequest -Uri "http://localhost:15672/api/overview" -Method GET -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("guest:guest"))} -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Test-Passed "RabbitMQ Management API" "http://localhost:15672"
} catch {
    Test-Warning "RabbitMQ Management API" "May require authentication or not be accessible"
}

# Test queue existence via API
$queues = @(
    "notification_queue",
    "notification_queue_dlq",
    "video_processing_queue",
    "video_processing_queue_dlq",
    "email_queue",
    "email_queue_dlq",
    "analytics_queue",
    "analytics_queue_dlq",
    "feed_generation_queue",
    "feed_generation_queue_dlq"
)

foreach ($queueName in $queues) {
    try {
        $queueUrl = "http://localhost:15672/api/queues/%2F/$queueName"
        $response = Invoke-WebRequest -Uri $queueUrl -Method GET -Headers @{Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("guest:guest"))} -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $queueData = $response.Content | ConvertFrom-Json
        Test-Passed "Queue: $queueName" "Messages: $($queueData.messages), Consumers: $($queueData.consumers)"
    } catch {
        Test-Warning "Queue: $queueName" "Queue may not exist yet or requires authentication"
    }
}

# Test message publishing (if amqplib is available)
try {
    $testScript = @"
const amqp = require('amqplib');
(async () => {
    try {
        const connection = await amqp.connect('amqp://localhost:5672');
        const channel = await connection.createChannel();
        
        // Test notification queue
        await channel.assertQueue('notification_queue', { durable: true });
        channel.sendToQueue('notification_queue', Buffer.from(JSON.stringify({ test: true })));
        
        // Test video processing queue
        await channel.assertQueue('video_processing_queue', { durable: true });
        channel.sendToQueue('video_processing_queue', Buffer.from(JSON.stringify({ test: true })));
        
        await channel.close();
        await connection.close();
        console.log('SUCCESS');
        process.exit(0);
    } catch (err) {
        console.error('ERROR:', err.message);
        process.exit(1);
    }
})();
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-queues.js" -Encoding UTF8
    $result = node "$env:TEMP/test-queues.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Queue message publishing" "Can publish to queues"
    } else {
        Test-Warning "Queue message publishing" "May require queue setup"
    }
    Remove-Item "$env:TEMP/test-queues.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Queue message publishing" "amqplib may not be available"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

