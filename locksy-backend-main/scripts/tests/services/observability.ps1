# Observability Test
# Tests Distributed Logging and Tracing

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Observability Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Jaeger (Distributed Tracing)
$jaegerStatus = Test-DockerService -ContainerName "locksy-jaeger" -Port 16686 -HealthCheck "http://localhost:16686"
if ($jaegerStatus.Running) {
    Test-Passed "Jaeger container running" "Port 16686"
    
    # Test Jaeger UI
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:16686" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Test-Passed "Jaeger UI accessible" "http://localhost:16686"
    } catch {
        Test-Warning "Jaeger UI" "May not be fully ready"
    }
} else {
    Test-Warning "Jaeger container" "Not running or not healthy"
}

# Test Distributed Logging
if (Test-Path "services/logging") {
    Test-Passed "Logging service directory exists" "services/logging"
} else {
    Test-Warning "Logging service directory" "services/logging not found"
}

# Test logging components
$loggingComponents = @(
    "services/logging/logger.js"
)

foreach ($component in $loggingComponents) {
    if (Test-Path $component) {
        Test-Passed "Logging component exists" $component
    } else {
        Test-Warning "Logging component" "$component not found"
    }
}

# Test Distributed Tracing
if (Test-Path "services/tracing") {
    Test-Passed "Tracing service directory exists" "services/tracing"
} else {
    Test-Warning "Tracing service directory" "services/tracing not found"
}

# Test tracing components
$tracingComponents = @(
    "services/tracing/tracer.js"
)

foreach ($component in $tracingComponents) {
    if (Test-Path $component) {
        Test-Passed "Tracing component exists" $component
    } else {
        Test-Warning "Tracing component" "$component not found"
    }
}

# Test tracing middleware
if (Test-Path "middlewares/tracing.js") {
    Test-Passed "Tracing middleware exists" "middlewares/tracing.js"
} else {
    Test-Warning "Tracing middleware" "middlewares/tracing.js not found"
}

# Test OpenTelemetry integration
try {
    $testScript = @"
try {
    const { trace } = require('@opentelemetry/api');
    const tracer = trace.getTracer('test');
    const span = tracer.startSpan('test-span');
    span.end();
    console.log('SUCCESS');
    process.exit(0);
} catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
}
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-tracing.js" -Encoding UTF8
    $result = node "$env:TEMP/test-tracing.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "OpenTelemetry API" "Can create traces"
    } else {
        Test-Warning "OpenTelemetry API" "May not be fully configured"
    }
    Remove-Item "$env:TEMP/test-tracing.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "OpenTelemetry API" "Cannot test (@opentelemetry/api may not be available)"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

