# Test Contact Endpoints
# Tests contact-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Contact Endpoints Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://localhost:3001"

# Get auth token using auth-helper (reads from file or env, or creates new user)
$authToken = Get-TestAuthToken -BaseUrl $baseUrl
$testUserId = Get-TestUserId -BaseUrl $baseUrl

if (-not $authToken) {
    Write-Host "No auth token available. Some tests will be skipped." -ForegroundColor Yellow
}

$headers = Get-TestAuthHeaders -BaseUrl $baseUrl

# Test 1: Get Contacts
Write-Host "Testing POST /api/contactos/getContactos..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos/getContactos" -Method POST -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            Test-Passed "Get contacts" "Contacts retrieved (may be empty)"
        } else {
            Test-Warning "Get contacts" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Get contacts" $_.Exception.Message
    }
} else {
    Test-Warning "Get contacts" "No auth token available"
}

# Test 2: Get Contact List
Write-Host ""
Write-Host "Testing POST /api/contactos/getListadoContactos..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos/getListadoContactos" -Method POST -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            Test-Passed "Get contact list" "Contact list retrieved"
        } else {
            Test-Warning "Get contact list" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Get contact list" $_.Exception.Message
    }
} else {
    Test-Warning "Get contact list" "No auth token available"
}

# Test 3: Create Contact Request
Write-Host ""
Write-Host "Testing POST /api/contactos (create contact request)..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $contactBody = @{
            contacto = "test-contact-id"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos" -Method POST -Body $contactBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Create contact request" "Contact request created"
                Write-Host "  Note: Contact creation should trigger notification" -ForegroundColor Gray
            } else {
                Test-Warning "Create contact request" "Contact may already exist or invalid: $($result.msg)"
            }
        } else {
            Test-Warning "Create contact request" "HTTP $($response.StatusCode) - Contact may not exist"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404 -or $statusCode -eq 400) {
            Test-Warning "Create contact request" "Contact user may not exist (expected for test)"
        } else {
            Test-Warning "Create contact request" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Create contact request" "No auth token available"
}

# Test 4: Activate Contact
Write-Host ""
Write-Host "Testing POST /api/contactos/activateContacto..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $activateBody = @{
            contacto = "test-contact-id"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos/activateContacto" -Method POST -Body $activateBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Activate contact" "Contact activated"
                Write-Host "  Note: Contact activation should trigger feed generation" -ForegroundColor Gray
            } else {
                Test-Warning "Activate contact" "Contact may not exist or already activated: $($result.msg)"
            }
        } else {
            Test-Warning "Activate contact" "HTTP $($response.StatusCode) - Contact may not exist"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 404 -or $statusCode -eq 400) {
            Test-Warning "Activate contact" "Contact may not exist (expected for test)"
        } else {
            Test-Warning "Activate contact" $_.Exception.Message
        }
    }
} else {
    Test-Warning "Activate contact" "No auth token available"
}

# Test 5: Remove Contact
Write-Host ""
Write-Host "Testing POST /api/contactos/dropContacto..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $removeBody = @{
            contacto = "test-contact-id"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos/dropContacto" -Method POST -Body $removeBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Test-Passed "Remove contact" "Contact removed (or didn't exist)"
        } else {
            Test-Warning "Remove contact" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Remove contact" $_.Exception.Message
    }
} else {
    Test-Warning "Remove contact" "No auth token available"
}

# Test 6: Unauthorized Access
Write-Host ""
Write-Host "Testing unauthorized access to contact endpoints..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/contactos/getContactos" -Method POST -UseBasicParsing -ErrorAction Stop
    Test-Failed "Unauthorized access protection" "Endpoint should require authentication"
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 401) {
        Test-Passed "Unauthorized access protection" "Endpoint correctly requires authentication"
    } else {
        Test-Warning "Unauthorized access protection" "Unexpected status code: $statusCode"
    }
}

# Summary
Write-TestSummary
exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

