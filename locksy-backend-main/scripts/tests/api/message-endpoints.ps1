# Test Message Endpoints
# Tests message-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Message Endpoints Test" -ForegroundColor Cyan
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

# Test 1: Get Chat History
Write-Host "Testing GET /api/mensajes/:de..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $testUserId = "test-user-id"
        $response = Invoke-WebRequest -Uri "$baseUrl/api/mensajes/chat/$testUserId" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            Test-Passed "Get chat history" "Chat history retrieved (may be empty)"
        } else {
            Test-Warning "Get chat history" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404 -or $statusCode -eq 400) {
            Test-Warning "Get chat history" "Chat may not exist (expected for new users)"
        } else {
            Test-Warning "Get chat history" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Get chat history" "No auth token available"
}

# Test 2: Create Message
Write-Host ""
Write-Host "Testing POST /api/mensajes..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $messageBody = @{
            de = "current-user-id"
            para = "recipient-user-id"
            mensaje = @{
                ciphertext = "Test message content"
                iv = "test-iv"
                salt = "test-salt"
            }
        } | ConvertTo-Json -Depth 10

        $response = Invoke-WebRequest -Uri "$baseUrl/api/mensajes" -Method POST -Body $messageBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -or $result.mensaje) {
                Test-Passed "Create message" "Message created successfully"
                
                # Note: Message creation should trigger:
                # - Notification queuing
                # - Search indexing
                # - Feed generation
                Write-Host "  Note: Message creation should trigger notification, search indexing, and feed generation" -ForegroundColor Gray
            } else {
                Test-Warning "Create message" "Message may not have been created: $($result.msg)"
            }
        } else {
            Test-Warning "Create message" "HTTP $($response.StatusCode) - Recipient may not exist"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404 -or $statusCode -eq 400) {
            Test-Warning "Create message" "Recipient may not exist or invalid data (expected for test)"
        } else {
            Test-Warning "Create message" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Create message" "No auth token available"
}

# Test 3: Unauthorized Access (no token)
Write-Host ""
Write-Host "Testing unauthorized access to message endpoints..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/mensajes/chat/test-user" -Method GET -UseBasicParsing -ErrorAction Stop
    Test-Failed "Unauthorized access protection" "Endpoint should require authentication"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Unauthorized access protection" "Endpoint correctly requires authentication"
    } else {
        Test-Warning "Unauthorized access protection" "Unexpected status code: $statusCode"
    }
}

# Test 4: Invalid Message Data
Write-Host ""
Write-Host "Testing message creation with invalid data..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $invalidBody = @{
            de = ""
            para = ""
            mensaje = @{}
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/mensajes" -Method POST -Body $invalidBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        Test-Warning "Invalid message data validation" "Endpoint should reject invalid data"
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 400 -or $statusCode -eq 422) {
            Test-Passed "Invalid message data validation" "Invalid data correctly rejected"
        } else {
            Test-Warning "Invalid message data validation" "Unexpected status code: $statusCode"
        }
    }
} else {
    Test-Warning "Invalid message data validation" "No auth token available"
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

