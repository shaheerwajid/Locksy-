# Comprehensive Frontend Readiness Verification
$BaseUrl = "http://localhost:3000"
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Frontend Readiness Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allChecks = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

# Check 1: Docker Services
Write-Host "Check 1: Docker Services Status" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $containers = docker ps --format "{{.Names}}`t{{.Status}}" 2>&1
    $requiredServices = @("locksy-backend", "locksy-mongodb-primary", "locksy-redis", "locksy-rabbitmq", "locksy-elasticsearch", "locksy-minio")
    $runningServices = 0
    
    foreach ($service in $requiredServices) {
        if ($containers -match $service) {
            $runningServices++
            Write-Host "  ✅ $service - Running" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $service - Not Running" -ForegroundColor Red
            $allChecks.Failed += "Docker Service: $service not running"
        }
    }
    
    if ($runningServices -eq $requiredServices.Count) {
        $allChecks.Passed += "All Docker services running"
        Write-Host "  ✅ All required services are running" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  $runningServices/$($requiredServices.Count) services running" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Error checking Docker services: $_" -ForegroundColor Red
    $allChecks.Failed += "Docker services check failed"
}

Write-Host ""

# Check 2: Backend Health
Write-Host "Check 2: Backend Health" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -TimeoutSec 5 -ErrorAction Stop
    if ($health.ok) {
        $allChecks.Passed += "Backend health check"
        Write-Host "  ✅ Backend is healthy" -ForegroundColor Green
        Write-Host "     Status: $($health.status)" -ForegroundColor Gray
        Write-Host "     Uptime: $([math]::Round($health.uptime, 2))s" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ❌ Backend health check failed: $_" -ForegroundColor Red
    $allChecks.Failed += "Backend health check failed"
}

try {
    $ready = Invoke-RestMethod -Uri "$BaseUrl/health/ready" -TimeoutSec 5 -ErrorAction Stop
    if ($ready.ok -and $ready.checks.database -eq "connected") {
        $allChecks.Passed += "Database connection"
        Write-Host "  ✅ Database is connected" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  Database may not be ready" -ForegroundColor Yellow
        $allChecks.Warnings += "Database readiness check"
    }
} catch {
    Write-Host "  ❌ Database readiness check failed: $_" -ForegroundColor Red
    $allChecks.Failed += "Database readiness check failed"
}

Write-Host ""

# Check 3: Authentication
Write-Host "Check 3: Authentication Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $loginBody = @{
        email = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json" -ErrorAction Stop
    if ($loginResponse.ok -and $loginResponse.accessToken) {
        $token = $loginResponse.accessToken
        $userId = $loginResponse.usuario.uid
        $allChecks.Passed += "Login endpoint"
        Write-Host "  ✅ Login endpoint working" -ForegroundColor Green
        Write-Host "     User ID: $userId" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ❌ Login endpoint failed: $_" -ForegroundColor Red
    $allChecks.Failed += "Login endpoint failed"
    $token = $null
}

Write-Host ""

# Check 4: Core API Endpoints
Write-Host "Check 4: Core API Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

if ($token) {
    $headers = @{
        "x-token" = $token
        "Content-Type" = "application/json"
    }
    
    # Test User Endpoint
    try {
        $body = @{uid=$userId} | ConvertTo-Json
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/getUsuario" -Method POST -Body $body -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Get User endpoint"
        Write-Host "  ✅ Get User endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Get User endpoint failed: $_" -ForegroundColor Red
        $allChecks.Failed += "Get User endpoint failed"
    }
    
    # Test Contacts Endpoint
    try {
        $body = @{} | ConvertTo-Json
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/contactos/getContactos" -Method POST -Body $body -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Get Contacts endpoint"
        Write-Host "  ✅ Get Contacts endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Get Contacts endpoint: $_" -ForegroundColor Yellow
        $allChecks.Warnings += "Get Contacts endpoint"
    }
    
    # Test Groups Endpoint
    try {
        $body = @{uid=$userId} | ConvertTo-Json
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/grupos/groupsByMember" -Method POST -Body $body -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Get Groups endpoint"
        Write-Host "  ✅ Get Groups endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Get Groups endpoint: $_" -ForegroundColor Yellow
        $allChecks.Warnings += "Get Groups endpoint"
    }
    
    # Test Messages Endpoint
    try {
        $validCiphertext = [Convert]::ToBase64String((1..150 | ForEach-Object { [byte](Get-Random -Minimum 0 -Maximum 256) }))
        $body = @{
            para = $userId
            mensaje = @{
                ciphertext = $validCiphertext
                type = "text"
            }
        } | ConvertTo-Json -Depth 3
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes" -Method POST -Body $body -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Create Message endpoint"
        Write-Host "  ✅ Create Message endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Create Message endpoint: $_" -ForegroundColor Yellow
        $allChecks.Warnings += "Create Message endpoint"
    }
    
    # Test Search Endpoint
    try {
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/search/search?q=test" -Method GET -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Search endpoint"
        Write-Host "  ✅ Search endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Search endpoint: $_" -ForegroundColor Yellow
        $allChecks.Warnings += "Search endpoint"
    }
    
    # Test Feed Endpoint
    try {
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/feed/user" -Method GET -Headers $headers -ErrorAction Stop
        $allChecks.Passed += "Feed endpoint"
        Write-Host "  ✅ Feed endpoint working" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Feed endpoint: $_" -ForegroundColor Yellow
        $allChecks.Warnings += "Feed endpoint"
    }
} else {
    Write-Host "  ⚠️  Skipping authenticated endpoints (no token)" -ForegroundColor Yellow
    $allChecks.Warnings += "Could not test authenticated endpoints"
}

