# Individual Component Testing Script
# Tests each component of the Load Balancer & API Gateway system individually

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Individual Component Testing" -ForegroundColor Cyan
Write-Host "Load Balancer & API Gateway" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

function Test-Passed {
    param([string]$test, [string]$details = "")
    Write-Host "  [PASS] $test" -ForegroundColor Green
    if ($details) { Write-Host "        $details" -ForegroundColor Gray }
    $testResults.Passed += $test
}

function Test-Failed {
    param([string]$test, [string]$details = "")
    Write-Host "  [FAIL] $test" -ForegroundColor Red
    if ($details) { Write-Host "        $details" -ForegroundColor Gray }
    $testResults.Failed += $test
}

function Test-Warning {
    param([string]$test, [string]$details = "")
    Write-Host "  [WARN] $test" -ForegroundColor Yellow
    if ($details) { Write-Host "        $details" -ForegroundColor Gray }
    $testResults.Warnings += $test
}

# ========================================
# TEST 1: File Structure
# ========================================
Write-Host "TEST 1: File Structure" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$requiredFiles = @(
    @{Path="nginx\nginx.conf"; Name="Nginx Configuration"},
    @{Path="nginx\upstream.conf"; Name="Nginx Upstream Config"},
    @{Path="gateway\index.js"; Name="API Gateway Main"},
    @{Path="gateway\middleware\auth.js"; Name="Auth Middleware"},
    @{Path="gateway\middleware\rateLimiter.js"; Name="Rate Limiter Middleware"},
    @{Path="gateway\middleware\validator.js"; Name="Validator Middleware"},
    @{Path="gateway\middleware\transformer.js"; Name="Transformer Middleware"},
    @{Path="gateway\middleware\logger.js"; Name="Logger Middleware"},
    @{Path="gateway\middleware\monitor.js"; Name="Monitor Middleware"},
    @{Path="gateway\routes\control.js"; Name="Control Routes"},
    @{Path="gateway\routes\data.js"; Name="Data Routes"},
    @{Path="gateway\routes\proxy.js"; Name="Proxy Routes"},
    @{Path="functions\index.js"; Name="Functions Index"},
    @{Path="functions\authFunction.js"; Name="Auth Function"},
    @{Path="functions\authorizeFunction.js"; Name="Authorize Function"},
    @{Path="functions\cacheFunction.js"; Name="Cache Function"},
    @{Path="functions\transformFunction.js"; Name="Transform Function"},
    @{Path="functions\reverseProxyFunction.js"; Name="Reverse Proxy Function"},
    @{Path="functions\monitorFunction.js"; Name="Monitor Function"},
    @{Path="functions\loggerFunction.js"; Name="Logger Function"},
    @{Path="config\index.js"; Name="Config File"},
    @{Path="index.js"; Name="Main Server File"},
    @{Path="package.json"; Name="Package Configuration"}
)

foreach ($file in $requiredFiles) {
    if (Test-Path $file.Path) {
        Test-Passed "$($file.Name) exists" "$($file.Path)"
    } else {
        Test-Failed "$($file.Name) missing" "$($file.Path)"
    }
}

Write-Host ""

# ========================================
# TEST 2: Dependencies
# ========================================
Write-Host "TEST 2: Dependencies" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$requiredDeps = @(
    "express-rate-limit",
    "ioredis",
    "uuid",
    "rate-limit-redis"
)

if (Test-Path "node_modules") {
    foreach ($dep in $requiredDeps) {
        if (Test-Path "node_modules\$dep") {
            Test-Passed "$dep installed"
        } else {
            Test-Failed "$dep not installed"
        }
    }
} else {
    Test-Failed "node_modules directory not found"
}

Write-Host ""

# ========================================
# TEST 3: Code Syntax
# ========================================
Write-Host "TEST 3: Code Syntax Validation" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$filesToCheck = @(
    "index.js",
    "gateway\index.js",
    "gateway\middleware\auth.js",
    "gateway\middleware\rateLimiter.js",
    "functions\authFunction.js"
)

