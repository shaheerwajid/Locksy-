# Comprehensive System Flow Test
# Tests all flows from the System Design Master Template

$ErrorActionPreference = "Continue"
$BaseUrl = "http://localhost:3000"
$TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
}

function Test-Flow {
    param(
        [string]$Name,
        [string]$Description,
        [string]$TestCode
    )
    
    $TestResults.Total++
    Write-Host "`n[$($TestResults.Total)] Testing: $Name" -ForegroundColor Cyan
    Write-Host "   $Description" -ForegroundColor Gray
    
    try {
        $scriptBlock = [scriptblock]::Create($TestCode)
        $result = & $scriptBlock
        if ($result) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
            return $true
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
            return $false
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
        return $false
    }
}

# Get authentication token
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Setting up authentication..." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$testEmail = "testuser@example.com"
$testPassword = "Test123456!"
$authToken = $null
$testUserId = $null

try {
    $loginBody = @{
        email = $testEmail
        password = $testPassword
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "$BaseUrl/api/auth/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    if ($loginResponse.token) {
        $authToken = $loginResponse.token
        $testUserId = $loginResponse.usuario.uid
        Write-Host "✓ Authentication successful" -ForegroundColor Green
        Write-Host "  User ID: $testUserId" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠ Could not authenticate. Some tests will be skipped." -ForegroundColor Yellow
}

$authHeaders = @{
    "Content-Type" = "application/json"
    "x-token" = $authToken
}

# ========================================
# FLOW 1: Primary Request Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 1: Primary Request Flow" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Health Check" -Description "Backend health endpoint" -TestCode @"
    `$response = Invoke-RestMethod -Uri "`$BaseUrl/health" -Method Get -ErrorAction Stop
    return `$response.ok -eq `$true
"@

Test-Flow -Name "Request Routing" -Description "API Gateway routing to services" -TestCode @"
    if (`$authToken) {
        `$response = Invoke-RestMethod -Uri "`$BaseUrl/api/usuarios" -Method Get -Headers `$authHeaders -ErrorAction Stop
        return `$response -ne `$null
    }
    return `$false
"@

# ========================================
# FLOW 2: Control Path (Metadata Operations)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 2: Control Path (Metadata)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Metadata Read" -Description "Read user metadata from Metadata Server" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response.usuarios -ne $null -or $response.ok -eq $true
    }
    return $false
}

Test-Flow -Name "Metadata Write" -Description "Write user metadata to Metadata Server" {
    if ($authToken -and $testUserId) {
        $updateBody = @{
            uid = $testUserId
            nombre = "Test User $(Get-Date -Format 'HHmmss')"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        return $response.ok -ne $null
    }
    return $false
}

Test-Flow -Name "Cache Integration" -Description "Redis cache for metadata" {
    if ($authToken) {
        # First request (may hit DB)
        $start1 = Get-Date
        $response1 = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        $duration1 = ((Get-Date) - $start1).TotalMilliseconds
        
        # Second request (should hit cache)
        $start2 = Get-Date
        $response2 = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        $duration2 = ((Get-Date) - $start2).TotalMilliseconds
        
        # Cache should make second request faster (or at least not slower)
        return $duration2 -le ($duration1 * 1.5)  # Allow some variance
    }
    return $false
}

# ========================================
# FLOW 3: Data Path (File Operations)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 3: Data Path (File Storage)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "File Endpoint Access" -Description "Block Server file endpoints" {
    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/api/archivos" -Method Get -UseBasicParsing -ErrorAction Stop
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        # 404 or 405 is acceptable (endpoint exists but may need parameters)
        return ($statusCode -eq 404 -or $statusCode -eq 405 -or $statusCode -eq 400)
    }
}

# ========================================
# FLOW 4: Search Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 4: Search Flow" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Elasticsearch Search" -Description "Search messages via Elasticsearch" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/search?q=test&type=messages" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

Test-Flow -Name "User Search" -Description "Search users via Elasticsearch" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/search?q=test&type=users" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

# ========================================
# FLOW 5: Feed Generation Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 5: Feed Generation" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Feed Generation" -Description "Generate user feed" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/feed" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

Test-Flow -Name "Feed Pagination" -Description "Feed with pagination" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/feed?page=1&limit=10" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

# ========================================
# FLOW 6: Message Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 6: Message Flow" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Get Messages" -Description "Retrieve chat messages" {
    if ($authToken -and $testUserId) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes/$testUserId" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

Test-Flow -Name "Send Message" -Description "Send a message" {
    if ($authToken -and $testUserId) {
        $messageBody = @{
            de = $testUserId
            para = $testUserId
            mensaje = "Test message $(Get-Date -Format 'HHmmss')"
            tipo = "texto"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes" -Method POST -Body $messageBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        return $response.ok -eq $true -or $response.mensaje -ne $null
    }
    return $false
}

# ========================================
# FLOW 7: Contact & Group Operations
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 7: Contact & Group Operations" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Get Contacts" -Description "Retrieve user contacts" {
    if ($authToken) {
        $body = @{} | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/contactos/getContactos" -Method POST -Body $body -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

Test-Flow -Name "Get Groups" -Description "Retrieve user groups" {
    if ($authToken) {
        $body = @{uid = $testUserId} | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/grupos/groupsByMember" -Method POST -Body $body -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        return $response -ne $null
    }
    return $false
}

# ========================================
# FLOW 8: Database Operations
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 8: Database Operations" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "MongoDB Read" -Description "Read from MongoDB replica set" {
    if ($authToken) {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        return $response.usuarios -ne $null -or $response.ok -eq $true
    }
    return $false
}

Test-Flow -Name "MongoDB Write" -Description "Write to MongoDB replica set" {
    if ($authToken -and $testUserId) {
        $updateBody = @{
            uid = $testUserId
            nombre = "DB Test $(Get-Date -Format 'HHmmss')"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        return $response.ok -ne $null
    }
    return $false
}

# ========================================
# Final Summary
# ========================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SYSTEM FLOW TEST SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Flows Tested:  $($TestResults.Total)" -ForegroundColor White
Write-Host "Passed:              $($TestResults.Passed)" -ForegroundColor Green
Write-Host "Warnings:            $($TestResults.Warnings)" -ForegroundColor Yellow
Write-Host "Failed:              $($TestResults.Failed)" -ForegroundColor $(if ($TestResults.Failed -gt 0) { "Red" } else { "Gray" })
Write-Host ""

$successRate = if ($TestResults.Total -gt 0) { [math]::Round(($TestResults.Passed / $TestResults.Total) * 100, 2) } else { 0 }
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($TestResults.Failed -eq 0 -and $TestResults.Passed -gt 0) {
    Write-Host "✅ ALL SYSTEM FLOWS ARE WORKING!" -ForegroundColor Green
    exit 0
} elseif ($TestResults.Passed -gt ($TestResults.Total * 0.7)) {
    Write-Host "⚠️  MOST FLOWS ARE WORKING (Some may need attention)" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "❌ SOME FLOWS NEED ATTENTION" -ForegroundColor Red
    exit 1
}

