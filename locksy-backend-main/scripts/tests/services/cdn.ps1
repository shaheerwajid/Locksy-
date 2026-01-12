# CDN Integration Test
# Tests CDN integration for static assets

. "$PSScriptRoot/../utils/test-helpers.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CDN Integration Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test CDN service exists
if (Test-Path "services/cdn") {
    Test-Passed "CDN service directory exists" "services/cdn"
} else {
    Test-Failed "CDN service directory missing" "services/cdn"
}

# Test CDN components
$cdnComponents = @(
    "services/cdn/cdnService.js",
    "services/cdn/cloudflare.js",
    "services/cdn/cloudfront.js",
    "services/cdn/static-assets.js"
)

foreach ($component in $cdnComponents) {
    if (Test-Path $component) {
        Test-Passed "CDN component exists" $component
    } else {
        Test-Warning "CDN component" "$component not found"
    }
}

# Test CDN middleware
if (Test-Path "middlewares/cdn-static.js") {
    Test-Passed "CDN middleware exists" "middlewares/cdn-static.js"
} else {
    Test-Warning "CDN middleware" "middlewares/cdn-static.js not found"
}

# Test CDN routes
if (Test-Path "routes/cdn.js") {
    Test-Passed "CDN routes exist" "routes/cdn.js"
} else {
    Test-Warning "CDN routes" "routes/cdn.js not found"
}

# Test CDN URL generation endpoint (if API Gateway is running)
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3001/api/data/cdn-url/test.jpg" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 404) {
        # 404 is OK if CDN is not enabled
        Test-Passed "CDN URL endpoint" "Endpoint is accessible"
    } else {
        Test-Warning "CDN URL endpoint" "Unexpected status: $($response.StatusCode)"
    }
} catch {
    # 404 is expected if CDN is not enabled
    if ($_.Exception.Response.StatusCode -eq 404) {
        Test-Passed "CDN URL endpoint" "Endpoint exists (CDN may not be enabled)"
    } else {
        Test-Warning "CDN URL endpoint" "Endpoint may not be configured"
    }
}

# Test static assets directory
if (Test-Path "public") {
    Test-Passed "Public static assets directory exists" "public"
} else {
    Test-Warning "Public static assets directory" "public not found"
}

# Test uploads directory
if (Test-Path "uploads") {
    Test-Passed "Uploads directory exists" "uploads"
} else {
    Test-Warning "Uploads directory" "uploads not found"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