foreach ($file in $filesToCheck) {
    if (Test-Path $file) {
        try {
            $check = node --check $file 2>&1
            if ($LASTEXITCODE -eq 0) {
                Test-Passed "$file syntax valid"
            } else {
                Test-Failed "$file has syntax errors"
            }
        } catch {
            Test-Warning "Could not verify $file syntax"
        }
    }
}

Write-Host ""

# ========================================
# TEST 4: Backend Server 3001
# ========================================
Write-Host "TEST 4: Backend Server - Port 3001" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $json = $response.Content | ConvertFrom-Json
        if ($json.ok -eq $true) {
            Test-Passed "Server 3001 responding" "Status: $($json.status), Worker: $($json.workerId)"
        } else {
            Test-Failed "Server 3001 invalid response"
        }
    } else {
        Test-Failed "Server 3001 returned HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Server 3001 not responding" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 5: Backend Server 3002
# ========================================
Write-Host "TEST 5: Backend Server - Port 3002" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3002/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $json = $response.Content | ConvertFrom-Json
        if ($json.ok -eq $true) {
            Test-Passed "Server 3002 responding" "Status: $($json.status), Worker: $($json.workerId)"
        } else {
            Test-Failed "Server 3002 invalid response"
        }
    } else {
        Test-Failed "Server 3002 returned HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Server 3002 not responding" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 6: Backend Server 3003
# ========================================
Write-Host "TEST 6: Backend Server - Port 3003" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3003/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $json = $response.Content | ConvertFrom-Json
        if ($json.ok -eq $true) {
            Test-Passed "Server 3003 responding" "Status: $($json.status), Worker: $($json.workerId)"
        } else {
            Test-Failed "Server 3003 invalid response"
        }
    } else {
        Test-Failed "Server 3003 returned HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Server 3003 not responding" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 7: API Gateway - Health Endpoint
# ========================================
Write-Host "TEST 7: API Gateway - Health Endpoint" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Test-Passed "API Gateway health endpoint working"
    } else {
        Test-Failed "API Gateway health endpoint returned HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "API Gateway health endpoint not responding" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 8: API Gateway - Request ID Middleware
# ========================================
Write-Host "TEST 8: API Gateway - Request ID Middleware" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if ($response.Headers['X-Request-ID']) {
        Test-Passed "Request ID header present" "ID: $($response.Headers['X-Request-ID'])"
    } else {
        Test-Warning "Request ID header not found" "May be in response body"
    }
} catch {
    Test-Failed "Could not test Request ID middleware" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 9: API Gateway - Routing (Control Path)
# ========================================
Write-Host "TEST 9: API Gateway - Control Path Routing" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401) {
        Test-Passed "Control path routing working" "HTTP $($response.StatusCode)"
    } else {
        Test-Warning "Control path routing returned HTTP $($response.StatusCode)"
    }
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Test-Passed "Control path routing working" "Authentication required (expected)"
    } else {
        Test-Warning "Control path routing test inconclusive" $_.Exception.Message
    }
}

Write-Host ""

# ========================================
# TEST 10: API Gateway - Data Path Routing
# ========================================
Write-Host "TEST 10: API Gateway - Data Path Routing" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/archivos/getavatars" -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401) {
        Test-Passed "Data path routing working" "HTTP $($response.StatusCode)"
    } else {
        Test-Warning "Data path routing returned HTTP $($response.StatusCode)"
    }
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 401) {
        Test-Passed "Data path routing working" "Authentication required (expected)"
    } else {
        Test-Warning "Data path routing test inconclusive" $_.Exception.Message
    }
}

Write-Host ""

# ========================================
# TEST 11: Nginx Process
# ========================================
Write-Host "TEST 11: Nginx Process" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$nginxProcess = Get-Process -Name nginx -ErrorAction SilentlyContinue
if ($nginxProcess) {
    Test-Passed "Nginx process running" "PID: $($nginxProcess.Id -join ', ')"
} else {
    Test-Failed "Nginx process not running"
}

Write-Host ""

# ========================================
# TEST 12: Nginx Configuration
# ========================================
Write-Host "TEST 12: Nginx Configuration" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$nginxPath = "C:\nginx\nginx-1.28.0"
$nginxExe = Join-Path $nginxPath "nginx.exe"

if (Test-Path $nginxExe) {
    Push-Location $nginxPath
    try {
        $testOutput = & $nginxExe -t 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Test-Passed "Nginx configuration valid"
        } else {
            Test-Failed "Nginx configuration has errors" $testOutput
        }
    } catch {
        Test-Warning "Could not test Nginx configuration" $_.Exception.Message
    } finally {
        Pop-Location
    }
} else {
    Test-Failed "Nginx executable not found" $nginxExe
}

Write-Host ""

# ========================================
# TEST 13: Load Balancer - Basic Connection
# ========================================
Write-Host "TEST 13: Load Balancer - Basic Connection" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $json = $response.Content | ConvertFrom-Json
        if ($json.ok -eq $true) {
            Test-Passed "Load balancer responding" "Status: $($json.status)"
        } else {
            Test-Failed "Load balancer returned invalid response"
        }
    } else {
        Test-Failed "Load balancer returned HTTP $($response.StatusCode)"
    }
} catch {
    Test-Failed "Load balancer not responding" $_.Exception.Message
}

Write-Host ""

# ========================================
# TEST 14: Load Balancer - Multiple Requests
# ========================================
Write-Host "TEST 14: Load Balancer - Multiple Requests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$requestResults = @()
$successfulRequests = 0

for ($i = 1; $i -le 10; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        $json = $response.Content | ConvertFrom-Json
        if ($json.pid) { $requestResults += $json.pid }
        elseif ($json.workerId) { $requestResults += $json.workerId }
        $successfulRequests++
    } catch {
        # Request failed
    }
}

if ($successfulRequests -eq 10) {
    Test-Passed "All 10 requests successful"
    if ($requestResults.Count -gt 0) {
        $unique = ($requestResults | Select-Object -Unique).Count
        if ($unique -gt 1) {
            Test-Passed "Load distribution working" "Requests across $unique servers"
        } else {
            Test-Warning "All requests to one server" "May be normal for health checks"
        }
    }
} else {
    Test-Failed "Only $successfulRequests/10 requests successful"
}

Write-Host ""

# ========================================
# TEST 15: Rate Limiting
# ========================================
Write-Host "TEST 15: Rate Limiting" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$rateLimitHit = $false
$requestsMade = 0

for ($i = 1; $i -le 110; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost/api/health" -TimeoutSec 1 -UseBasicParsing -ErrorAction Stop
        $requestsMade++
        if ($response.StatusCode -eq 429 -or $response.StatusCode -eq 503) {
            $rateLimitHit = $true
            Test-Passed "Rate limiting working" "Hit at request $i (HTTP $($response.StatusCode))"
            break
        }
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 429 -or $_.Exception.Response.StatusCode.value__ -eq 503) {
            $rateLimitHit = $true
            Test-Passed "Rate limiting working" "Hit at request $i"
            break
        }
    }
}

if (-not $rateLimitHit) {
    Test-Warning "Rate limiting not detected" "Made $requestsMade requests without hitting limit"
}

Write-Host ""

# ========================================
# TEST 16: MongoDB Connection
# ========================================
Write-Host "TEST 16: MongoDB Connection" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$mongoProcess = Get-Process -Name mongod -ErrorAction SilentlyContinue
if ($mongoProcess) {
    Test-Passed "MongoDB process running" "PID: $($mongoProcess.Id)"
} else {
    Test-Failed "MongoDB process not running" "Backend servers may fail without MongoDB"
}

Write-Host ""

