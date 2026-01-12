# File Upload Endpoint Test
# Tests file upload endpoints and routing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "File Upload Endpoint Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0
$warnings = 0

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [int]$ExpectedStatus = 200
    )
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = $Body
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        $statusCode = $response.StatusCode
        
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "  [PASS] $Name" -ForegroundColor Green
            Write-Host "        $Url - Status: $statusCode" -ForegroundColor Gray
            $script:passed++
            return $true
        } else {
            Write-Host "  [WARN] $Name" -ForegroundColor Yellow
            Write-Host "        Expected $ExpectedStatus, got $statusCode" -ForegroundColor Gray
            $script:warnings++
            return $false
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "  [PASS] $Name" -ForegroundColor Green
            Write-Host "        $Url - Status: $statusCode (expected)" -ForegroundColor Gray
            $script:passed++
            return $true
        } else {
            Write-Host "  [FAIL] $Name" -ForegroundColor Red
            Write-Host "        $Url - Error: $($_.Exception.Message)" -ForegroundColor Gray
            $script:failed++
            return $false
        }
    }
}

# Test file upload endpoints (without authentication - should return 401)
Write-Host "Testing File Upload Endpoints..." -ForegroundColor Yellow

# Test upload-file endpoint (JSON-based, used by chat_service.dart)
Test-Endpoint "Upload File Endpoint (JSON)" "http://localhost:3001/api/archivos/upload-file" -Method POST -ExpectedStatus 401

# Test subirArchivos endpoint (multipart, used by auth_service.dart)
Test-Endpoint "Subir Archivos Endpoint (Multipart)" "http://localhost:3001/api/archivos/subirArchivos" -Method POST -ExpectedStatus 401

# Test Block Server direct endpoint
Test-Endpoint "Block Server Upload Endpoint" "http://localhost:3005/api/archivos/upload" -Method POST -ExpectedStatus 401

# Test file download endpoints
Write-Host ""
Write-Host "Testing File Download Endpoints..." -ForegroundColor Yellow

# Test getFile endpoint
Test-Endpoint "Get File Endpoint" "http://localhost:3001/api/archivos/getFile" -Method GET -ExpectedStatus 400

# Test getavatars endpoint (requires authentication)
Test-Endpoint "Get Avatars Endpoint" "http://localhost:3001/api/archivos/getavatars" -Method GET -ExpectedStatus 401

# Test getgruposimg endpoint (requires authentication)
Test-Endpoint "Get Grupos Images Endpoint" "http://localhost:3001/api/archivos/getgruposimg" -Method GET -ExpectedStatus 401

# Test API Gateway routing to Block Server
Write-Host ""
Write-Host "Testing API Gateway Routing..." -ForegroundColor Yellow

# Verify that /api/archivos routes through API Gateway to Block Server
# (Should return 401 without auth, confirming routing works)
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/archivos/getavatars" -UseBasicParsing -ErrorAction Stop
    Write-Host "  [WARN] API Gateway routing test" -ForegroundColor Yellow
    Write-Host "        Unexpected 200 response (should require auth)" -ForegroundColor Gray
    $warnings++
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Write-Host "  [PASS] API Gateway routes /api/archivos to Block Server (401 as expected)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  [FAIL] API Gateway routing test" -ForegroundColor Red
        Write-Host "        Error: $($_.Exception.Message)" -ForegroundColor Gray
        $failed++
    }
}

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Passed:  $passed" -ForegroundColor Green
Write-Host "  Failed:  $failed" -ForegroundColor Red
Write-Host "  Warnings: $warnings" -ForegroundColor Yellow
Write-Host "  Total:   $($passed + $failed + $warnings)" -ForegroundColor Cyan
Write-Host ""

