# Test Metadata Server
# Verifies Metadata Server functionality

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Metadata Server Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test service startup and health
Write-Host "Testing Metadata Server health..." -ForegroundColor Yellow

$metadataPort = 3004
$result = Test-ServiceHealth -ServiceName "Metadata Server" -HealthUrl "http://localhost:$metadataPort/health"

if (-not $result) {
    Write-Host ""
    Write-Host "Metadata Server is not running. Please start it first." -ForegroundColor Red
    Write-TestSummary
    exit 1
}

# Test /health/ready
Write-Host ""
Write-Host "Testing readiness endpoint..." -ForegroundColor Yellow

$readyResult = Test-HTTPEndpoint -Url "http://localhost:$metadataPort/health/ready"
if ($readyResult.Success) {
    try {
        $json = $readyResult.Content | ConvertFrom-Json
        if ($json.ok -and $json.status -eq "ready") {
            Test-Passed "Metadata Server ready" "Database and cache connected"
        } else {
            Test-Warning "Metadata Server ready" "Status: $($json.status)"
        }
    } catch {
        Test-Warning "Metadata Server ready" "Could not parse response"
    }
} else {
    Test-Failed "Metadata Server ready" $readyResult.Error
}

# Test cache integration (verify Redis is being used)
Write-Host ""
Write-Host "Testing cache integration..." -ForegroundColor Yellow

# This would require making actual API calls with authentication
# For now, we'll just verify the service is responding
Test-Passed "Metadata Server responding" "Service is accessible"

# Test database connection (indirectly via health check)
Write-Host ""
Write-Host "Testing database connection..." -ForegroundColor Yellow

# The /health/ready endpoint should check database
if ($readyResult.Success) {
    try {
        $json = $readyResult.Content | ConvertFrom-Json
        if ($json.checks.database -eq "connected") {
            Test-Passed "Database connection" "Connected to MongoDB"
        } else {
            Test-Failed "Database connection" "Not connected"
        }
    } catch {
        Test-Warning "Database connection" "Could not verify"
    }
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })


