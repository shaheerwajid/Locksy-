#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start all worker processes for the Locksy Backend

.DESCRIPTION
    This script starts all worker processes:
    - Video Processing Workers
    - Analytics Workers
    - Search Indexing Worker (started automatically by Metadata Server)

.NOTES
    Make sure all required services are running:
    - MongoDB
    - Redis
    - RabbitMQ
    - Elasticsearch
#>

Write-Host "Starting all Locksy Backend workers..." -ForegroundColor Green

# Check if Node.js is available
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

# Change to root directory
Set-Location $rootDir

# Start Video Workers
Write-Host "`nStarting Video Processing Workers..." -ForegroundColor Yellow
Start-Process -NoNewWindow -FilePath "node" -ArgumentList "scripts/start-video-workers.js" -WorkingDirectory $rootDir
Start-Sleep -Seconds 2

# Start Analytics Workers
Write-Host "Starting Analytics Workers..." -ForegroundColor Yellow
Start-Process -NoNewWindow -FilePath "node" -ArgumentList "scripts/start-analytics-workers.js" -WorkingDirectory $rootDir
Start-Sleep -Seconds 2

Write-Host "`nAll workers started!" -ForegroundColor Green
Write-Host "Note: Search Indexing Worker is started automatically by Metadata Server" -ForegroundColor Cyan
Write-Host "`nTo stop all workers, use: Get-Process -Name node | Where-Object { $_.Path -like '*node.exe' } | Stop-Process" -ForegroundColor Gray