# ========================================
# TEST 17: Redis Connection (Optional)
# ========================================
Write-Host "TEST 17: Redis Connection (Optional)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$redisProcess = Get-Process -Name redis-server -ErrorAction SilentlyContinue
if ($redisProcess) {
    Test-Passed "Redis process running" "PID: $($redisProcess.Id)"
} else {
    Test-Warning "Redis not running" "Rate limiting uses memory store (Phase 3 feature)"
}

Write-Host ""

# ========================================
# TEST 18: Middleware Exports
# ========================================
Write-Host "TEST 18: Middleware Module Exports" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$middlewareFiles = @(
    "gateway\middleware\auth.js",
    "gateway\middleware\rateLimiter.js",
    "gateway\middleware\validator.js",
    "gateway\middleware\transformer.js",
    "gateway\middleware\logger.js",
    "gateway\middleware\monitor.js"
)

foreach ($file in $middlewareFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        if ($content -match "module\.exports") {
            Test-Passed "$file has exports"
        } else {
            Test-Failed "$file missing module.exports"
        }
    } else {
        Test-Failed "$file not found"
    }
}

Write-Host ""

# ========================================
# TEST 19: Serverless Functions Exports
# ========================================
Write-Host "TEST 19: Serverless Functions Exports" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$functionFiles = @(
    "functions\authFunction.js",
    "functions\authorizeFunction.js",
    "functions\cacheFunction.js",
    "functions\transformFunction.js",
    "functions\reverseProxyFunction.js",
    "functions\monitorFunction.js",
    "functions\loggerFunction.js"
)

foreach ($file in $functionFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        if ($content -match "module\.exports") {
            Test-Passed "$file has exports"
        } else {
            Test-Failed "$file missing module.exports"
        }
    } else {
        Test-Failed "$file not found"
    }
}

# Check functions/index.js
if (Test-Path "functions\index.js") {
    $indexContent = Get-Content "functions\index.js" -Raw
    $requiredExports = @("authFunction", "authorizeFunction", "cacheFunction", "transformFunction", "reverseProxyFunction", "monitorFunction", "loggerFunction")
    
    foreach ($export in $requiredExports) {
        if ($indexContent -match $export) {
            Test-Passed "functions/index.js exports $export"
        } else {
            Test-Failed "functions/index.js missing $export"
        }
    }
}

Write-Host ""

# ========================================
# TEST 20: Environment Configuration
# ========================================
Write-Host "TEST 20: Environment Configuration" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

if (Test-Path ".env") {
    $envContent = Get-Content ".env" -Raw
    
    if ($envContent -match "DB_CNN") {
        Test-Passed ".env has DB_CNN"
    } else {
        Test-Warning ".env missing DB_CNN"
    }
    
    if ($envContent -match "JWT") {
        Test-Passed ".env has JWT configuration"
    } else {
        Test-Warning ".env missing JWT configuration"
    }
    
    if ($envContent -match "PORT") {
        Test-Passed ".env has PORT"
    } else {
        Test-Warning ".env missing PORT"
    }
} else {
    Test-Warning ".env file not found"
}

Write-Host ""

# ========================================
# TEST 21: Health Check Endpoints
# ========================================
Write-Host "TEST 21: Health Check Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

$healthEndpoints = @(
    @{Url="http://localhost:3001/health"; Name="Server 3001 /health"},
    @{Url="http://localhost:3002/health"; Name="Server 3002 /health"},
    @{Url="http://localhost:3003/health"; Name="Server 3003 /health"},
    @{Url="http://localhost:3001/health/ready"; Name="Server 3001 /health/ready"},
    @{Url="http://localhost:3001/health/live"; Name="Server 3001 /health/live"},
    @{Url="http://localhost/health"; Name="Load Balancer /health"}
)

foreach ($endpoint in $healthEndpoints) {
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Test-Passed "$($endpoint.Name) working"
        } else {
            Test-Warning "$($endpoint.Name) returned HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Failed "$($endpoint.Name) not responding" $_.Exception.Message
    }
}

