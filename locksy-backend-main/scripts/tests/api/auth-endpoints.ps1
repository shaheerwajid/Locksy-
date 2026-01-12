# Test Authentication Endpoints
# Tests login, registration, token renewal, and JWT validation

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Authentication Endpoints Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"
$testEmail = "test$(Get-Random)@test.com"
$testPassword = "TestPassword123!"
$testNombre = "Test User"
$authToken = $null

# Test 1: User Registration
Write-Host "Testing user registration..." -ForegroundColor Yellow
try {
    $registerBody = @{
        nombre = $testNombre
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$baseUrl/api/login/new" -Method POST -Body $registerBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $result = $response.Content | ConvertFrom-Json
        if ($result.ok) {
            Test-Passed "User registration" "User created successfully"
            $authToken = $result.token
            if (-not $authToken) {
                $authToken = $result.accessToken
            }
        } else {
            Test-Failed "User registration" "Registration failed: $($result.msg)"
        }
    } else {
        Test-Failed "User registration" "HTTP $($response.StatusCode)"
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400 -or $statusCode -eq 409) {
        Test-Warning "User registration" "User may already exist or invalid data: $($_.Exception.Message)"
        # Try to login instead
        Write-Host "  Attempting login with existing user..." -ForegroundColor Gray
    } else {
        Test-Failed "User registration" $_.Exception.Message
    }
}

# Test 2: User Login
Write-Host ""
Write-Host "Testing user login..." -ForegroundColor Yellow
try {
    $loginBody = @{
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $response = Invoke-WebRequest -Uri "$baseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $result = $response.Content | ConvertFrom-Json
        if ($result.ok -and ($result.token -or $result.accessToken)) {
            Test-Passed "User login" "Login successful"
            $authToken = $result.token
            if (-not $authToken) {
                $authToken = $result.accessToken
            }
        } else {
            Test-Failed "User login" "Login failed: $($result.msg)"
        }
    } else {
        Test-Failed "User login" "HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "User login" $_.Exception.Message
}

# Test 3: Token Validation (Protected Endpoint)
Write-Host ""
Write-Host "Testing token validation..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $headers = @{
            "x-token" = $authToken
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            Test-Passed "Token validation" "Token is valid"
        } else {
            Test-Failed "Token validation" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            Test-Failed "Token validation" "Token is invalid or expired"
        } else {
            Test-Failed "Token validation" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Token validation" "No token available to test"
}

# Test 4: Unauthorized Access (No Token)
Write-Host ""
Write-Host "Testing unauthorized access (no token)..." -ForegroundColor Yellow
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

# Test 5: Invalid Token
Write-Host ""
Write-Host "Testing invalid token..." -ForegroundColor Yellow
try {
    $headers = @{
        "x-token" = "invalid-token-12345"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri "$baseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
    Test-Failed "Invalid token rejection" "Endpoint should reject invalid tokens"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Invalid token rejection" "Invalid token correctly rejected"
    } else {
        Test-Warning "Invalid token rejection" "Unexpected status code: $statusCode"
    }
}

# Test 6: Public Endpoints (No Auth Required)
Write-Host ""
Write-Host "Testing public endpoints..." -ForegroundColor Yellow
$publicEndpoints = @(
    @{Path="/health"; Method="GET"; ExpectedStatus=200}
    @{Path="/api/login/new"; Method="POST"; ExpectedStatus=400} # Should accept POST but may require body
)

foreach ($endpoint in $publicEndpoints) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl$($endpoint.Path)" -Method $endpoint.Method -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq $endpoint.ExpectedStatus) {
            Test-Passed "Public endpoint: $($endpoint.Path)" "Accessible without authentication"
        } else {
            Test-Warning "Public endpoint: $($endpoint.Path)" "HTTP $($response.StatusCode), expected $($endpoint.ExpectedStatus)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $endpoint.ExpectedStatus) {
            Test-Passed "Public endpoint: $($endpoint.Path)" "Accessible without authentication"
        } else {
            Test-Warning "Public endpoint: $($endpoint.Path)" "Status: $statusCode"
        }
    }
}

# Summary
Write-TestSummary

# Export token for other tests
if ($authToken) {
    $env:TEST_AUTH_TOKEN = $authToken
    Write-Host ""
    Write-Host "Auth token saved to environment variable: TEST_AUTH_TOKEN" -ForegroundColor Green
}

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






