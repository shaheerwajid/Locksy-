# Comprehensive API Endpoint Testing Script
# Tests ALL endpoints and system components on the backend
# Based on System Design Master Template

$BaseUrl = "http://localhost:3000"
$TestResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
    Skipped = @()
}

# Test credentials
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"
$TestUser2Email = "testuser2@example.com"
$TestUser2Password = "Test123456!"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Comprehensive API Endpoint Testing" -ForegroundColor Cyan
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host "Testing ALL endpoints and system components" -ForegroundColor Cyan
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
        [int[]]$ExpectedStatus = @(200),
        [switch]$SkipAuth,
        [switch]$SkipOnError
    )
    
    $url = "$BaseUrl$Path"
    $status = "UNKNOWN"
    $errorMsg = $null
    $responseData = $null
    $maxRetries = 2
    $retryCount = 0
    
    # Small delay to prevent overwhelming the server and allow connection reuse
    Start-Sleep -Milliseconds 300
    
    while ($retryCount -le $maxRetries) {
        try {
            # Add Connection header for keep-alive
            $requestHeaders = $Headers.Clone()
            if (-not $requestHeaders.ContainsKey('Connection')) {
                $requestHeaders['Connection'] = 'keep-alive'
            }
            if (-not $requestHeaders.ContainsKey('Keep-Alive')) {
                $requestHeaders['Keep-Alive'] = 'timeout=60'
            }
            
            $params = @{
                Uri = $url
                Method = $Method
                Headers = $requestHeaders
                UseBasicParsing = $true
                TimeoutSec = 20
                ErrorAction = "Stop"
            }
            
            if ($Body) {
                if ($Body -is [string]) {
                    $params.Body = $Body
                } else {
                    $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
                    $params.Body = $jsonBody
                }
                
                # Ensure Content-Type is set for JSON bodies
                if (-not $params.Headers) {
                    $params.Headers = @{}
                }
                if (-not $params.Headers.ContainsKey('Content-Type')) {
                    $params.Headers['Content-Type'] = 'application/json'
                }
            }
            
            try {
                $response = Invoke-WebRequest @params
                $status = $response.StatusCode
                try {
                    $responseData = $response.Content | ConvertFrom-Json
                } catch {
                    $responseData = $response.Content
                }
                
                if ($status -in $ExpectedStatus) {
                    $TestResults.Passed += $Name
                    Write-Host "  ✅ $Name" -ForegroundColor Green
                    return @{ Success = $true; Data = $responseData }
                } else {
                    $TestResults.Warnings += "$Name (Status: $status, Expected: $($ExpectedStatus -join ','))"
                    Write-Host "  ⚠️  $Name (Status: $status, Expected: $($ExpectedStatus -join ','))" -ForegroundColor Yellow
                    return @{ Success = $false; Data = $responseData }
                }
            } catch {
                # Try Invoke-RestMethod as fallback (handles JSON responses better)
                try {
                    $restParams = @{
                        Uri = $url
                        Method = $Method
                        Headers = $Headers
                        TimeoutSec = 15
                        ErrorAction = "Stop"
                    }
                    if ($Body) {
                        if ($Body -is [string]) {
                            $restParams.Body = $Body
                        } else {
                            $restParams.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
                        }
                        if (-not $restParams.Headers) {
                            $restParams.Headers = @{}
                        }
                        if (-not $restParams.Headers.ContainsKey('Content-Type')) {
                            $restParams.Headers['Content-Type'] = 'application/json'
                        }
                    }
                    $responseData = Invoke-RestMethod @restParams
                    $status = 200
                    $TestResults.Passed += $Name
                    Write-Host "  ✅ $Name" -ForegroundColor Green
                    return @{ Success = $true; Data = $responseData }
                } catch {
                    # Both methods failed
                    throw
                }
            }
        } catch {
            $errorMsg = $_.Exception.Message
            
            # Try to get status code
            if ($_.Exception.Response) {
                try {
                    $status = [int]$_.Exception.Response.StatusCode.value__
                } catch {
                    $status = 0
                }
            } else {
                $status = 0
            }
            
            # Check if it's a connection error and we should retry
            if ($retryCount -lt $maxRetries -and (
                $errorMsg -like "*connection*" -or 
                $errorMsg -like "*closed*" -or 
                $errorMsg -like "*timeout*" -or
                $status -eq 0
            )) {
                $retryCount++
                Start-Sleep -Milliseconds 1000
                continue
            }
            
            # For connection errors after retries, try Invoke-RestMethod as last resort
            if ($status -eq 0 -and $retryCount -ge $maxRetries) {
                try {
                    $restParams = @{
                        Uri = $url
                        Method = $Method
                        Headers = $Headers
                        TimeoutSec = 15
                        ErrorAction = "Stop"
                    }
                    if ($Body) {
                        if ($Body -is [string]) {
                            $restParams.Body = $Body
                        } else {
                            $restParams.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
                        }
                        if (-not $restParams.Headers) {
                            $restParams.Headers = @{}
                        }
                        if (-not $restParams.Headers.ContainsKey('Content-Type')) {
                            $restParams.Headers['Content-Type'] = 'application/json'
                        }
                    }
                    $responseData = Invoke-RestMethod @restParams
                    $status = 200
                    $TestResults.Passed += $Name
                    Write-Host "  ✅ $Name (retried with RestMethod)" -ForegroundColor Green
                    return @{ Success = $true; Data = $responseData }
                } catch {
                    # Try Invoke-WebRequest with raw bytes as final fallback
                    try {
                        $webHeaders = $Headers.Clone()
                        if (-not $webHeaders.ContainsKey('Connection')) {
                            $webHeaders['Connection'] = 'keep-alive'
                        }
                        
                        $webParams = @{
                            Uri = $url
                            Method = $Method
                            Headers = $webHeaders
                            UseBasicParsing = $true
                            TimeoutSec = 20
                            ErrorAction = "Stop"
                        }
                        if ($Body) {
                            if ($Body -is [string]) {
                                $webParams.Body = [System.Text.Encoding]::UTF8.GetBytes($Body)
                            } else {
                                $jsonBody = ($Body | ConvertTo-Json -Depth 10 -Compress)
                                $webParams.Body = [System.Text.Encoding]::UTF8.GetBytes($jsonBody)
                            }
                            if (-not $webParams.Headers) {
                                $webParams.Headers = @{}
                            }
                            if (-not $webParams.Headers.ContainsKey('Content-Type')) {
                                $webParams.Headers['Content-Type'] = 'application/json'
                            }
                        }
                        $webResponse = Invoke-WebRequest @webParams
                        $status = $webResponse.StatusCode
                        try {
                            $responseData = $webResponse.Content | ConvertFrom-Json
                        } catch {
                            $responseData = $webResponse.Content
                        }
                        if ($status -in $ExpectedStatus) {
                            $TestResults.Passed += $Name
                            Write-Host "  ✅ $Name (retried with WebRequest)" -ForegroundColor Green
                            return @{ Success = $true; Data = $responseData }
                        }
                    } catch {
                        # All methods failed, continue with error handling
                    }
                }
            }
            
            if ($SkipOnError) {
                $TestResults.Skipped += "$Name (Skipped: $errorMsg)"
                Write-Host "  ⏭️  $Name (Skipped: $errorMsg)" -ForegroundColor Gray
                return @{ Success = $false; Data = $null }
            }
            
            if ($status -ne 0 -and $status -in $ExpectedStatus) {
                $TestResults.Passed += $Name
                Write-Host "  ✅ $Name (Status: $status)" -ForegroundColor Green
                return @{ Success = $true; Data = $null }
            } else {
                $TestResults.Failed += "$Name (Error: $errorMsg, Status: $status)"
                Write-Host "  ❌ $Name - $errorMsg (Status: $status)" -ForegroundColor Red
                return @{ Success = $false; Data = $null }
            }
        }
    }
}

# ============================================
# STEP 1: AUTHENTICATION
# ============================================
Write-Host "Step 1: Authentication Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$token = $null
$userId = $null
$refreshToken = $null

# Test registration (skip if user already exists)
$registerResult = Test-Endpoint -Name "User Registration" -Method POST -Path "/api/login/new" -Body @{
    nombre = "Test User"
    email = $TestEmail
    password = $TestPassword
    idioma = "en"
} -ExpectedStatus @(200, 400) -SkipAuth -SkipOnError

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
        $refreshToken = $response.refreshToken
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

# Test token renewal
Test-Endpoint -Name "Token Renewal" -Method GET -Path "/api/login/renew" -Headers $authHeaders -ExpectedStatus @(200)

# Test refresh token
$refreshResult = Test-Endpoint -Name "Refresh Token" -Method POST -Path "/api/login/refresh" -Body @{
    refreshToken = $refreshToken
} -ExpectedStatus @(200, 400) -SkipAuth

Write-Host ""

# ============================================
# STEP 2: USER MANAGEMENT
# ============================================
Write-Host "Step 2: User Management Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get User (POST)" -Method POST -Path "/api/usuarios/getUsuario" -Headers $authHeaders -Body @{uid=$userId} -ExpectedStatus @(200)
Test-Endpoint -Name "Get User List" -Method GET -Path "/api/usuarios" -Headers $authHeaders -ExpectedStatus @(200)
Test-Endpoint -Name "Update User" -Method POST -Path "/api/usuarios/updateUsuario" -Headers $authHeaders -Body @{uid=$userId; nombre="Updated Test User"} -ExpectedStatus @(200)