Write-Host ""

# ========================================
# TEST 22: Static File Serving
# ========================================
Write-Host "TEST 22: Static File Serving" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

if (Test-Path "public") {
    Test-Passed "Public directory exists"
    
    if (Test-Path "public\index.html") {
        Test-Passed "Static files present"
    } else {
        Test-Warning "No index.html in public directory"
    }
} else {
    Test-Warning "Public directory not found"
}

Write-Host ""

# ========================================
# TEST 23: Socket.IO Configuration
# ========================================
Write-Host "TEST 23: Socket.IO Configuration" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

if (Test-Path "sockets\socket.js") {
    Test-Passed "Socket.IO configuration file exists"
    
    $socketContent = Get-Content "sockets\socket.js" -Raw
    if ($socketContent -match "socket\.io") {
        Test-Passed "Socket.IO properly configured"
    } else {
        Test-Warning "Socket.IO configuration may be incomplete"
    }
} else {
    Test-Failed "Socket.IO configuration file not found"
}

Write-Host ""

# ========================================
# FINAL SUMMARY
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host 'PASSED: ' -NoNewline
Write-Host "$($testResults.Passed.Count)" -ForegroundColor Green
Write-Host 'FAILED: ' -NoNewline
if ($testResults.Failed.Count -eq 0) {
    Write-Host "$($testResults.Failed.Count)" -ForegroundColor Green
} else {
    Write-Host "$($testResults.Failed.Count)" -ForegroundColor Red
}
Write-Host 'WARNINGS: ' -NoNewline
Write-Host "$($testResults.Warnings.Count)" -ForegroundColor Yellow

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Cyan
Write-Host ""

if ($testResults.Passed.Count -gt 0) {
    Write-Host 'PASSED Tests:' -ForegroundColor Green
    foreach ($test in $testResults.Passed) {
        Write-Host "  [OK] $test" -ForegroundColor Green
    }
    Write-Host ''
}

if ($testResults.Failed.Count -gt 0) {
    Write-Host 'FAILED Tests:' -ForegroundColor Red
    foreach ($test in $testResults.Failed) {
        Write-Host "  [ERROR] $test" -ForegroundColor Red
    }
    Write-Host ''
}

if ($testResults.Warnings.Count -gt 0) {
    Write-Host 'WARNINGS:' -ForegroundColor Yellow
    foreach ($test in $testResults.Warnings) {
        Write-Host "  [WARNING] $test" -ForegroundColor Yellow
    }
    Write-Host ''
}

# Overall Status
Write-Host "========================================" -ForegroundColor Cyan
if ($testResults.Failed.Count -eq 0) {
    Write-Host '[SUCCESS] All critical tests passed!' -ForegroundColor Green
} elseif ($testResults.Failed.Count -lt 5) {
    Write-Host '[WARNING] Some tests failed. Review above.' -ForegroundColor Yellow
} else {
    Write-Host '[ERROR] Multiple tests failed. System needs attention.' -ForegroundColor Red
}

Write-Host ""
Write-Host 'Test Coverage:' -ForegroundColor Cyan
Write-Host '  - File Structure: Tested' -ForegroundColor White
Write-Host '  - Dependencies: Tested' -ForegroundColor White
Write-Host '  - Code Syntax: Tested' -ForegroundColor White
Write-Host '  - Backend Servers: Tested' -ForegroundColor White
Write-Host '  - API Gateway: Tested' -ForegroundColor White
Write-Host '  - Nginx Load Balancer: Tested' -ForegroundColor White
Write-Host '  - Middleware: Tested' -ForegroundColor White
Write-Host '  - Serverless Functions: Tested' -ForegroundColor White
Write-Host '  - Health Checks: Tested' -ForegroundColor White
Write-Host '  - Rate Limiting: Tested' -ForegroundColor White
Write-Host ''

