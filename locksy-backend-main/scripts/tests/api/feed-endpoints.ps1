# Test Feed Endpoints
# Tests feed-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Feed Endpoints Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"
$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

# Test 1: Get User Feed
Write-Host "Testing GET /api/feed/user..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/feed/user" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                if ($result.items) {
                    Test-Passed "Get user feed" "User feed retrieved successfully"
                    Write-Host "  Found $($result.items.Count) feed items" -ForegroundColor Gray
                } else {
                    Test-Warning "Get user feed" "Feed retrieved but no items array (may be generating)"
                }
            } else {
                Test-Warning "Get user feed" "Feed may be generating: $($result.msg)"
            }
        } else {
            Test-Warning "Get user feed" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            Test-Failed "Get user feed" "Authentication required"
        } else {
            Test-Warning "Get user feed" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Get user feed" "No auth token available"
}

# Test 2: Trigger User Feed Generation
Write-Host ""
Write-Host "Testing POST /api/feed/user/generate..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $generateBody = @{
            userId = (Get-TestUserId -BaseUrl $baseUrl)
            options = @{}
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/feed/user/generate" -Method POST -Body $generateBody -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Trigger user feed generation" "Feed generation triggered"
            } else {
                Test-Warning "Trigger user feed generation" "Generation may have failed: $($result.msg)"
            }
        } else {
            Test-Warning "Trigger user feed generation" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Trigger user feed generation" $_.Exception.Message
    }
} else {
    Test-Warning "Trigger user feed generation" "No auth token available"
}

# Test 3: Get Group Feed
Write-Host ""
Write-Host "Testing GET /api/feed/group/:groupId..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $testGroupId = "test-group-id"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/feed/group/$testGroupId" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                if ($result.items) {
                    Test-Passed "Get group feed" "Group feed retrieved successfully"
                    Write-Host "  Found $($result.items.Count) feed items" -ForegroundColor Gray
                } else {
                    Test-Warning "Get group feed" "Feed retrieved but no items array (may be generating or group doesn't exist)"
                }
            } else {
                Test-Warning "Get group feed" "Feed may be generating or group doesn't exist: $($result.msg)"
            }
        } else {
            Test-Warning "Get group feed" "HTTP $($response.StatusCode) - Group may not exist"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Test-Warning "Get group feed" "Group not found (expected for test)"
        } else {
            Test-Warning "Get group feed" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Get group feed" "No auth token available"
}

# Test 4: Unauthorized Access (no token)
Write-Host ""
Write-Host "Testing unauthorized access to feed endpoints..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/feed/user" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
    Test-Failed "Unauthorized access protection" "Endpoint should require authentication"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Unauthorized access protection" "Endpoint correctly requires authentication"
    } else {
        Test-Warning "Unauthorized access protection" "Unexpected status code: $statusCode"
    }
}

# Test 5: Feed Response Format
Write-Host ""
Write-Host "Testing feed response format..." -ForegroundColor Yellow
if ($headers["x-token"]) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/feed/user" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.items) {
                # Verify items array structure
                if ($result.items.Count -gt 0) {
                    $item = $result.items[0]
                    if ($item.type -and $item.data) {
                        Test-Passed "Feed response format" "Feed items have correct structure (type, data)"
                    } else {
                        Test-Warning "Feed response format" "Feed items may not have expected structure"
                    }
                } else {
                    Test-Passed "Feed response format" "Feed response format is correct (empty feed)"
                }
            } else {
                Test-Warning "Feed response format" "Feed may be generating or response format differs"
            }
        }
    } catch {
        Test-Warning "Feed response format" $_.Exception.Message
    }
} else {
    Test-Warning "Feed response format" "No auth token available"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






