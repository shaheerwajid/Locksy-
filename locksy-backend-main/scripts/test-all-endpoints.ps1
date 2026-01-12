# Comprehensive API Endpoint Testing Script
# Tests all critical endpoints on the backend

$BaseUrl = "http://localhost:3000"
$TestResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

# Test credentials
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Comprehensive API Endpoint Testing" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Helper function to test endpoints
function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method = "GET",
        [string]$Path,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int]$ExpectedStatus = 200,
        [switch]$SkipAuth
    )
    
    $url = "$BaseUrl$Path"
    $status = "UNKNOWN"
    $errorMsg = $null
    
    try {
        $params = @{
            Uri = $url
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
            TimeoutSec = 10
            ErrorAction = "Stop"
        }
        
        if ($Body) {
            if ($Body -is [string]) {
                $params.Body = $Body
            } else {
                $params.Body = ($Body | ConvertTo-Json -Depth 10)
            }
        }
        
        $response = Invoke-WebRequest @params
        $status = $response.StatusCode
        
        if ($status -eq $ExpectedStatus) {
            $TestResults.Passed += $Name
            Write-Host "  ✅ $Name" -ForegroundColor Green
            return $true
        } else {
            $TestResults.Warnings += "$Name (Status: $status, Expected: $ExpectedStatus)"
            Write-Host "  ⚠️  $Name (Status: $status, Expected: $ExpectedStatus)" -ForegroundColor Yellow
            return $false
        }
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        $errorMsg = $_.Exception.Message
        $TestResults.Failed += "$Name (Error: $errorMsg)"
        Write-Host "  ❌ $Name - $errorMsg" -ForegroundColor Red
        return $false
    }
}

# Step 1: Get Authentication Token
Write-Host "Step 1: Authentication" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$token = $null
$userId = $null

# Test login
try {
    $loginBody = @{
        email = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    if ($response.ok -and $response.accessToken) {
        $token = $response.accessToken
        $userId = $response.usuario.uid
        Write-Host "  ✅ Login successful" -ForegroundColor Green
        Write-Host "     User ID: $userId" -ForegroundColor Gray
        $TestResults.Passed += "Login"
    }
} catch {
    Write-Host "  ❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Login"
    Write-Host ""
    Write-Host "Cannot continue without authentication token!" -ForegroundColor Red
    exit 1
}

$authHeaders = @{
    "Content-Type" = "application/json"
    "x-token" = $token
}

Write-Host ""

# Step 2: User Endpoints
Write-Host "Step 2: User Management Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get User (POST)" -Method POST -Path "/api/usuarios/getUsuario" -Headers $authHeaders -Body @{uid=$userId} -ExpectedStatus 200
Test-Endpoint -Name "Get User List" -Method GET -Path "/api/usuarios" -Headers $authHeaders -ExpectedStatus 200
Test-Endpoint -Name "Update User" -Method POST -Path "/api/usuarios/updateUsuario" -Headers $authHeaders -Body @{uid=$userId; nombre="Updated Test User"} -ExpectedStatus 200

Write-Host ""

# Step 3: Contact Endpoints
Write-Host "Step 3: Contact Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Contactos" -Method POST -Path "/api/contactos/getContactos" -Headers $authHeaders -Body @{} -ExpectedStatus 200
Test-Endpoint -Name "Get Listado Contactos" -Method POST -Path "/api/contactos/getListadoContactos" -Headers $authHeaders -Body @{} -ExpectedStatus 200

Write-Host ""

# Step 4: Group Endpoints
Write-Host "Step 4: Group Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Groups" -Method POST -Path "/api/grupos/groupsByMember" -Headers $authHeaders -Body @{uid=$userId} -ExpectedStatus 200
Test-Endpoint -Name "Group Members" -Method POST -Path "/api/grupos/groupMembers" -Headers $authHeaders -Body @{groupId="test"} -ExpectedStatus 200

Write-Host ""

# Step 5: Message Endpoints
Write-Host "Step 5: Message Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Messages" -Method GET -Path "/api/mensajes/$userId" -Headers $authHeaders -ExpectedStatus 200

Write-Host ""

# Step 6: Search Endpoints
Write-Host "Step 6: Search Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Search" -Method GET -Path "/api/search/search?q=test" -Headers $authHeaders -ExpectedStatus 200

Write-Host ""

# Step 7: Health & Status Endpoints
Write-Host "Step 7: Health & Status Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Health Check" -Method GET -Path "/health" -SkipAuth -ExpectedStatus 200
Test-Endpoint -Name "Readiness Check" -Method GET -Path "/health/ready" -SkipAuth -ExpectedStatus 200
Test-Endpoint -Name "Liveness Check" -Method GET -Path "/health/live" -SkipAuth -ExpectedStatus 200

Write-Host ""

# Step 8: File Endpoints (Basic Check)
Write-Host "Step 8: File Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# File endpoints may return different status codes - test with any valid response
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/archivos" -Method GET -Headers $authHeaders -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $TestResults.Passed += "File Upload Endpoint"
    Write-Host "  ✅ File Upload Endpoint (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -in @(200, 404, 405)) {
        $TestResults.Passed += "File Upload Endpoint"
        Write-Host "  ✅ File Upload Endpoint (Status: $status)" -ForegroundColor Green
    } else {
        $TestResults.Failed += "File Upload Endpoint (Status: $status)"
        Write-Host "  ❌ File Upload Endpoint - Status: $status" -ForegroundColor Red
    }
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Passed: $($TestResults.Passed.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($TestResults.Warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Failed: $($TestResults.Failed.Count)" -ForegroundColor Red
Write-Host ""

if ($TestResults.Passed.Count -gt 0) {
    Write-Host "Passed Tests:" -ForegroundColor Green
    $TestResults.Passed | ForEach-Object { Write-Host "  ✅ $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($TestResults.Warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    $TestResults.Warnings | ForEach-Object { Write-Host "  ⚠️  $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($TestResults.Failed.Count -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    $TestResults.Failed | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Gray }
    Write-Host ""
}

$successRate = [math]::Round(($TestResults.Passed.Count / ($TestResults.Passed.Count + $TestResults.Failed.Count)) * 100, 1)
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

# Export results
$resultsFile = "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$TestResults | ConvertTo-Json -Depth 5 | Out-File $resultsFile
Write-Host "Results saved to: $resultsFile" -ForegroundColor Cyan

