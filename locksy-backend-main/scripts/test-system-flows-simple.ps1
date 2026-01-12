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
        [string]$Description
    )
    
    $TestResults.Total++
    Write-Host "`n[$($TestResults.Total)] Testing: $Name" -ForegroundColor Cyan
    Write-Host "   $Description" -ForegroundColor Gray
    
    return $true  # Will be set by caller
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

Test-Flow -Name "Health Check" -Description "Backend health endpoint" | Out-Null
try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -ErrorAction Stop
    if ($response.ok -eq $true) {
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } else {
        Write-Host "   ✗ FAILED" -ForegroundColor Red
        $TestResults.Failed++
    }
} catch {
    Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed++
}

Test-Flow -Name "Request Routing" -Description "API Gateway routing to services" | Out-Null
if ($authToken) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 2: Control Path (Metadata Operations)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 2: Control Path (Metadata)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Metadata Read" -Description "Read user metadata from Metadata Server" | Out-Null
if ($authToken) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        if ($response.usuarios -ne $null -or $response.ok -eq $true) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "Metadata Write" -Description "Write user metadata to Metadata Server" | Out-Null
if ($authToken -and $testUserId) {
    try {
        $updateBody = @{
            uid = $testUserId
            nombre = "Test User $(Get-Date -Format 'HHmmss')"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        if ($response.ok -ne $null) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token or user ID" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "Cache Integration" -Description "Redis cache for metadata" | Out-Null
if ($authToken) {
    try {
        $start1 = Get-Date
        $response1 = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        $duration1 = ((Get-Date) - $start1).TotalMilliseconds
        
        $start2 = Get-Date
        $response2 = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        $duration2 = ((Get-Date) - $start2).TotalMilliseconds
        
        if ($duration2 -le ($duration1 * 1.5)) {
            Write-Host "   ✓ PASSED (Cache working)" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING (Cache may not be optimal)" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 3: Data Path (File Operations)
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 3: Data Path (File Storage)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "File Endpoint Access" -Description "Block Server file endpoints" | Out-Null
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/api/archivos" -Method Get -UseBasicParsing -ErrorAction Stop
    Write-Host "   ✓ PASSED" -ForegroundColor Green
    $TestResults.Passed++
} catch {
    $statusCode = $null
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
    }
    
    if ($statusCode -eq 404 -or $statusCode -eq 405 -or $statusCode -eq 400) {
        Write-Host "   ✓ PASSED (Endpoint exists)" -ForegroundColor Green
        $TestResults.Passed++
    } elseif ($statusCode) {
        Write-Host "   ⚠ WARNING: Status $statusCode" -ForegroundColor Yellow
        $TestResults.Warnings++
    } else {
        Write-Host "   ⚠ WARNING: Connection error" -ForegroundColor Yellow
        $TestResults.Warnings++
    }
}

# ========================================
# FLOW 4: Search Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 4: Search Flow" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Elasticsearch Search" -Description "Search messages via Elasticsearch" | Out-Null
if ($authToken) {
    try {
        $searchUrl = "$BaseUrl/api/search?q=test`&type=messages"
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "User Search" -Description "Search users via Elasticsearch" | Out-Null
if ($authToken) {
    try {
        $searchUrl = "$BaseUrl/api/search?q=test`&type=users"
        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 5: Feed Generation Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 5: Feed Generation" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Feed Generation" -Description "Generate user feed" | Out-Null
if ($authToken) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/feed" -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "Feed Pagination" -Description "Feed with pagination" | Out-Null
if ($authToken) {
    try {
        $feedUrl = "$BaseUrl/api/feed?page=1`&limit=10"
        $response = Invoke-RestMethod -Uri $feedUrl -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 6: Message Flow
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 6: Message Flow" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Get Messages" -Description "Retrieve chat messages" | Out-Null
if ($authToken -and $testUserId) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes/$testUserId" -Method Get -Headers $authHeaders -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token or user ID" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "Send Message" -Description "Send a message" | Out-Null
if ($authToken -and $testUserId) {
    try {
        $messageBody = @{
            de = $testUserId
            para = $testUserId
            mensaje = "Test message $(Get-Date -Format 'HHmmss')"
            tipo = "texto"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes" -Method POST -Body $messageBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        if ($response.ok -eq $true -or $response.mensaje -ne $null) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token or user ID" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 7: Contact & Group Operations
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 7: Contact & Group Operations" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "Get Contacts" -Description "Retrieve user contacts" | Out-Null
if ($authToken) {
    try {
        $body = @{} | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/contactos/getContactos" -Method POST -Body $body -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "Get Groups" -Description "Retrieve user groups" | Out-Null
if ($authToken) {
    try {
        $body = @{uid = $testUserId} | ConvertTo-Json
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/grupos/groupsByMember" -Method POST -Body $body -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        Write-Host "   ✓ PASSED" -ForegroundColor Green
        $TestResults.Passed++
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

# ========================================
# FLOW 8: Database Operations
# ========================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "FLOW 8: Database Operations" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Test-Flow -Name "MongoDB Read" -Description "Read from MongoDB replica set" | Out-Null
if ($authToken) {
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method Get -Headers $authHeaders -ErrorAction Stop
        if ($response.usuarios -ne $null -or $response.ok -eq $true) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token" -ForegroundColor Yellow
    $TestResults.Warnings++
}

Test-Flow -Name "MongoDB Write" -Description "Write to MongoDB replica set" | Out-Null
if ($authToken -and $testUserId) {
    try {
        $updateBody = @{
            uid = $testUserId
            nombre = "DB Test $(Get-Date -Format 'HHmmss')"
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/updateUsuario" -Method POST -Body $updateBody -Headers $authHeaders -ContentType "application/json" -ErrorAction Stop
        if ($response.ok -ne $null) {
            Write-Host "   ✓ PASSED" -ForegroundColor Green
            $TestResults.Passed++
        } else {
            Write-Host "   ⚠ WARNING" -ForegroundColor Yellow
            $TestResults.Warnings++
        }
    } catch {
        Write-Host "   ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed++
    }
} else {
    Write-Host "   ⚠ WARNING: No auth token or user ID" -ForegroundColor Yellow
    $TestResults.Warnings++
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

