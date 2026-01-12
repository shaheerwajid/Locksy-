# Comprehensive Test Suite Runner
# Runs all tests in the correct order

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Comprehensive System Test Suite" -ForegroundColor Cyan
Write-Host "Locksy Backend - System Design Master Template" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$script:StartTime = Get-Date
$script:TestResults = @{
    Infrastructure = @{Passed=0; Failed=0; Warnings=0}
    Services = @{Passed=0; Failed=0; Warnings=0}
    Workers = @{Passed=0; Failed=0; Warnings=0}
    Queues = @{Passed=0; Failed=0; Warnings=0}
    Flows = @{Passed=0; Failed=0; Warnings=0}
    Integration = @{Passed=0; Failed=0; Warnings=0}
}

function Run-TestSuite {
    param(
        [string]$Category,
        [string]$TestScript
    )
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Running: $Category" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $TestScript)) {
        Write-Host "  [SKIP] Test script not found: $TestScript" -ForegroundColor Yellow
        return
    }
    
    try {
        & $TestScript
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            $script:TestResults[$Category].Passed++
        } else {
            $script:TestResults[$Category].Failed++
        }
    } catch {
        Write-Host "  [ERROR] Test failed: $_" -ForegroundColor Red
        $script:TestResults[$Category].Failed++
    }
}

# ========================================
# Infrastructure Tests
# ========================================
Write-Host "PHASE 1: Infrastructure Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/docker-services.ps1"
Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/mongodb-replica.ps1"

# Additional infrastructure tests would go here
# Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/redis.ps1"
# Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/rabbitmq.ps1"
# Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/elasticsearch.ps1"
# Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/zookeeper.ps1"
# Run-TestSuite -Category "Infrastructure" -TestScript "$PSScriptRoot/infrastructure/jaeger.ps1"

# ========================================
# Service Tests
# ========================================
Write-Host ""
Write-Host "PHASE 2: Service Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/api-gateway.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/metadata-server.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/block-server.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/storage.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/cdn.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/sharding.ps1"
Run-TestSuite -Category "Services" -TestScript "$PSScriptRoot/services/warehouse.ps1"

# ========================================
# Queue Tests
# ========================================
Write-Host ""
Write-Host "PHASE 3: Queue Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Queues" -TestScript "$PSScriptRoot/services/queues.ps1"

# ========================================
# Worker Tests
# ========================================
Write-Host ""
Write-Host "PHASE 4: Worker Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Workers" -TestScript "$PSScriptRoot/services/workers.ps1"

# ========================================
# Search and Feed Tests
# ========================================
Write-Host ""
Write-Host "PHASE 5: Search and Feed Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Flows" -TestScript "$PSScriptRoot/services/search.ps1"
Run-TestSuite -Category "Flows" -TestScript "$PSScriptRoot/services/feed-generation.ps1"

# ========================================
# Coordination and Observability Tests
# ========================================
Write-Host ""
Write-Host "PHASE 6: Coordination and Observability Tests" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

Run-TestSuite -Category "Integration" -TestScript "$PSScriptRoot/services/coordination.ps1"
Run-TestSuite -Category "Integration" -TestScript "$PSScriptRoot/services/observability.ps1"

# ========================================
# Final Summary
# ========================================
$endTime = Get-Date
$duration = $endTime - $script:StartTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Suite Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalPassed = 0
$totalFailed = 0
$totalWarnings = 0

foreach ($category in $script:TestResults.GetEnumerator()) {
    $passed = $category.Value.Passed
    $failed = $category.Value.Failed
    $warnings = $category.Value.Warnings
    
    $totalPassed += $passed
    $totalFailed += $failed
    $totalWarnings += $warnings
    
    if ($passed -gt 0 -or $failed -gt 0 -or $warnings -gt 0) {
        Write-Host "$($category.Key):" -ForegroundColor Yellow
        Write-Host "  Passed:  $passed" -ForegroundColor Green
        Write-Host "  Failed:  $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
        Write-Host "  Warnings: $warnings" -ForegroundColor $(if ($warnings -gt 0) { "Yellow" } else { "Gray" })
        Write-Host ""
    }
}

Write-Host "Overall:" -ForegroundColor Cyan
Write-Host "  Passed:  $totalPassed" -ForegroundColor Green
Write-Host "  Failed:  $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Gray" })
Write-Host "  Warnings: $totalWarnings" -ForegroundColor $(if ($totalWarnings -gt 0) { "Yellow" } else { "Gray" })
Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Cyan
Write-Host ""

if ($totalFailed -eq 0) {
    Write-Host "[SUCCESS] All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAILURE] Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}

