# Test Service-Dependent Endpoints
# Tests endpoints that require RabbitMQ, Elasticsearch, Metadata Server, or Block Server

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

Write-Host "=== SERVICE-DEPENDENT ENDPOINTS TEST ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login to get token
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
        Write-Host "  ❌ Login failed: Invalid response" -ForegroundColor Red
        $TestResults.Failed += "Login"
        exit 1
    }
} catch {
    Write-Host "  ❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Login"
    exit 1
}

Start-Sleep -Seconds 1

# Step 2: Check Service Health
Write-Host "`nStep 2: Service Health Checks" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Check RabbitMQ
try {
    $rmq = Invoke-RestMethod -Uri "http://localhost:15672/api/overview" -Headers @{Authorization="Basic Z3Vlc3Q6Z3Vlc3Q="} -TimeoutSec 5
    Write-Host "  ✅ RabbitMQ: Running (v$($rmq.rabbitmq_version))" -ForegroundColor Green
    $TestResults.Passed += "RabbitMQ Health"
} catch {
    Write-Host "  ❌ RabbitMQ: Not accessible" -ForegroundColor Red
    $TestResults.Failed += "RabbitMQ Health"
}

# Check Elasticsearch
try {
    $es = Invoke-RestMethod -Uri "http://localhost:9200/_cluster/health" -TimeoutSec 5
    Write-Host "  ✅ Elasticsearch: $($es.status) (nodes: $($es.number_of_nodes))" -ForegroundColor Green
    $TestResults.Passed += "Elasticsearch Health"
} catch {
    Write-Host "  ❌ Elasticsearch: Not accessible" -ForegroundColor Red
    $TestResults.Failed += "Elasticsearch Health"
}

# Check Metadata Server
try {
    $meta = Invoke-RestMethod -Uri "http://localhost:3004/health" -TimeoutSec 3
    Write-Host "  ✅ Metadata Server: Running" -ForegroundColor Green
    $TestResults.Passed += "Metadata Server Health"
} catch {
    Write-Host "  ⚠️  Metadata Server: Not running (endpoints will use main server)" -ForegroundColor Yellow
    $TestResults.Warnings += "Metadata Server Health"
}

# Check Block Server
try {
    $block = Invoke-RestMethod -Uri "http://localhost:3005/health" -TimeoutSec 3
    Write-Host "  ✅ Block Server: Running" -ForegroundColor Green
    $TestResults.Passed += "Block Server Health"
} catch {
    Write-Host "  ⚠️  Block Server: Not running (endpoints will use main server)" -ForegroundColor Yellow
    $TestResults.Warnings += "Block Server Health"
}

Start-Sleep -Seconds 1

# Step 3: Test Feed Endpoints (Requires RabbitMQ)
Write-Host "`nStep 3: Feed Endpoints (Requires RabbitMQ)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Get User Feed
try {
    $feed = Invoke-RestMethod -Uri "$BaseUrl/api/feed/user" -Method GET -Headers $headers -TimeoutSec 10
    if ($feed.ok) {
        Write-Host "  ✅ Get User Feed" -ForegroundColor Green
        $TestResults.Passed += "Get User Feed"
    } else {
        Write-Host "  ⚠️  Get User Feed: $($feed.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Get User Feed"
    }
} catch {
    Write-Host "  ❌ Get User Feed: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Get User Feed"
}
Start-Sleep -Milliseconds 500

# Generate User Feed
try {
    $generateBody = @{options=@{}} | ConvertTo-Json
    $feedGen = Invoke-RestMethod -Uri "$BaseUrl/api/feed/user/generate" -Method POST -Headers $headers -Body $generateBody -TimeoutSec 15
    if ($feedGen.ok -or $feedGen.status) {
        Write-Host "  ✅ Generate User Feed" -ForegroundColor Green
        $TestResults.Passed += "Generate User Feed"
    } else {
        Write-Host "  ⚠️  Generate User Feed: $($feedGen.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Generate User Feed"
    }
} catch {
    Write-Host "  ❌ Generate User Feed: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Generate User Feed"
}
Start-Sleep -Milliseconds 500

