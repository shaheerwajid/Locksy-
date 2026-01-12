# Test Helper Functions
# Common utilities for all test scripts

$global:TestResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
    StartTime = Get-Date
}

function Test-Passed {
    param(
        [string]$Test,
        [string]$Details = ""
    )
    Write-Host "  [PASS] $Test" -ForegroundColor Green
    if ($Details) {
        Write-Host "        $Details" -ForegroundColor Gray
    }
    $global:TestResults.Passed += $Test
}

function Test-Failed {
    param(
        [string]$Test,
        [string]$Details = ""
    )
    Write-Host "  [FAIL] $Test" -ForegroundColor Red
    if ($Details) {
        Write-Host "        $Details" -ForegroundColor Gray
    }
    $global:TestResults.Failed += $Test
}

function Test-Warning {
    param(
        [string]$Test,
        [string]$Details = ""
    )
    Write-Host "  [WARN] $Test" -ForegroundColor Yellow
    if ($Details) {
        Write-Host "        $Details" -ForegroundColor Gray
    }
    $global:TestResults.Warnings += $Test
}

function Test-HTTPEndpoint {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int]$ExpectedStatus = 200,
        [int]$Timeout = 10
    )
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = $Timeout
            UseBasicParsing = $true
            ErrorAction = "Stop"
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = if ($Body -is [string]) { $Body } else { ($Body | ConvertTo-Json) }
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        
        if ($response.StatusCode -eq $ExpectedStatus) {
            return @{
                Success = $true
                StatusCode = $response.StatusCode
                Content = $response.Content
                Response = $response
            }
        } else {
            return @{
                Success = $false
                StatusCode = $response.StatusCode
                Error = "Expected status $ExpectedStatus, got $($response.StatusCode)"
            }
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = $_.Exception.Response.StatusCode.value__
        }
    }
}

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [string]$HealthUrl,
        [int]$Timeout = 5
    )
    
    $result = Test-HTTPEndpoint -Url $HealthUrl -Timeout $Timeout
    
    if ($result.Success) {
        try {
            $json = $result.Content | ConvertFrom-Json
            if ($json.ok -or $json.status -eq "healthy" -or $json.status -eq "ready") {
                Test-Passed "$ServiceName health check" "$HealthUrl"
                return $true
            } else {
                Test-Failed "$ServiceName health check" "Service returned unhealthy status"
                return $false
            }
        } catch {
            Test-Warning "$ServiceName health check" "Could not parse response"
            return $false
        }
    } else {
        Test-Failed "$ServiceName health check" "$($result.Error)"
        return $false
    }
}

function Test-DockerContainer {
    param(
        [string]$ContainerName
    )
    
    try {
        $status = docker ps --filter "name=$ContainerName" --format "{{.Status}}" 2>&1
        if ($status -match "Up") {
            return $true
        } else {
            return $false
        }
    } catch {
        return $false
    }
}

function Test-Port {
    param(
        [int]$Port,
        [string]$HostName = "localhost"
    )
    
    try {
        $connection = Test-NetConnection -ComputerName $HostName -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet
        return $connection
    } catch {
        return $false
    }
}

function Get-TestSummary {
    $endTime = Get-Date
    $duration = $endTime - $global:TestResults.StartTime
    
    return @{
        Passed = $global:TestResults.Passed.Count
        Failed = $global:TestResults.Failed.Count
        Warnings = $global:TestResults.Warnings.Count
        Duration = $duration
        Total = $global:TestResults.Passed.Count + $global:TestResults.Failed.Count + $global:TestResults.Warnings.Count
    }
}

function Write-TestSummary {
    $summary = Get-TestSummary
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Passed:  $($summary.Passed)" -ForegroundColor Green
    Write-Host "  Failed:  $($summary.Failed)" -ForegroundColor $(if ($summary.Failed -gt 0) { "Red" } else { "Gray" })
    Write-Host "  Warnings: $($summary.Warnings)" -ForegroundColor $(if ($summary.Warnings -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "  Total:   $($summary.Total)" -ForegroundColor Cyan
    Write-Host "  Duration: $($summary.Duration.TotalSeconds) seconds" -ForegroundColor Cyan
    Write-Host ""
    
    if ($summary.Failed -gt 0) {
        Write-Host "Failed Tests:" -ForegroundColor Red
        foreach ($test in $global:TestResults.Failed) {
            Write-Host "  - $test" -ForegroundColor Red
        }
        Write-Host ""
        return 1
    } else {
        return 0
    }
}

function Reset-TestResults {
    $global:TestResults = @{
        Passed = @()
        Failed = @()
        Warnings = @()
        StartTime = Get-Date
    }
}


