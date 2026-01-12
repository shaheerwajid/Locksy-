# Start Metadata Server - Reliable Version
# Starts Metadata Server in a way that keeps it running

Write-Host "Starting Metadata Server..." -ForegroundColor Cyan

# Set environment variables
$env:NODE_ENV = 'development'
$env:METADATA_SERVER_ENABLED = 'true'
$env:METADATA_SERVER_PORT = '3004'
$env:USE_GATEWAY = 'false'
$env:ENABLE_CLUSTER = 'false'
$env:SKIP_MAIN_SERVER = 'true'

# Change to project directory
Set-Location $PSScriptRoot\..

# Start Metadata Server in a new PowerShell window that stays open
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "`$env:NODE_ENV='development'; `$env:METADATA_SERVER_ENABLED='true'; `$env:METADATA_SERVER_PORT='3004'; `$env:USE_GATEWAY='false'; `$env:ENABLE_CLUSTER='false'; `$env:SKIP_MAIN_SERVER='true'; cd '$PWD'; Write-Host 'Starting Metadata Server...' -ForegroundColor Cyan; node scripts/start-metadata-server.js; Write-Host '`nMetadata Server is running. Close this window to stop it.' -ForegroundColor Yellow"
) -WindowStyle Normal

Write-Host "Metadata Server started in new PowerShell window" -ForegroundColor Green
Write-Host "Waiting 15 seconds for server to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Test if server is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3004/health" -Method GET -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Metadata Server is running and healthy!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Metadata Server responded with status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Metadata Server is not responding. Check the PowerShell window for errors." -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}