# Get Group Feed (using a test group ID - may fail if group doesn't exist)
try {
    $groupFeed = Invoke-RestMethod -Uri "$BaseUrl/api/feed/group/TEST_GROUP" -Method GET -Headers $headers -TimeoutSec 10
    if ($groupFeed.ok) {
        Write-Host "  ✅ Get Group Feed" -ForegroundColor Green
        $TestResults.Passed += "Get Group Feed"
    } else {
        Write-Host "  ⚠️  Get Group Feed: Group may not exist" -ForegroundColor Yellow
        $TestResults.Warnings += "Get Group Feed"
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  ⚠️  Get Group Feed: Group not found (expected)" -ForegroundColor Yellow
        $TestResults.Warnings += "Get Group Feed"
    } else {
        Write-Host "  ❌ Get Group Feed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "Get Group Feed"
    }
}
Start-Sleep -Milliseconds 500

# Generate Group Feed
try {
    $groupGenBody = @{options=@{}} | ConvertTo-Json
    $groupGen = Invoke-RestMethod -Uri "$BaseUrl/api/feed/group/TEST_GROUP/generate" -Method POST -Headers $headers -Body $groupGenBody -TimeoutSec 15
    if ($groupGen.ok -or $groupGen.status) {
        Write-Host "  ✅ Generate Group Feed" -ForegroundColor Green
        $TestResults.Passed += "Generate Group Feed"
    } else {
        Write-Host "  ⚠️  Generate Group Feed: $($groupGen.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Generate Group Feed"
    }
} catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  ⚠️  Generate Group Feed: Group not found (expected)" -ForegroundColor Yellow
        $TestResults.Warnings += "Generate Group Feed"
    } else {
        Write-Host "  ❌ Generate Group Feed: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "Generate Group Feed"
    }
}
Start-Sleep -Milliseconds 500

# Generate Activity Feed
try {
    $activityBody = @{options=@{}} | ConvertTo-Json
    $activity = Invoke-RestMethod -Uri "$BaseUrl/api/feed/activity/generate" -Method POST -Headers $headers -Body $activityBody -TimeoutSec 15
    if ($activity.ok -or $activity.status) {
        Write-Host "  ✅ Generate Activity Feed" -ForegroundColor Green
        $TestResults.Passed += "Generate Activity Feed"
    } else {
        Write-Host "  ⚠️  Generate Activity Feed: $($activity.msg)" -ForegroundColor Yellow
        $TestResults.Warnings += "Generate Activity Feed"
    }
} catch {
    Write-Host "  ❌ Generate Activity Feed: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Generate Activity Feed"
}
Start-Sleep -Seconds 1

# Step 4: Test Search Endpoints (Requires Elasticsearch)
Write-Host "`nStep 4: Search Endpoints (Requires Elasticsearch)" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Search All
try {
    $searchAll = Invoke-RestMethod -Uri "$BaseUrl/api/search/search?q=test" -Method GET -Headers $headers -TimeoutSec 10
    if ($searchAll.ok) {
        Write-Host "  ✅ Search All" -ForegroundColor Green
        $TestResults.Passed += "Search All"
    } else {
        Write-Host "  ⚠️  Search All: $($searchAll.message)" -ForegroundColor Yellow
        $TestResults.Warnings += "Search All"
    }
} catch {
    Write-Host "  ❌ Search All: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Search All"
}
Start-Sleep -Milliseconds 500

# Search Users
try {
    $searchUsers = Invoke-RestMethod -Uri "$BaseUrl/api/search/search/users?q=test" -Method GET -Headers $headers -TimeoutSec 10
    if ($searchUsers.ok) {
        Write-Host "  ✅ Search Users" -ForegroundColor Green
        $TestResults.Passed += "Search Users"
    } else {
        Write-Host "  ⚠️  Search Users: $($searchUsers.message)" -ForegroundColor Yellow
        $TestResults.Warnings += "Search Users"
    }
} catch {
    Write-Host "  ❌ Search Users: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Search Users"
}
Start-Sleep -Milliseconds 500

