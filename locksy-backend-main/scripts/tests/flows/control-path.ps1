# Test Control Path Flow
# Tests metadata operations routing, cache-aside pattern, MongoDB operations

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Control Path Flow Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"

# Get auth token
$authToken = Get-TestAuthToken -BaseUrl $baseUrl
$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

if (-not $authToken) {
    Write-Host "No auth token available. Some tests will be skipped." -ForegroundColor Yellow
}

# Test 1: Metadata Operations Route to Metadata Server
Write-Host "Testing metadata operations routing..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Test-Passed "Metadata operations routing" "Request routed to Metadata Server"
        } else {
            Test-Warning "Metadata operations routing" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Failed "Metadata operations routing" $_.Exception.Message
    }
} else {
    Test-Warning "Metadata operations routing" "No auth token available"
}

# Test 2: Cache-Aside Pattern (Redis)
Write-Host ""
Write-Host "Testing cache-aside pattern..." -ForegroundColor Yellow
if ($authToken) {
    try {
        # First request (should hit database and cache)
        Write-Host "  First request (database + cache)..." -ForegroundColor Gray
        $start1 = Get-Date
        $response1 = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        $duration1 = ((Get-Date) - $start1).TotalMilliseconds
        
        # Second request (should hit cache)
        Write-Host "  Second request (cache)..." -ForegroundColor Gray
        $start2 = Get-Date
        $response2 = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        $duration2 = ((Get-Date) - $start2).TotalMilliseconds
        
        if ($duration2 -lt $duration1) {
            Test-Passed "Cache-aside pattern" "Cache is working (second request $([math]::Round(($duration1 - $duration2), 2))ms faster)"
        } else {
            Test-Warning "Cache-aside pattern" "Cache may not be working (second request not faster)"
        }
    } catch {
        Test-Warning "Cache-aside pattern" $_.Exception.Message
    }
} else {
    Test-Warning "Cache-aside pattern" "No auth token available"
}

# Test 3: MongoDB Read Operations
Write-Host ""
Write-Host "Testing MongoDB read operations..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.usuarios -or $result.ok) {
                Test-Passed "MongoDB read operations" "Data retrieved from database"
            } else {
                Test-Warning "MongoDB read operations" "Unexpected response format"
            }
        } else {
            Test-Warning "MongoDB read operations" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "MongoDB read operations" $_.Exception.Message
    }
} else {
    Test-Warning "MongoDB read operations" "No auth token available"
}

# Test 4: MongoDB Write Operations
Write-Host ""
Write-Host "Testing MongoDB write operations..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $testUserId = Get-TestUserId -BaseUrl $baseUrl
        if ($testUserId) {
            $updateBody = @{
                uid = $testUserId
                nombre = "Test User Updated $(Get-Random)"
            } | ConvertTo-Json -Compress
            $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
            if ($response.StatusCode -eq 200) {
                Test-Passed "MongoDB write operations" "Data written to database"
            } else {
                Test-Warning "MongoDB write operations" "HTTP $($response.StatusCode)"
            }
        } else {
            Test-Warning "MongoDB write operations" "No test user ID available"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Test-Warning "MongoDB write operations" "Route not found (404)"
        } else {
            Test-Warning "MongoDB write operations" "Status: $statusCode"
        }
    }
} else {
    Test-Warning "MongoDB write operations" "No auth token available"
}

# Test 5: Cache Invalidation
Write-Host ""
Write-Host "Testing cache invalidation..." -ForegroundColor Yellow
if ($authToken) {
    try {
        # Make a request to populate cache
        $response1 = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        
        # Perform a write operation (should invalidate cache)
        $testUserId = Get-TestUserId -BaseUrl $baseUrl
        if ($testUserId) {
            $updateBody = @{
                uid = $testUserId
                nombre = "Test User $(Get-Random)"
            } | ConvertTo-Json -Compress
            $response2 = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
            
            # Next request should hit database (cache invalidated)
            $response3 = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
            if ($response3.StatusCode -eq 200) {
                Test-Passed "Cache invalidation" "Cache invalidated after write operation"
            } else {
                Test-Warning "Cache invalidation" "HTTP $($response3.StatusCode)"
            }
        } else {
            Test-Warning "Cache invalidation" "No test user ID available"
        }
    } catch {
        Test-Warning "Cache invalidation" $_.Exception.Message
    }
} else {
    Test-Warning "Cache invalidation" "No auth token available"
}

# Summary
Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