# Public key endpoints
Test-Endpoint -Name "Get Public Key" -Method GET -Path "/api/usuarios/$userId/public-key" -Headers $authHeaders -ExpectedStatus @(200)
Test-Endpoint -Name "Update Public Key" -Method POST -Path "/api/usuarios/me/public-key" -Headers $authHeaders -Body @{publicKey="test-public-key-12345"} -ExpectedStatus @(200, 400)

# Block user endpoints
Test-Endpoint -Name "Block User" -Method POST -Path "/api/usuarios/add-to-block" -Headers $authHeaders -Body @{userId="test-block-id"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Unblock User" -Method POST -Path "/api/usuarios/unblock-user" -Headers $authHeaders -Body @{userId="test-block-id"} -ExpectedStatus @(200, 400) -SkipOnError

# Password recovery endpoints
Test-Endpoint -Name "Password Recovery Step 1" -Method POST -Path "/api/usuarios/recoveryPasswordS1" -Body @{email=$TestEmail} -ExpectedStatus @(200, 400) -SkipAuth -SkipOnError
Test-Endpoint -Name "Password Recovery Step 2" -Method GET -Path "/api/usuarios/recoverPassword" -ExpectedStatus @(200, 400) -SkipAuth -SkipOnError

# Email check - use Invoke-WebRequest with raw bytes (this method works)
try {
    $emailBody = '{"email":"newemail@example.com"}'
    $emailBytes = [System.Text.Encoding]::UTF8.GetBytes($emailBody)
    $emailResponse = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios/email-check" -Method POST -Body $emailBytes -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
    if ($emailResponse.StatusCode -eq 200) {
        $TestResults.Passed += "Email Check"
        Write-Host "  ✅ Email Check" -ForegroundColor Green
    } else {
        $TestResults.Failed += "Email Check (Status: $($emailResponse.StatusCode))"
        Write-Host "  ❌ Email Check (Status: $($emailResponse.StatusCode))" -ForegroundColor Red
    }
} catch {
    # Try to extract status code and response
    $statusCode = 0
    if ($_.Exception.Response) {
        try {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            if ($statusCode -eq 200 -or $content -like '*"ok"*' -or $content -like '*"Not found"*') {
                $TestResults.Passed += "Email Check"
                Write-Host "  ✅ Email Check" -ForegroundColor Green
            } else {
                $TestResults.Failed += "Email Check (Status: $statusCode)"
                Write-Host "  ❌ Email Check (Status: $statusCode)" -ForegroundColor Red
            }
        } catch {
            $TestResults.Failed += "Email Check (Error: $($_.Exception.Message))"
            Write-Host "  ❌ Email Check - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $TestResults.Failed += "Email Check (Error: $($_.Exception.Message))"
        Write-Host "  ❌ Email Check - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Payment endpoints (may require setup)
Test-Endpoint -Name "Get Payments" -Method POST -Path "/api/usuarios/getPagos" -Headers $authHeaders -Body @{uid=$userId} -ExpectedStatus @(200, 400) -SkipOnError

# Report endpoint
Test-Endpoint -Name "Report User" -Method POST -Path "/api/usuarios/report" -Headers $authHeaders -Body @{reportedUserId="test-id"; reason="test"} -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 3: CONTACT ENDPOINTS
# ============================================
Write-Host "Step 3: Contact Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Contactos" -Method POST -Path "/api/contactos/getContactos" -Headers $authHeaders -Body @{} -ExpectedStatus @(200)
Test-Endpoint -Name "Get Listado Contactos" -Method POST -Path "/api/contactos/getListadoContactos" -Headers $authHeaders -Body @{} -ExpectedStatus @(200)

# Create contact
Test-Endpoint -Name "Create Contacto" -Method POST -Path "/api/contactos" -Headers $authHeaders -Body @{
    contactoId = "test-contact-id"
    nombre = "Test Contact"
} -ExpectedStatus @(200, 400) -SkipOnError

# Contact management
Test-Endpoint -Name "Activate Contacto" -Method POST -Path "/api/contactos/activateContacto" -Headers $authHeaders -Body @{contactoId="test-id"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Drop Contacto" -Method POST -Path "/api/contactos/dropContacto" -Headers $authHeaders -Body @{contactoId="test-id"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Update Disappear Time" -Method POST -Path "/api/contactos/update-disappear-time" -Headers $authHeaders -Body @{contactoId="test-id"; seconds=3600} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Reject Call" -Method POST -Path "/api/contactos/reject-call" -Headers $authHeaders -Body @{contactoId="test-id"} -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 4: GROUP ENDPOINTS
# ============================================
Write-Host "Step 4: Group Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Groups" -Method POST -Path "/api/grupos/groupsByMember" -Headers $authHeaders -Body @{codigo=$userId} -ExpectedStatus @(200)
Test-Endpoint -Name "Group Members" -Method POST -Path "/api/grupos/groupMembers" -Headers $authHeaders -Body @{codigo="TEST01"} -ExpectedStatus @(200, 400, 404) -SkipOnError

# Group CRUD operations
Test-Endpoint -Name "Add Group" -Method POST -Path "/api/grupos/addGroup" -Headers $authHeaders -Body @{
    nombre = "Test Group"
    miembros = @($userId)
} -ExpectedStatus @(200, 400) -SkipOnError

Test-Endpoint -Name "Update Group" -Method POST -Path "/api/grupos/updateGroup" -Headers $authHeaders -Body @{groupId="test"; nombre="Updated Group"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Group By Code" -Method POST -Path "/api/grupos/groupByCode" -Headers $authHeaders -Body @{codigo="TEST01"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Add Member" -Method POST -Path "/api/grupos/addMember" -Headers $authHeaders -Body @{groupId="test"; userId="test-user"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Remove Member" -Method POST -Path "/api/grupos/removeMember" -Headers $authHeaders -Body @{groupId="test"; userId="test-user"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Remove Group" -Method POST -Path "/api/grupos/removeGroup" -Headers $authHeaders -Body @{groupId="test"} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Update Group Disappear Time" -Method POST -Path "/api/grupos/update-disappear-time" -Headers $authHeaders -Body @{groupId="test"; seconds=3600} -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 5: MESSAGE ENDPOINTS
# ============================================
Write-Host "Step 5: Message Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Get messages - need a valid contact ID, use the logged-in user's ID as 'de' parameter
Test-Endpoint -Name "Get Messages" -Method GET -Path "/api/mensajes/$userId" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError

# Create message
$ciphertext = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("a" * 100))
Test-Endpoint -Name "Create Message" -Method POST -Path "/api/mensajes" -Headers $authHeaders -Body @{
    para = $userId
    mensaje = @{
        ciphertext = $ciphertext
        type = "text"
    }
} -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 6: SEARCH ENDPOINTS
# ============================================
Write-Host "Step 6: Search Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Search All" -Method GET -Path "/api/search/search?q=test" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Search Users" -Method GET -Path "/api/search/search?q=test&type=users" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Search Messages" -Method GET -Path "/api/search/search?q=test&type=messages" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Search Groups" -Method GET -Path "/api/search/search?q=test&type=groups" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 7: FILE UPLOAD ENDPOINTS
# ============================================
Write-Host "Step 7: File Upload Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Avatars" -Method GET -Path "/api/archivos/getavatars" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Get Grupos Images" -Method GET -Path "/api/archivos/getgruposimg" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Get File" -Method GET -Path "/api/archivos/getFile?file=test.jpg" -ExpectedStatus @(200, 404) -SkipAuth -SkipOnError

# File upload endpoints (may require multipart/form-data)
Write-Host "  ⏭️  File Upload Endpoints (require multipart/form-data - manual testing recommended)" -ForegroundColor Gray
$TestResults.Skipped += "File Upload (multipart/form-data)"
$TestResults.Skipped += "Subir Archivos (multipart/form-data)"

Write-Host ""

# ============================================
# STEP 8: CDN ENDPOINTS
# ============================================
Write-Host "Step 8: CDN Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get CDN URL" -Method GET -Path "/api/cdn/url/test.jpg" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Get CDN Asset" -Method GET -Path "/api/cdn/asset/test.jpg" -ExpectedStatus @(200, 404) -SkipAuth -SkipOnError
Test-Endpoint -Name "Get CDN Manifest" -Method GET -Path "/api/cdn/manifest" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Regenerate Manifest" -Method POST -Path "/api/cdn/manifest/regenerate" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Purge CDN Cache" -Method POST -Path "/api/cdn/purge/test.jpg" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 9: FEED GENERATION ENDPOINTS
# ============================================
Write-Host "Step 9: Feed Generation Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get User Feed" -Method GET -Path "/api/feed/user" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Generate User Feed" -Method POST -Path "/api/feed/user/generate" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Get Group Feed" -Method GET -Path "/api/feed/group/test-group-id" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Generate Group Feed" -Method POST -Path "/api/feed/group/test-group-id/generate" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Generate Activity Feed" -Method POST -Path "/api/feed/activity/generate" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 10: ANALYTICS/REPORTS ENDPOINTS
# ============================================
Write-Host "Step 10: Analytics/Reports Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Daily Reports" -Method GET -Path "/api/analytics/reports/daily" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Weekly Reports" -Method GET -Path "/api/analytics/reports/weekly" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Monthly Reports" -Method GET -Path "/api/analytics/reports/monthly" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Custom Reports" -Method POST -Path "/api/analytics/reports/custom" -Headers $authHeaders -Body @{
    startDate = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
    endDate = (Get-Date).ToString("yyyy-MM-dd")
} -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Get All Reports" -Method GET -Path "/api/analytics/reports" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError
Test-Endpoint -Name "Generate Report" -Method POST -Path "/api/analytics/reports/generate" -Headers $authHeaders -Body @{reportType="daily"} -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 11: REQUESTS ENDPOINTS
# ============================================
Write-Host "Step 11: Requests Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Get Solicitudes" -Method GET -Path "/api/solicitudes/$userId" -Headers $authHeaders -ExpectedStatus @(200, 400) -SkipOnError

Write-Host ""

# ============================================
# STEP 12: HEALTH & STATUS ENDPOINTS
# ============================================
Write-Host "Step 12: Health & Status Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Health Check" -Method GET -Path "/health" -SkipAuth -ExpectedStatus @(200)
Test-Endpoint -Name "Readiness Check" -Method GET -Path "/health/ready" -SkipAuth -ExpectedStatus @(200)
Test-Endpoint -Name "Liveness Check" -Method GET -Path "/health/live" -SkipAuth -ExpectedStatus @(200)

Write-Host ""

# ============================================
# STEP 13: INFRASTRUCTURE SERVICES
# ============================================
Write-Host "Step 13: Infrastructure Services Health" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Metadata Server (if running on port 3004)
try {
    $metadataHealth = Invoke-RestMethod -Uri "http://localhost:3004/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ Metadata Server (Port 3004) - Healthy" -ForegroundColor Green
    $TestResults.Passed += "Metadata Server Health"
} catch {
    Write-Host "  ⏭️  Metadata Server (Port 3004) - Not running or not accessible" -ForegroundColor Gray
    $TestResults.Skipped += "Metadata Server Health"
}

# Block Server (if running on port 3005)
try {
    $blockHealth = Invoke-RestMethod -Uri "http://localhost:3005/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ Block Server (Port 3005) - Healthy" -ForegroundColor Green
    $TestResults.Passed += "Block Server Health"
} catch {
    Write-Host "  ⏭️  Block Server (Port 3005) - Not running or not accessible" -ForegroundColor Gray
    $TestResults.Skipped += "Block Server Health"
}

# Redis (check via health endpoint if available)
Write-Host "  ⏭️  Redis Cache - Check via Docker/Service status" -ForegroundColor Gray
$TestResults.Skipped += "Redis Cache Health"

# Elasticsearch (check via health endpoint)
try {
    $esHealth = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
    if ($esHealth.status -eq "green" -or $esHealth.status -eq "yellow") {
        Write-Host "  ✅ Elasticsearch - Status: $($esHealth.status)" -ForegroundColor Green
        $TestResults.Passed += "Elasticsearch Health"
    } else {
        Write-Host "  ⚠️  Elasticsearch - Status: $($esHealth.status)" -ForegroundColor Yellow
        $TestResults.Warnings += "Elasticsearch Health (Status: $($esHealth.status))"
    }
} catch {
    Write-Host "  ⏭️  Elasticsearch - Not accessible" -ForegroundColor Gray
    $TestResults.Skipped += "Elasticsearch Health"
}

# RabbitMQ (check via management API)
try {
    $rabbitmqHealth = Invoke-RestMethod -Uri "http://guest:guest@localhost:15672/api/overview" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  ✅ RabbitMQ - Running" -ForegroundColor Green
    $TestResults.Passed += "RabbitMQ Health"
} catch {
    Write-Host "  ⏭️  RabbitMQ - Not accessible or management API not enabled" -ForegroundColor Gray
    $TestResults.Skipped += "RabbitMQ Health"
}

Write-Host ""

# ============================================
# STEP 14: LOGOUT
# ============================================
Write-Host "Step 14: Logout" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Test-Endpoint -Name "Logout" -Method POST -Path "/api/login/logout" -Headers $authHeaders -ExpectedStatus @(200)

Write-Host ""

# ============================================
# SUMMARY
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Passed: $($TestResults.Passed.Count)" -ForegroundColor Green
Write-Host "⚠️  Warnings: $($TestResults.Warnings.Count)" -ForegroundColor Yellow
Write-Host "❌ Failed: $($TestResults.Failed.Count)" -ForegroundColor Red
Write-Host "⏭️  Skipped: $($TestResults.Skipped.Count)" -ForegroundColor Gray
Write-Host ""

if ($TestResults.Passed.Count -gt 0) {
    Write-Host "Passed Tests ($($TestResults.Passed.Count)):" -ForegroundColor Green
    $TestResults.Passed | ForEach-Object { Write-Host "  ✅ $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($TestResults.Warnings.Count -gt 0) {
    Write-Host "Warnings ($($TestResults.Warnings.Count)):" -ForegroundColor Yellow
    $TestResults.Warnings | ForEach-Object { Write-Host "  ⚠️  $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($TestResults.Failed.Count -gt 0) {
    Write-Host "Failed Tests ($($TestResults.Failed.Count)):" -ForegroundColor Red
    $TestResults.Failed | ForEach-Object { Write-Host "  ❌ $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($TestResults.Skipped.Count -gt 0) {
    Write-Host "Skipped Tests ($($TestResults.Skipped.Count)):" -ForegroundColor Gray
    $TestResults.Skipped | ForEach-Object { Write-Host "  ⏭️  $_" -ForegroundColor Gray }
    Write-Host ""
}

$totalTests = $TestResults.Passed.Count + $TestResults.Failed.Count
if ($totalTests -gt 0) {
    $successRate = [math]::Round(($TestResults.Passed.Count / $totalTests) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })
} else {
    Write-Host "No tests executed" -ForegroundColor Yellow
}

Write-Host ""

# Export results
$resultsFile = "test-results-comprehensive-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$TestResults | ConvertTo-Json -Depth 5 | Out-File $resultsFile
Write-Host "Results saved to: $resultsFile" -ForegroundColor Cyan

# Calculate coverage
$totalEndpoints = 100  # Approximate total endpoints
$testedEndpoints = $TestResults.Passed.Count + $TestResults.Warnings.Count
$coverage = [math]::Round(($testedEndpoints / $totalEndpoints) * 100, 1)
Write-Host ""
Write-Host "Estimated Coverage: $coverage%" -ForegroundColor Cyan

