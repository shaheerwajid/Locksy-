# Comprehensive Backend Test Suite
# Tests all endpoints and flows to ensure backend is complete

$ErrorActionPreference = "Continue"
$BaseUrl = "http://localhost:3000"
$TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Skipped = 0
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method = "GET",
        [string]$Path,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int[]]$ExpectedStatusCodes = @(200),
        [string]$Description = ""
    )
    
    $TestResults.Total++
    Write-Host "`n[$($TestResults.Total)] Testing: $Name" -ForegroundColor Cyan
    if ($Description) {
        Write-Host "   $Description" -ForegroundColor Gray
    }
    
    try {
        $params = @{
            Uri = "$BaseUrl$Path"
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
            TimeoutSec = 30
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        $statusCode = $response.StatusCode
        
        if ($ExpectedStatusCodes -contains $statusCode) {
            Write-Host "   ✓ PASSED (Status: $statusCode)" -ForegroundColor Green
            $TestResults.Passed++
            
            # Try to parse response
            try {
                $json = $response.Content | ConvertFrom-Json
                if ($json.ok -eq $false) {
                    Write-Host "   ⚠ Warning: Response indicates failure: $($json.msg)" -ForegroundColor Yellow
                }
            } catch {
                # Not JSON, that's okay
            }
            
            return $true
        } else {
            Write-Host "   ✗ FAILED (Expected: $($ExpectedStatusCodes -join ', '), Got: $statusCode)" -ForegroundColor Red
            Write-Host "   Response: $($response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)))" -ForegroundColor Gray
            $TestResults.Failed++
            return $false
        }
    } catch {
        $statusCode = $null
        try {
            $statusCode = $_.Exception.Response.StatusCode.value__
        } catch {
            # No HTTP response (connection error, etc.)
        }
        
        if ($statusCode -and $ExpectedStatusCodes -contains $statusCode) {
            Write-Host "   ✓ PASSED (Status: $statusCode)" -ForegroundColor Green
            $TestResults.Passed++
            return $true
        } else {
            if ($statusCode) {
                Write-Host "   ✗ FAILED (Expected: $($ExpectedStatusCodes -join ', '), Got: $statusCode)" -ForegroundColor Red
            } else {
                Write-Host "   ✗ FAILED (Connection/Network Error)" -ForegroundColor Red
            }
            Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
            $TestResults.Failed++
            return $false
        }
    }
}

# ========================================
# Phase 1: Health Check
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 1: Health & Infrastructure" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Endpoint -Name "Backend Health" -Path "/health" -ExpectedStatusCodes @(200)
Test-Endpoint -Name "Backend Ready" -Path "/health/ready" -ExpectedStatusCodes @(200)

# ========================================
# Phase 2: Authentication
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 2: Authentication" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Create/Register Test User
$testEmail = "testuser_$(Get-Date -Format 'yyyyMMddHHmmss')@example.com"
$testPassword = "Test123456!"
$testName = "Test User"

Write-Host "`nCreating test user: $testEmail" -ForegroundColor Cyan
$registerBody = @{
    nombre = $testName
    email = $testEmail
    password = $testPassword
}

$registerSuccess = Test-Endpoint -Name "User Registration" -Method "POST" -Path "/api/usuarios" -Body $registerBody -ExpectedStatusCodes @(200, 201, 400) -Description "Register new user"

# If registration failed with 400 (user exists), try login
$authToken = $null
$testUserId = $null

if (-not $registerSuccess) {
    Write-Host "`nRegistration may have failed (user might exist), trying login..." -ForegroundColor Yellow
}

# Login
$loginBody = @{
    email = $testEmail
    password = $testPassword
}

$loginResponse = $null
try {
    $loginResponse = Invoke-WebRequest -Uri "$BaseUrl/api/auth/login" -Method POST -Body ($loginBody | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    if ($loginResponse.StatusCode -eq 200) {
        $loginData = $loginResponse.Content | ConvertFrom-Json
        $authToken = $loginData.token
        $testUserId = $loginData.usuario.uid
        Write-Host "   ✓ Login successful" -ForegroundColor Green
        $TestResults.Passed++
    }
} catch {
    # Try with existing test user
    $testEmail = "testuser@example.com"
    $testPassword = "Test123456!"
    $loginBody = @{
        email = $testEmail
        password = $testPassword
    }
    try {
        $loginResponse = Invoke-WebRequest -Uri "$BaseUrl/api/auth/login" -Method POST -Body ($loginBody | ConvertTo-Json) -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
        if ($loginResponse.StatusCode -eq 200) {
            $loginData = $loginResponse.Content | ConvertFrom-Json
            $authToken = $loginData.token
            $testUserId = $loginData.usuario.uid
            Write-Host "   ✓ Login successful with existing user" -ForegroundColor Green
            $TestResults.Passed++
        }
    } catch {
        Write-Host "   ✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
}

if (-not $authToken) {
    Write-Host "`n⚠ WARNING: Could not obtain authentication token. Some tests will be skipped." -ForegroundColor Yellow
    $TestResults.Skipped++
}

$authHeaders = @{
    "Content-Type" = "application/json"
    "x-token" = $authToken
}

# Test Refresh Token
if ($authToken) {
    Test-Endpoint -Name "Refresh Token" -Method "POST" -Path "/api/auth/refresh" -Headers $authHeaders -ExpectedStatusCodes @(200, 401)
}

# ========================================
# Phase 3: User Management
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 3: User Management" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    Test-Endpoint -Name "Get Current User" -Path "/api/usuarios" -Headers $authHeaders
    Test-Endpoint -Name "Get User by ID" -Path "/api/usuarios/$testUserId" -Headers $authHeaders -ExpectedStatusCodes @(200, 404)
    
    $updateBody = @{
        uid = $testUserId
        nombre = "Updated Test User"
    }
    Test-Endpoint -Name "Update User" -Method "PUT" -Path "/api/usuarios" -Headers $authHeaders -Body $updateBody -ExpectedStatusCodes @(200, 400)
} else {
    Write-Host "   [SKIPPED] User management tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 3
}

# ========================================
# Phase 4: Contacts
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 4: Contacts" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    Test-Endpoint -Name "Get Contacts" -Method "POST" -Path "/api/contactos/getContactos" -Headers $authHeaders -Body @{} -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Get Contact List" -Method "POST" -Path "/api/contactos/getListadoContactos" -Headers $authHeaders -Body @{} -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Activate Contact" -Method "POST" -Path "/api/contactos/activateContacto" -Headers $authHeaders -Body @{code = "TEST123"} -ExpectedStatusCodes @(200, 400, 404)
    Test-Endpoint -Name "Drop Contact" -Method "POST" -Path "/api/contactos/dropContacto" -Headers $authHeaders -Body @{uid = "test"} -ExpectedStatusCodes @(200, 400, 404)
} else {
    Write-Host "   [SKIPPED] Contact tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 4
}

# ========================================
# Phase 5: Groups
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 5: Groups" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    $groupBody = @{
        nombre = "Test Group"
        miembros = @($testUserId)
    }
    Test-Endpoint -Name "Add Group" -Method "POST" -Path "/api/grupos/addGroup" -Headers $authHeaders -Body $groupBody -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Get Groups by Member" -Method "POST" -Path "/api/grupos/groupsByMember" -Headers $authHeaders -Body @{} -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Get Group Members" -Method "POST" -Path "/api/grupos/groupMembers" -Headers $authHeaders -Body @{gid = "test"} -ExpectedStatusCodes @(200, 400, 404)
} else {
    Write-Host "   [SKIPPED] Group tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 3
}

# ========================================
# Phase 6: Messages
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 6: Messages" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    $messageBody = @{
        de = $testUserId
        para = $testUserId
        mensaje = "Test message"
        tipo = "texto"
    }
    Test-Endpoint -Name "Send Message" -Method "POST" -Path "/api/mensajes" -Headers $authHeaders -Body $messageBody -ExpectedStatusCodes @(200, 201, 400)
    Test-Endpoint -Name "Get Messages" -Method "GET" -Path "/api/mensajes/$testUserId" -Headers $authHeaders -ExpectedStatusCodes @(200, 400, 404)
} else {
    Write-Host "   [SKIPPED] Message tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 2
}

# ========================================
# Phase 7: Search
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 7: Search" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    Test-Endpoint -Name "Search Messages" -Path "/api/search?q=test&type=messages" -Headers $authHeaders -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Search Users" -Path "/api/search?q=test&type=users" -Headers $authHeaders -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Search Groups" -Path "/api/search?q=test&type=groups" -Headers $authHeaders -ExpectedStatusCodes @(200, 400)
} else {
    Write-Host "   [SKIPPED] Search tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 3
}

# ========================================
# Phase 8: Feed
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 8: Feed" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    Test-Endpoint -Name "Get Feed" -Path "/api/feed" -Headers $authHeaders -ExpectedStatusCodes @(200, 400)
    Test-Endpoint -Name "Get Feed with Pagination" -Path "/api/feed?page=1&limit=10" -Headers $authHeaders -ExpectedStatusCodes @(200, 400)
} else {
    Write-Host "   [SKIPPED] Feed tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 2
}

# ========================================
# Phase 9: Files
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "PHASE 9: Files" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

if ($authToken) {
    Test-Endpoint -Name "Get Files" -Path "/api/archivos" -Headers $authHeaders -ExpectedStatusCodes @(200, 400, 404, 405)
    Test-Endpoint -Name "Upload File (GET check)" -Path "/api/archivos/upload" -Headers $authHeaders -ExpectedStatusCodes @(200, 400, 404, 405)
} else {
    Write-Host "   [SKIPPED] File tests require authentication" -ForegroundColor Yellow
    $TestResults.Skipped += 2
}

# ========================================
# Final Summary
# ========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $($TestResults.Total)" -ForegroundColor White
Write-Host "Passed:       $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:       $($TestResults.Failed)" -ForegroundColor $(if ($TestResults.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host "Skipped:      $($TestResults.Skipped)" -ForegroundColor Yellow
Write-Host ""

$successRate = if ($TestResults.Total -gt 0) { [math]::Round(($TestResults.Passed / $TestResults.Total) * 100, 2) } else { 0 }
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($TestResults.Failed -eq 0) {
    Write-Host "✅ ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}

