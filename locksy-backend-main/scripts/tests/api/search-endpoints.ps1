# Test Search Endpoints
# Tests search-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Search Endpoints Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"
$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

# Test 1: Aggregate Search
Write-Host "Testing GET /api/search/search?q=query..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $query = "test"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search?q=$query&limit=10" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.results) {
                Test-Passed "Aggregate search" "Search completed successfully"
                Write-Host "  Results: Users=$($result.results.users.Count), Messages=$($result.results.messages.Count), Groups=$($result.results.groups.Count)" -ForegroundColor Gray
            } else {
                Test-Warning "Aggregate search" "Unexpected response format"
            }
        } else {
            Test-Warning "Aggregate search" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            Test-Failed "Aggregate search" "Authentication required"
        } else {
            Test-Warning "Aggregate search" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Aggregate search" "No auth token available"
}

# Test 2: User Search
Write-Host ""
Write-Host "Testing GET /api/search/search/users?q=query..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $query = "test"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search/users?q=$query&limit=10" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.users) {
                Test-Passed "User search" "User search completed successfully"
                Write-Host "  Found $($result.users.Count) users" -ForegroundColor Gray
            } else {
                Test-Warning "User search" "Unexpected response format"
            }
        } else {
            Test-Warning "User search" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "User search" $_.Exception.Message
    }
} else {
    Test-Warning "User search" "No auth token available"
}

# Test 3: Message Search
Write-Host ""
Write-Host "Testing GET /api/search/search/messages?q=query..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $query = "test"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search/messages?q=$query&limit=20" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.messages) {
                Test-Passed "Message search" "Message search completed successfully"
                Write-Host "  Found $($result.messages.Count) messages" -ForegroundColor Gray
            } else {
                Test-Warning "Message search" "Unexpected response format"
            }
        } else {
            Test-Warning "Message search" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Message search" $_.Exception.Message
    }
} else {
    Test-Warning "Message search" "No auth token available"
}

# Test 4: Group Search
Write-Host ""
Write-Host "Testing GET /api/search/search/groups?q=query..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $query = "test"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search/groups?q=$query&limit=10" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.groups) {
                Test-Passed "Group search" "Group search completed successfully"
                Write-Host "  Found $($result.groups.Count) groups" -ForegroundColor Gray
            } else {
                Test-Warning "Group search" "Unexpected response format"
            }
        } else {
            Test-Warning "Group search" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Group search" $_.Exception.Message
    }
} else {
    Test-Warning "Group search" "No auth token available"
}

# Test 5: Unauthorized Access (no token)
Write-Host ""
Write-Host "Testing unauthorized access to search endpoints..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search?q=test" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
    Test-Failed "Unauthorized access protection" "Endpoint should require authentication"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Unauthorized access protection" "Endpoint correctly requires authentication"
    } else {
        Test-Warning "Unauthorized access protection" "Unexpected status code: $statusCode"
    }
}

# Test 6: Empty Query
Write-Host ""
Write-Host "Testing search with empty query..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/search/search?q=" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        Test-Warning "Empty query validation" "Endpoint should reject empty queries"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400) {
            Test-Passed "Empty query validation" "Empty query correctly rejected"
        } else {
            Test-Warning "Empty query validation" "Unexpected status code: $statusCode"
        }
    }
} else {
    Test-Warning "Empty query validation" "No auth token available"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






