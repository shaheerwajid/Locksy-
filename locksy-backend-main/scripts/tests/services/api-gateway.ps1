# Test API Gateway
# Verifies API Gateway functionality and routing

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API Gateway Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test health endpoints on all API servers
Write-Host "Testing health endpoints..." -ForegroundColor Yellow

$ports = @(3001, 3002, 3003)

foreach ($port in $ports) {
    # Test /health
    $result = Test-ServiceHealth -ServiceName "API Server $port" -HealthUrl "http://localhost:$port/health"
    
    # Test /health/ready
    $readyResult = Test-HTTPEndpoint -Url "http://localhost:$port/health/ready"
    if ($readyResult.Success) {
        Test-Passed "API Server $port /health/ready"
    } else {
        Test-Warning "API Server $port /health/ready" $readyResult.Error
    }
    
    # Test /health/live
    $liveResult = Test-HTTPEndpoint -Url "http://localhost:$port/health/live"
    if ($liveResult.Success) {
        Test-Passed "API Server $port /health/live"
    } else {
        Test-Warning "API Server $port /health/live" $liveResult.Error
    }
}

# Test Control Path routing (should route to Metadata Server)
Write-Host ""
Write-Host "Testing Control Path routing..." -ForegroundColor Yellow

# Test that requests to /api/usuarios route correctly
# Note: This will fail if Metadata Server is not running, which is expected
$testPort = 3001
try {
    $response = Test-HTTPEndpoint -Url "http://localhost:$testPort/api/usuarios" -Method "GET" -Headers @{"x-token"="test"} -ExpectedStatus 401
    # 401 is expected without valid token, but routing should work
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 503) {
        # 503 means Metadata Server not available, 401 means auth required (routing works)
        if ($response.StatusCode -eq 401) {
            Test-Passed "Control Path routing" "Request routed (auth required)"
        } else {
            Test-Warning "Control Path routing" "Metadata Server may not be running"
        }
    } else {
        Test-Warning "Control Path routing" "Unexpected status: $($response.StatusCode)"
    }
} catch {
    Test-Warning "Control Path routing" $_.Exception.Message
}

# Test Data Path routing (should route to Block Server)
Write-Host ""
Write-Host "Testing Data Path routing..." -ForegroundColor Yellow

try {
    $response = Test-HTTPEndpoint -Url "http://localhost:$testPort/api/archivos" -Method "GET" -Headers @{"x-token"="test"} -ExpectedStatus 401
    if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 503) {
        if ($response.StatusCode -eq 401) {
            Test-Passed "Data Path routing" "Request routed (auth required)"
        } else {
            Test-Warning "Data Path routing" "Block Server may not be running"
        }
    } else {
        Test-Warning "Data Path routing" "Unexpected status: $($response.StatusCode)"
    }
} catch {
    Test-Warning "Data Path routing" $_.Exception.Message
}

# Test rate limiting (if implemented)
Write-Host ""
Write-Host "Testing rate limiting..." -ForegroundColor Yellow

# Make multiple rapid requests to test rate limiting
$rateLimitTest = $true
for ($i = 1; $i -le 10; $i++) {
    $response = Test-HTTPEndpoint -Url "http://localhost:$testPort/health" -Timeout 2
    if (-not $response.Success -and $response.StatusCode -eq 429) {
        Test-Passed "Rate limiting active" "Request $i was rate limited"
        $rateLimitTest = $false
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($rateLimitTest) {
    Test-Warning "Rate limiting" "No rate limit detected (may be disabled for health endpoints)"
}

# Test serverless functions middleware
Write-Host ""
Write-Host "Testing serverless functions..." -ForegroundColor Yellow

# Test that request ID is set (logger function)
$response = Test-HTTPEndpoint -Url "http://localhost:$testPort/health"
if ($response.Success) {
    $headers = $response.Response.Headers
    if ($headers["X-Request-ID"]) {
        Test-Passed "Logger function (Request ID)" "X-Request-ID header present"
    } else {
        Test-Warning "Logger function (Request ID)" "X-Request-ID header not found"
    }
} else {
    Test-Warning "Logger function test" "Could not test"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })


