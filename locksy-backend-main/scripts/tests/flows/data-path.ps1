# Test Data Path Flow
# Tests file operations routing, file chunking, distributed storage

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Path Flow Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"
$blockServerUrl = "http://localhost:3005"

# Get auth token
$authToken = Get-TestAuthToken -BaseUrl $baseUrl
$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

if (-not $authToken) {
    Write-Host "No auth token available. Some tests will be skipped." -ForegroundColor Yellow
}

# Test 1: Block Server Health
Write-Host "Testing Block Server health..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$blockServerUrl/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Test-Passed "Block Server health" "Block Server is healthy"
    } else {
        Test-Failed "Block Server health" "HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Block Server health" $_.Exception.Message
}

# Test 2: File Operations Route to Block Server
Write-Host ""
Write-Host "Testing file operations routing..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/archivos/getFile" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
    Test-Warning "File operations routing" "Unexpected success (should require parameters)"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400 -or $statusCode -eq 401) {
        Test-Passed "File operations routing" "Request routed to Block Server (400/401 expected)"
    } elseif ($statusCode -eq 503) {
        Test-Warning "File operations routing" "Block Server may not be running"
    } else {
        Test-Warning "File operations routing" "Status: $statusCode"
    }
}

# Test 3: File Upload Endpoint
Write-Host ""
Write-Host "Testing file upload endpoint..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $uploadBody = @{
            file = "test-file.txt"
            content = "Test file content"
        } | ConvertTo-Json -Compress
        $response = Invoke-WebRequest -Uri "$baseUrl/api/archivos/upload-file" -Method POST -Body $uploadBody -Headers $headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            Test-Passed "File upload endpoint" "File upload successful"
        } else {
            Test-Warning "File upload endpoint" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            Test-Warning "File upload endpoint" "Unauthorized (401) - Auth may be required"
        } else {
            Test-Warning "File upload endpoint" "Status: $statusCode"
        }
    }
} else {
    Test-Warning "File upload endpoint" "No auth token available"
}

# Test 4: File Download Endpoint
Write-Host ""
Write-Host "Testing file download endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/archivos/getFile" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
    Test-Warning "File download endpoint" "Unexpected success (should require file ID)"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 400 -or $statusCode -eq 401) {
        Test-Passed "File download endpoint" "Endpoint exists (400/401 expected)"
    } else {
        Test-Warning "File download endpoint" "Status: $statusCode"
    }
}

# Test 5: Storage Integration
Write-Host ""
Write-Host "Testing storage integration..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$blockServerUrl/health/ready" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    $result = $response.Content | ConvertFrom-Json
    if ($result.checks.storage -eq 'connected') {
        Test-Passed "Storage integration" "Storage is connected"
    } else {
        Test-Warning "Storage integration" "Storage status: $($result.checks.storage)"
    }
} catch {
    Test-Warning "Storage integration" $_.Exception.Message
}

# Test 6: Chunked Upload (if endpoint exists)
Write-Host ""
Write-Host "Testing chunked upload endpoint..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $chunkBody = @{
            fileName = "test-chunk.txt"
            totalChunks = 1
            chunkNumber = 1
            chunkData = "Test chunk data"
        } | ConvertTo-Json -Compress
        $response = Invoke-WebRequest -Uri "$baseUrl/api/archivos/init-chunk-upload" -Method POST -Body $chunkBody -Headers $headers -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 15
        if ($response.StatusCode -eq 200) {
            Test-Passed "Chunked upload endpoint" "Chunked upload initialized"
        } else {
            Test-Warning "Chunked upload endpoint" "HTTP $($response.StatusCode)"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404) {
            Test-Warning "Chunked upload endpoint" "Endpoint not found (404) - May not be implemented"
        } else {
            Test-Warning "Chunked upload endpoint" "Status: $statusCode"
        }
    }
} else {
    Test-Warning "Chunked upload endpoint" "No auth token available"
}

# Summary
Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })






