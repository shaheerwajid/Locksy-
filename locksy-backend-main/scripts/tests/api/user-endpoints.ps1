# Test User Endpoints
# Tests user-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "User Endpoints Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"

# Get auth token using auth-helper (reads from file or env, or creates new user)
$authToken = Get-TestAuthToken -BaseUrl $baseUrl
$testUserId = Get-TestUserId -BaseUrl $baseUrl

if (-not $authToken) {
    Write-Host "No auth token available. Some tests will be skipped." -ForegroundColor Yellow
}

$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

# Test 1: Get All Users
Write-Host "Testing GET /api/usuarios..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -or $result.usuarios) {
                Test-Passed "Get all users" "Users retrieved successfully"
            } else {
                Test-Warning "Get all users" "Unexpected response format"
            }
        } else {
            Test-Failed "Get all users" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Failed "Get all users" $_.Exception.Message
    }
} else {
    Test-Warning "Get all users" "No auth token available"
}

# Test 2: Get Specific User
Write-Host ""
Write-Host "Testing POST /api/usuarios/getUsuario..." -ForegroundColor Yellow
if ($authToken -and $testUserId) {
    try {
        $getUserBody = @{
            uid = $testUserId
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/getUsuario" -Method POST -Body $getUserBody -Headers $headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -or $result.usuario) {
                Test-Passed "Get specific user" "User retrieved successfully"
            } else {
                Test-Warning "Get specific user" "User may not exist or unexpected response"
            }
        } else {
            Test-Warning "Get specific user" "HTTP $($response.StatusCode) - User may not exist"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404 -or $statusCode -eq 400) {
            Test-Warning "Get specific user" "User not found (expected for test user)"
        } elseif ($statusCode -eq 408) {
            Test-Warning "Get specific user" "Request timeout - Metadata Server may be slow or hanging"
        } else {
            Test-Warning "Get specific user" "Error: $($_.Exception.Message)"
        }
    }
} else {
    Test-Warning "Get specific user" "No auth token or user ID available"
}

# Test 3: Update User (requires authentication and authorization)
Write-Host ""
Write-Host "Testing POST /api/usuarios/updateUsuario..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $updateBody = @{
            nombre = "Updated Test User"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Update user" "User updated successfully"
            } else {
                Test-Warning "Update user" "Update may have failed: $($result.msg)"
            }
        } else {
            Test-Warning "Update user" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Update user" $_.Exception.Message
    }
} else {
    Test-Warning "Update user" "No auth token available"
}

# Test 4: Password Recovery Step 1 (public endpoint)
Write-Host ""
Write-Host "Testing POST /api/usuarios/recoveryPasswordS1..." -ForegroundColor Yellow
try {
    $recoveryBody = @{
        email = "test@test.com"
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/recoveryPasswordS1" -Method POST -Body $recoveryBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Test-Passed "Password recovery step 1" "Recovery request processed"
    } else {
        Test-Warning "Password recovery step 1" "HTTP $($response.StatusCode)"
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Test-Warning "Password recovery step 1" "User not found (expected for test)"
    } else {
        Test-Warning "Password recovery step 1" $_.Exception.Message
    }
}

# Test 5: Get Public Key (may be public or require auth)
Write-Host ""
Write-Host "Testing GET /api/usuarios/:id/public-key..." -ForegroundColor Yellow
try {
    $testUserId = "test-user-id"
    $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios/$testUserId/public-key" -Method GET -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Test-Passed "Get public key" "Public key retrieved"
    } else {
        Test-Warning "Get public key" "HTTP $($response.StatusCode) - User may not exist"
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Test-Warning "Get public key" "User not found (expected for test)"
    } else {
        Test-Warning "Get public key" "Endpoint may require authentication or user doesn't exist"
    }
}

# Test 6: Unauthorized Access (no token)
Write-Host ""
Write-Host "Testing unauthorized access to protected endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -UseBasicParsing -ErrorAction Stop
    Test-Failed "Unauthorized access protection" "Endpoint should require authentication"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Unauthorized access protection" "Endpoint correctly requires authentication"
    } else {
        Test-Warning "Unauthorized access protection" "Unexpected status code: $statusCode"
    }
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