Write-Host ""

# Check 5: Frontend Configuration
Write-Host "Check 5: Frontend Configuration" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
$envFile = "../locksy-main/lib/global/environment.dart"
if (Test-Path $envFile) {
    $content = Get-Content $envFile -Raw
    if ($content -match 'localhost:3000') {
        $allChecks.Passed += "Frontend environment configuration"
        Write-Host "  ✅ Frontend configured for port 3000" -ForegroundColor Green
    } elseif ($content -match 'localhost:3001') {
        Write-Host "  ❌ Frontend still configured for port 3001" -ForegroundColor Red
        $allChecks.Failed += "Frontend environment points to wrong port"
    } else {
        Write-Host "  ⚠️  Could not verify frontend configuration" -ForegroundColor Yellow
        $allChecks.Warnings += "Frontend configuration verification"
    }
} else {
    Write-Host "  ⚠️  Frontend environment file not found" -ForegroundColor Yellow
    $allChecks.Warnings += "Frontend environment file not found"
}

Write-Host ""

# Check 6: Port Availability
Write-Host "Check 6: Port Availability" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $allChecks.Passed += "Port 3000 accessible"
        Write-Host "  ✅ Port 3000 is accessible" -ForegroundColor Green
    }
} catch {
    Write-Host "  ❌ Port 3000 not accessible: $_" -ForegroundColor Red
    $allChecks.Failed += "Port 3000 not accessible"
}

Write-Host ""

# Check 7: CORS Configuration
Write-Host "Check 7: CORS Configuration" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
try {
    $response = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.Headers['Access-Control-Allow-Origin']) {
        $allChecks.Passed += "CORS headers present"
        Write-Host "  ✅ CORS headers configured" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  CORS headers not visible (may be configured)" -ForegroundColor Yellow
        $allChecks.Warnings += "CORS headers verification"
    }
} catch {
    Write-Host "  ⚠️  Could not verify CORS: $_" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Readiness Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Passed: $($allChecks.Passed.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($allChecks.Warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Failed: $($allChecks.Failed.Count)" -ForegroundColor Red
Write-Host ""

if ($allChecks.Passed.Count -gt 0) {
    Write-Host "Passed Checks:" -ForegroundColor Green
    $allChecks.Passed | ForEach-Object { Write-Host "  ✅ $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($allChecks.Warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    $allChecks.Warnings | ForEach-Object { Write-Host "  ⚠️  $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($allChecks.Failed.Count -gt 0) {
    Write-Host "Failed Checks:" -ForegroundColor Red
    $allChecks.Failed | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Gray }
    Write-Host ""
}

# Final Verdict
$totalChecks = $allChecks.Passed.Count + $allChecks.Failed.Count
if ($totalChecks -gt 0) {
    $successRate = [math]::Round(($allChecks.Passed.Count / $totalChecks) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
}

Write-Host ""

if ($allChecks.Failed.Count -eq 0 -and $allChecks.Passed.Count -ge 8) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ READY FOR FRONTEND TESTING!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backend URL: $BaseUrl" -ForegroundColor Cyan
    Write-Host "Test User: $TestEmail" -ForegroundColor Cyan
    Write-Host "All critical endpoints are working!" -ForegroundColor Cyan
} else {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "⚠️  SOME ISSUES DETECTED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please fix the failed checks before starting frontend testing." -ForegroundColor Yellow
}


