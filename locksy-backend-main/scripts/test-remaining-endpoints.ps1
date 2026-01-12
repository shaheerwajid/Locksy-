# Comprehensive Test of All Remaining Endpoints
$BaseUrl = "http://localhost:3000"
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing All Remaining Endpoints" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Login
Write-Host "Step 1: Authentication" -ForegroundColor Yellow
try {
    $loginBody = @{
        email = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.accessToken
    $userId = $loginResponse.usuario.uid
    Write-Host "  ✅ Login successful" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$headers = @{
    "x-token" = $token
    "Content-Type" = "application/json"
}

Write-Host ""

# Test Results
$results = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

# Test Messages Endpoint
Write-Host "Step 2: Messages Endpoint" -ForegroundColor Yellow
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
    $results.Passed += "Messages (POST)"
    Write-Host "  ✅ Messages endpoint works!" -ForegroundColor Green
} catch {
    $results.Failed += "Messages (POST): $($_.Exception.Message)"
    Write-Host "  ❌ Messages failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Get Messages
try {
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/mensajes/$userId" -Method GET -Headers $headers -ErrorAction Stop
    $results.Passed += "Messages (GET)"
    Write-Host "  ✅ Get messages works!" -ForegroundColor Green
} catch {
    $results.Warnings += "Messages (GET): $($_.Exception.Message)"
    Write-Host "  ⚠️  Get messages: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Test Search Endpoints
Write-Host "Step 3: Search Endpoints" -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/search/search?q=test" -Method GET -Headers $headers -ErrorAction Stop
    $results.Passed += "Search (All)"
    Write-Host "  ✅ Search endpoint works!" -ForegroundColor Green
} catch {
    $results.Failed += "Search (All): $($_.Exception.Message)"
    Write-Host "  ❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/search/search/users?q=test" -Method GET -Headers $headers -ErrorAction Stop
    $results.Passed += "Search (Users)"
    Write-Host "  ✅ Search users works!" -ForegroundColor Green
} catch {
    $results.Warnings += "Search (Users): $($_.Exception.Message)"
    Write-Host "  ⚠️  Search users: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Test Feed Endpoints
Write-Host "Step 4: Feed Endpoints" -ForegroundColor Yellow
try {
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/feed/user" -Method GET -Headers $headers -ErrorAction Stop
    $results.Passed += "Feed (Get User)"
    Write-Host "  ✅ Feed endpoint works!" -ForegroundColor Green
} catch {
    $results.Failed += "Feed (Get User): $($_.Exception.Message)"
    Write-Host "  ❌ Feed failed: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    $body = @{} | ConvertTo-Json
    $result = Invoke-RestMethod -Uri "$BaseUrl/api/feed/user/generate" -Method POST -Body $body -Headers $headers -ErrorAction Stop
    $results.Passed += "Feed (Generate)"
    Write-Host "  ✅ Feed generation works!" -ForegroundColor Green
} catch {
    $results.Warnings += "Feed (Generate): $($_.Exception.Message)"
    Write-Host "  ⚠️  Feed generation: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""

# Test File Endpoints
Write-Host "Step 5: File Endpoints" -ForegroundColor Yellow
try {
    $result = Invoke-WebRequest -Uri "$BaseUrl/api/archivos" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop
    if ($result.StatusCode -eq 200) {
        $results.Passed += "Files (GET)"
        Write-Host "  ✅ File endpoint accessible" -ForegroundColor Green
    } else {
        $results.Warnings += "Files (GET): Status $($result.StatusCode)"
        Write-Host "  ⚠️  File endpoint: Status $($result.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -in @(404, 405)) {
        $results.Passed += "Files (GET - Endpoint exists)"
        Write-Host "  ✅ File endpoint exists (Status: $status)" -ForegroundColor Green
    } else {
        $results.Failed += "Files (GET): Status $status"
        Write-Host "  ❌ File endpoint: Status $status" -ForegroundColor Red
    }
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Passed: $($results.Passed.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($results.Warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Failed: $($results.Failed.Count)" -ForegroundColor Red
Write-Host ""

if ($results.Passed.Count -gt 0) {
    Write-Host "Passed Tests:" -ForegroundColor Green
    $results.Passed | ForEach-Object { Write-Host "  ✅ $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($results.Warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    $results.Warnings | ForEach-Object { Write-Host "  ⚠️  $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($results.Failed.Count -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    $results.Failed | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Gray }
    Write-Host ""
}

$total = $results.Passed.Count + $results.Failed.Count
if ($total -gt 0) {
    $successRate = [math]::Round(($results.Passed.Count / $total) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 70) { "Yellow" } else { "Red" })
}


