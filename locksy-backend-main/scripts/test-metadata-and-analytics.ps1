# Test Metadata and Analytics Endpoints
# Tests metadata endpoints through main server and investigates analytics endpoints

$BaseUrl = "http://localhost:3000"
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"

# Test Results
$TestResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
    Skipped = @()
}

Write-Host "=== METADATA & ANALYTICS ENDPOINTS TEST ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login
Write-Host "Step 1: Authentication" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $loginBody = @{email=$TestEmail; password=$TestPassword} | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json" -TimeoutSec 10
    if ($response.ok -and $response.accessToken) {
        $token = $response.accessToken
        $userId = $response.usuario.uid
        $headers = @{"x-token"=$token; "Content-Type"="application/json"}
        Write-Host "  ✅ Login successful - User ID: $userId" -ForegroundColor Green
        $TestResults.Passed += "Login"
    } else {
        Write-Host "  ❌ Login failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Start-Sleep -Seconds 1

# Step 2: Test Metadata Endpoints (through main server)
Write-Host "`nStep 2: Metadata Endpoints (Main Server)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Get User
try {
    $getUserBody = @{uid=$userId} | ConvertTo-Json
    $user = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios/getUsuario" -Method POST -Headers $headers -Body $getUserBody -TimeoutSec 10
    if ($user.ok -or $user.usuario) {
        Write-Host "  ✅ Get User (Metadata)" -ForegroundColor Green
        $TestResults.Passed += "Get User (Metadata)"
    } else {
        Write-Host "  ❌ Get User (Metadata): Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Get User (Metadata)"
    }
} catch {
    Write-Host "  ❌ Get User (Metadata): $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get User (Metadata)"
}
Start-Sleep -Milliseconds 500

# Get User List
try {
    $users = Invoke-RestMethod -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -TimeoutSec 10
    if ($users.ok -or $users.usuarios) {
        Write-Host "  ✅ Get User List (Metadata)" -ForegroundColor Green
        $TestResults.Passed += "Get User List (Metadata)"
    } else {
        Write-Host "  ❌ Get User List (Metadata): Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Get User List (Metadata)"
    }
} catch {
    Write-Host "  ❌ Get User List (Metadata): $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get User List (Metadata)"
}
Start-Sleep -Milliseconds 500

# Get Contactos
try {
    $contactBody = @{} | ConvertTo-Json
    $contactos = Invoke-RestMethod -Uri "$BaseUrl/api/contactos/getContactos" -Method POST -Headers $headers -Body $contactBody -TimeoutSec 10
    if ($contactos.ok -or $contactos.contactos) {
        Write-Host "  ✅ Get Contactos (Metadata)" -ForegroundColor Green
        $TestResults.Passed += "Get Contactos (Metadata)"
    } else {
        Write-Host "  ❌ Get Contactos (Metadata): Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Get Contactos (Metadata)"
    }
} catch {
    Write-Host "  ❌ Get Contactos (Metadata): $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get Contactos (Metadata)"
}
Start-Sleep -Milliseconds 500

# Get Groups
try {
    $groupsBody = @{codigo=$userId} | ConvertTo-Json
    $groups = Invoke-RestMethod -Uri "$BaseUrl/api/grupos/groupsByMember" -Method POST -Headers $headers -Body $groupsBody -TimeoutSec 10
    if ($groups.ok -or $groups.grupos) {
        Write-Host "  ✅ Get Groups (Metadata)" -ForegroundColor Green
        $TestResults.Passed += "Get Groups (Metadata)"
    } else {
        Write-Host "  ❌ Get Groups (Metadata): Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Get Groups (Metadata)"
    }
} catch {
    Write-Host "  ❌ Get Groups (Metadata): $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get Groups (Metadata)"
}
Start-Sleep -Milliseconds 500

# Get Messages
try {
    $messages = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes/$userId" -Method GET -Headers $headers -TimeoutSec 10
    if ($messages.ok -or $messages.mensajes) {
        Write-Host "  ✅ Get Messages (Metadata)" -ForegroundColor Green
        $TestResults.Passed += "Get Messages (Metadata)"
    } else {
        Write-Host "  ❌ Get Messages (Metadata): Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Get Messages (Metadata)"
    }
} catch {
    Write-Host "  ❌ Get Messages (Metadata): $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get Messages (Metadata)"
}
Start-Sleep -Seconds 1

# Step 3: Test Analytics Endpoints
Write-Host "`nStep 3: Analytics Endpoints Investigation" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Check if analytics route exists
Write-Host "  Checking if /api/analytics route is registered..." -ForegroundColor Gray

# Try Daily Reports
try {
    $dailyReport = Invoke-RestMethod -Uri "$BaseUrl/api/analytics/reports/daily" -Method GET -Headers $headers -TimeoutSec 10
    if ($dailyReport.ok) {
        Write-Host "  ✅ Daily Reports" -ForegroundColor Green
        $TestResults.Passed += "Daily Reports"
    } else {
        Write-Host "  ⚠️  Daily Reports: $($dailyReport.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Daily Reports"
    }
} catch {
    $statusCode = 0
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        } catch {}
    }
    
    if ($statusCode -eq 404) {
        Write-Host "  ❌ Daily Reports: Route not found (404) - Analytics routes not registered" -ForegroundColor Red
        $TestResults.Failed += "Daily Reports (Route Not Found)"
    } else {
        Write-Host "  ❌ Daily Reports: $($_.Exception.Message) (Status: $statusCode)" -ForegroundColor Red
        $TestResults.Failed += "Daily Reports"
    }
}
Start-Sleep -Milliseconds 500