# Search Messages
try {
    $searchMessages = Invoke-RestMethod -Uri "$BaseUrl/api/search/search/messages?q=test" -Method GET -Headers $headers -TimeoutSec 10
    if ($searchMessages.ok) {
        Write-Host "  ✅ Search Messages" -ForegroundColor Green
        $TestResults.Passed += "Search Messages"
    } else {
        Write-Host "  ⚠️  Search Messages: $($searchMessages.message)" -ForegroundColor Yellow
        $TestResults.Warnings += "Search Messages"
    }
} catch {
    Write-Host "  ❌ Search Messages: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Search Messages"
}
Start-Sleep -Milliseconds 500

# Search Groups
try {
    $searchGroups = Invoke-RestMethod -Uri "$BaseUrl/api/search/search/groups?q=test" -Method GET -Headers $headers -TimeoutSec 10
    if ($searchGroups.ok) {
        Write-Host "  ✅ Search Groups" -ForegroundColor Green
        $TestResults.Passed += "Search Groups"
    } else {
        Write-Host "  ⚠️  Search Groups: $($searchGroups.message)" -ForegroundColor Yellow
        $TestResults.Warnings += "Search Groups"
    }
} catch {
    Write-Host "  ❌ Search Groups: $($_.Exception.Message)" -ForegroundColor Red
    $TestResults.Failed += "Search Groups"
}
Start-Sleep -Seconds 1

# Step 5: Test Block Server Endpoints (if running)
Write-Host "`nStep 5: Block Server Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Block Server Health
try {
    $blockHealth = Invoke-RestMethod -Uri "http://localhost:3005/health" -Method GET -TimeoutSec 3
    Write-Host "  ✅ Block Server Health" -ForegroundColor Green
    $TestResults.Passed += "Block Server Health"
    
    # Test Block Server file endpoints if available
    # Note: File upload requires multipart/form-data, so we'll just test if the server responds
    Write-Host "  ℹ️  Block Server file upload/download endpoints require multipart/form-data" -ForegroundColor Gray
    $TestResults.Skipped += "Block Server File Upload (requires multipart)"
} catch {
    Write-Host "  ⚠️  Block Server: Not running, file operations will use main server" -ForegroundColor Yellow
    $TestResults.Warnings += "Block Server Endpoints"
}
Start-Sleep -Milliseconds 500

# Step 6: Test Metadata Server Endpoints (if running)
Write-Host "`nStep 6: Metadata Server Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Metadata Server Health
try {
    $metaHealth = Invoke-RestMethod -Uri "http://localhost:3004/health" -Method GET -TimeoutSec 3
    Write-Host "  ✅ Metadata Server Health" -ForegroundColor Green
    $TestResults.Passed += "Metadata Server Health"
    Write-Host "  ℹ️  Metadata operations are handled through main server (port 3000)" -ForegroundColor Gray
} catch {
    Write-Host "  ⚠️  Metadata Server: Not running, metadata operations use main server" -ForegroundColor Yellow
    $TestResults.Warnings += "Metadata Server Endpoints"
}
Start-Sleep -Milliseconds 500

# Step 7: Test Analytics Endpoints (if available)
Write-Host "`nStep 7: Analytics Endpoints" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Daily Reports
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
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  ⚠️  Analytics endpoints: Not available (route may not be registered)" -ForegroundColor Yellow
        $TestResults.Warnings += "Analytics Endpoints"
    } else {
        Write-Host "  ❌ Daily Reports: $($_.Exception.Message)" -ForegroundColor Red
        $TestResults.Failed += "Daily Reports"
    }
}
Start-Sleep -Milliseconds 500

# Summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
Write-Host "Passed: $($TestResults.Passed.Count)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.Failed.Count)" -ForegroundColor Red
Write-Host "Warnings: $($TestResults.Warnings.Count)" -ForegroundColor Yellow
Write-Host "Skipped: $($TestResults.Skipped.Count)" -ForegroundColor Gray
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

$totalTests = $TestResults.Passed.Count + $TestResults.Failed.Count + $TestResults.Warnings.Count
$successRate = if ($totalTests -gt 0) { [math]::Round(($TestResults.Passed.Count / $totalTests) * 100, 2) } else { 0 }
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })


