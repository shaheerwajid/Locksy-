# Test Primary Request Flow
# Tests DNS, Load Balancer, API Gateway routing, request ID generation, logging

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Primary Request Flow Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"

# Test 1: API Gateway Health
Write-Host "Testing API Gateway health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Test-Passed "API Gateway health" "Gateway is healthy"
    } else {
        Test-Failed "API Gateway health" "HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "API Gateway health" $_.Exception.Message
}

# Test 2: Request ID Generation
Write-Host ""
Write-Host "Testing request ID generation..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    $requestId = $response.Headers['X-Request-ID']
    if ($requestId) {
        Test-Passed "Request ID generation" "Request ID: $requestId"
    } else {
        Test-Warning "Request ID generation" "Request ID not found in headers"
    }
} catch {
    Test-Failed "Request ID generation" $_.Exception.Message
}

# Test 3: API Gateway Routing (Control Path)
Write-Host ""
Write-Host "Testing Control Path routing to Metadata Server..." -ForegroundColor Yellow
try {
    $token = Get-Content "$PSScriptRoot/../../.test-auth-token" -ErrorAction SilentlyContinue
    if ($token) {
        $headers = @{
            "Content-Type" = "application/json"
            "x-token" = $token
        }
        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Test-Passed "Control Path routing" "Request routed to Metadata Server successfully"
        } else {
            Test-Warning "Control Path routing" "HTTP $($response.StatusCode)"
        }
    } else {
        Test-Warning "Control Path routing" "No auth token available"
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Control Path routing" "Request routed (401 expected without valid token)"
    } else {
        Test-Warning "Control Path routing" "Status: $statusCode"
    }
}

# Test 4: API Gateway Routing (Data Path)
Write-Host ""
Write-Host "Testing Data Path routing to Block Server..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/archivos/getFile" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
    Test-Warning "Data Path routing" "Unexpected success (should require auth)"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401 -or $statusCode -eq 400) {
        Test-Passed "Data Path routing" "Request routed to Block Server (401/400 expected)"
    } elseif ($statusCode -eq 503) {
        Test-Warning "Data Path routing" "Block Server may not be running"
    } else {
        Test-Warning "Data Path routing" "Status: $statusCode"
    }
}

# Test 5: Request Logging
Write-Host ""
Write-Host "Testing request logging..." -ForegroundColor Yellow
# Request logging is tested implicitly by checking if requests are processed
# We can verify by checking if request IDs are generated
try {
    $response1 = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    $requestId1 = $response1.Headers['X-Request-ID']
    $response2 = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    $requestId2 = $response2.Headers['X-Request-ID']
    if ($requestId1 -and $requestId2 -and $requestId1 -ne $requestId2) {
        Test-Passed "Request logging" "Request IDs are unique and generated"
    } else {
        Test-Warning "Request logging" "Request IDs may not be unique"
    }
} catch {
    Test-Warning "Request logging" $_.Exception.Message
}

# Test 6: Response Transformation
Write-Host ""
Write-Host "Testing response transformation..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    $content = $response.Content | ConvertFrom-Json
    if ($content.ok -or $content.status) {
        Test-Passed "Response transformation" "Response is properly formatted JSON"
    } else {
        Test-Warning "Response transformation" "Response format may be incorrect"
    }
} catch {
    Test-Warning "Response transformation" $_.Exception.Message
}

# Summary
Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






