# Create Test User and Run Authenticated Tests
# This script creates a test user, logs in, and runs authenticated API tests

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:3000"
$testEmail = "testuser_$(Get-Date -Format 'yyyyMMddHHmmss')@test.com"
$testPassword = "TestPassword123!"
$testName = "Test User $(Get-Date -Format 'HHmmss')"
$tokenFile = "logs\test-token.txt"
$userFile = "logs\test-user.json"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating Test User and Running Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ensure logs directory exists
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Step 1: Create test user
Write-Host "Step 1: Creating test user..." -ForegroundColor Yellow
Write-Host "  Email: $testEmail" -ForegroundColor Gray
Write-Host "  Name: $testName" -ForegroundColor Gray

try {
    $registerBody = @{
        email = $testEmail
        password = $testPassword
        nombre = $testName
    } | ConvertTo-Json

    $registerResponse = Invoke-RestMethod -Uri "$baseUrl/api/login/new" `
        -Method POST `
        -ContentType "application/json" `
        -Body $registerBody `
        -ErrorAction Stop

    if ($registerResponse.ok) {
        Write-Host "  ✅ User created successfully!" -ForegroundColor Green
        Write-Host "  User ID: $($registerResponse.usuario._id)" -ForegroundColor Gray
        
        # Save user info
        $registerResponse | ConvertTo-Json -Depth 10 | Out-File -FilePath $userFile -Encoding UTF8
    } else {
        Write-Host "  ❌ User creation failed: $($registerResponse.msg)" -ForegroundColor Red
        exit 1
    }
} catch {
    $errorMsg = $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        try {
            $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
            $errorMsg = $errorJson.msg
        } catch {}
    }
    Write-Host "  ❌ Failed to create user: $errorMsg" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Login to get access token
Write-Host "Step 2: Logging in to get access token..." -ForegroundColor Yellow

try {
    $loginBody = @{
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod -Uri "$baseUrl/api/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -ErrorAction Stop

    if ($loginResponse.ok -and $loginResponse.accessToken) {
        $accessToken = $loginResponse.accessToken
        $accessToken | Out-File -FilePath $tokenFile -Encoding UTF8 -NoNewline
        Write-Host "  ✅ Login successful!" -ForegroundColor Green
        Write-Host "  Token saved to: $tokenFile" -ForegroundColor Gray
        Write-Host "  User ID: $($loginResponse.usuario._id)" -ForegroundColor Gray
        Write-Host "  Email: $($loginResponse.usuario.email)" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Login failed: $($loginResponse.msg)" -ForegroundColor Red
        exit 1
    }
} catch {
    $errorMsg = $_.Exception.Message
    if ($_.ErrorDetails.Message) {
        try {
            $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
            $errorMsg = $errorJson.msg
        } catch {}
    }
    Write-Host "  ❌ Failed to login: $errorMsg" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test User Credentials" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Email: $testEmail" -ForegroundColor White
Write-Host "Password: $testPassword" -ForegroundColor White
Write-Host "Token: $accessToken" -ForegroundColor Gray
Write-Host ""

# Step 3: Test authenticated endpoints
Write-Host "Step 3: Testing authenticated endpoints..." -ForegroundColor Yellow
Write-Host ""

$headers = @{
    "Content-Type" = "application/json"
    "x-token" = $accessToken
}

$testResults = @{
    passed = 0
    failed = 0
    tests = @()
}

# Test 1: Get current user
Write-Host "Test 1: GET /api/usuarios/getUsuario (current user)" -ForegroundColor Cyan
try {
    $body = @{ uid = $loginResponse.usuario._id } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/api/usuarios/getUsuario" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Get current user"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Get current user"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Get current user"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Test 2: Update user
Write-Host "Test 2: POST /api/usuarios/updateUsuario" -ForegroundColor Cyan
try {
    $updateBody = @{
        nombre = "$testName (Updated)"
        avatar = "test-avatar.png"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/usuarios/updateUsuario" `
        -Method POST `
        -Headers $headers `
        -Body $updateBody `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Update user"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Update user"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Update user"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Test 3: Get contacts
Write-Host "Test 3: POST /api/contactos/getContactos" -ForegroundColor Cyan
try {
    $body = @{} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/api/contactos/getContactos" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Get contacts"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Get contacts"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Get contacts"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Test 4: Get groups
Write-Host "Test 4: POST /api/grupos/groupsByMember" -ForegroundColor Cyan
try {
    $body = @{} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/api/grupos/groupsByMember" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Get groups"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Get groups"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Get groups"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Test 5: Search endpoint
Write-Host "Test 5: GET /api/search?q=test" -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/search?q=test" `
        -Method GET `
        -Headers $headers `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Search"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Search"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Search"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Test 6: Get messages
Write-Host "Test 6: POST /api/mensajes" -ForegroundColor Cyan
try {
    $body = @{
        tipo = "individual"
        limit = 10
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$baseUrl/api/mensajes" `
        -Method POST `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    if ($response.ok) {
        Write-Host "  ✅ Passed" -ForegroundColor Green
        $testResults.passed++
        $testResults.tests += @{ name = "Get messages"; status = "PASS" }
    } else {
        Write-Host "  ❌ Failed: $($response.msg)" -ForegroundColor Red
        $testResults.failed++
        $testResults.tests += @{ name = "Get messages"; status = "FAIL"; error = $response.msg }
    }
} catch {
    Write-Host "  ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    $testResults.failed++
    $testResults.tests += @{ name = "Get messages"; status = "FAIL"; error = $_.Exception.Message }
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($testResults.passed + $testResults.failed)" -ForegroundColor White
Write-Host "Passed: $($testResults.passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.failed)" -ForegroundColor $(if ($testResults.failed -gt 0) { "Red" } else { "Green" })
Write-Host ""

# Save test results
$testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath "logs\test-results.json" -Encoding UTF8
Write-Host "Test results saved to: logs\test-results.json" -ForegroundColor Gray
Write-Host ""

if ($testResults.failed -eq 0) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  Some tests failed. Check logs for details." -ForegroundColor Yellow
    exit 1
}