# Try Weekly Reports
try {
    $weeklyReport = Invoke-RestMethod -Uri "$BaseUrl/api/analytics/reports/weekly" -Method GET -Headers $headers -TimeoutSec 10
    if ($weeklyReport.ok) {
        Write-Host "  ✅ Weekly Reports" -ForegroundColor Green
        $TestResults.Passed += "Weekly Reports"
    } else {
        Write-Host "  ⚠️  Weekly Reports: $($weeklyReport.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Weekly Reports"
    }
} catch {
    $statusCode = 0
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        } catch {}
    }
    
    if ($statusCode -eq 404) {
        Write-Host "  ❌ Weekly Reports: Route not found (404)" -ForegroundColor Red
        $TestResults.Failed += "Weekly Reports (Route Not Found)"
    } else {
        Write-Host "  ❌ Weekly Reports: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "Weekly Reports"
    }
}
Start-Sleep -Milliseconds 500

# Try Monthly Reports
try {
    $monthlyReport = Invoke-RestMethod -Uri "$BaseUrl/api/analytics/reports/monthly" -Method GET -Headers $headers -TimeoutSec 10
    if ($monthlyReport.ok) {
        Write-Host "  ✅ Monthly Reports" -ForegroundColor Green
        $TestResults.Passed += "Monthly Reports"
    } else {
        Write-Host "  ⚠️  Monthly Reports: $($monthlyReport.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Monthly Reports"
    }
} catch {
    $statusCode = 0
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        } catch {}
    }
    
    if ($statusCode -eq 404) {
        Write-Host "  ❌ Monthly Reports: Route not found (404)" -ForegroundColor Red
        $TestResults.Failed += "Monthly Reports (Route Not Found)"
    } else {
        Write-Host "  ❌ Monthly Reports: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "Monthly Reports"
    }
}
Start-Sleep -Milliseconds 500

# Try List Reports
try {
    $listReports = Invoke-RestMethod -Uri "$BaseUrl/api/analytics/reports" -Method GET -Headers $headers -TimeoutSec 10
    if ($listReports.ok) {
        Write-Host "  ✅ List Reports" -ForegroundColor Green
        $TestResults.Passed += "List Reports"
    } else {
        Write-Host "  ⚠️  List Reports: $($listReports.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "List Reports"
    }
} catch {
    $statusCode = 0
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
        } catch {}
    }
    
    if ($statusCode -eq 404) {
        Write-Host "  ❌ List Reports: Route not found (404)" -ForegroundColor Red
        $TestResults.Failed += "List Reports (Route Not Found)"
    } else {
        Write-Host "  ❌ List Reports: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "List Reports"
    }
}
Start-Sleep -Seconds 1

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Passed: $($TestResults.Passed.Count)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.Failed.Count)" -ForegroundColor Red
Write-Host "Warnings: $($TestResults.Warnings.Count)" -ForegroundColor Yellow
Write-Host ""

if ($TestResults.Failed.Count -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    $TestResults.Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
}

if ($TestResults.Warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    $TestResults.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host ""
}

$totalTests = $TestResults.Passed.Count + $TestResults.Failed.Count
$successRate = if ($totalTests -gt 0) { [math]::Round(($TestResults.Passed.Count / $totalTests) * 100, 2) } else { 0 }
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })


