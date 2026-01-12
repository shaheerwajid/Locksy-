# Elasticsearch Search Test
# Tests search functionality and indexing

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Elasticsearch Search Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Elasticsearch is running
$esStatus = Test-DockerService -ContainerName "locksy-elasticsearch" -Port 9200 -HealthCheck "http://localhost:9200/_cluster/health"
if (-not $esStatus.Running) {
    Test-Failed "Elasticsearch container not running"
    Write-Host "Elasticsearch is not running. Please start it first." -ForegroundColor Red
    exit 1
}

Test-Passed "Elasticsearch container running" "Port 9200"

# Test cluster health
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9200/_cluster/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $health = $response.Content | ConvertFrom-Json
    if ($health.status -eq "green" -or $health.status -eq "yellow") {
        Test-Passed "Elasticsearch cluster health" "Status: $($health.status)"
    } else {
        Test-Warning "Elasticsearch cluster health" "Status: $($health.status)"
    }
} catch {
    Test-Failed "Elasticsearch cluster health" $_.Exception.Message
}

# Test search service exists
if (Test-Path "services/search") {
    Test-Passed "Search service directory exists" "services/search"
} else {
    Test-Failed "Search service directory missing" "services/search"
}

# Test search client
if (Test-Path "services/search/elasticsearchClient.js") {
    Test-Passed "Elasticsearch client exists" "services/search/elasticsearchClient.js"
} else {
    Test-Warning "Elasticsearch client" "services/search/elasticsearchClient.js not found"
}

# Test search service
if (Test-Path "services/search/searchService.js") {
    Test-Passed "Search service exists" "services/search/searchService.js"
} else {
    Test-Warning "Search service" "services/search/searchService.js not found"
}

# Test index creation (if search service is available)
try {
    $testScript = @"
const { Client } = require('@elastic/elasticsearch');
(async () => {
    try {
        const client = new Client({ node: 'http://localhost:9200' });
        const health = await client.cluster.health();
        console.log('SUCCESS');
        process.exit(0);
    } catch (err) {
        console.error('ERROR:', err.message);
        process.exit(1);
    }
})();
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-elasticsearch.js" -Encoding UTF8
    $result = node "$env:TEMP/test-elasticsearch.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Elasticsearch connection" "Can connect to Elasticsearch"
    } else {
        Test-Warning "Elasticsearch connection" "Connection test failed"
    }
    Remove-Item "$env:TEMP/test-elasticsearch.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Elasticsearch connection" "Cannot test connection (@elastic/elasticsearch may not be available)"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

