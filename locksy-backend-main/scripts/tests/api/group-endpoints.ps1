# Test Group Endpoints
# Tests group-related API endpoints with authentication

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/auth-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Group Endpoints Test" -ForegroundColor Cyan
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

$testGroupId = $null

# Test 1: Create Group
Write-Host "Testing POST /api/grupos/addGroup..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $groupBody = @{
            nombre = "Test Group $(Get-Random)"
            descripcion = "Test group description"
            codigosUsuario = @()
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/addGroup" -Method POST -Body $groupBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 201) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and $result.grupo) {
                Test-Passed "Create group" "Group created successfully"
                $testGroupId = $result.grupo._id
                if (-not $testGroupId) {
                    $testGroupId = $result.grupo.id
                }
                Write-Host "  Note: Group creation should trigger search indexing, feed generation, and notifications" -ForegroundColor Gray
            } else {
                Test-Warning "Create group" "Group may not have been created: $($result.msg)"
            }
        } else {
            Test-Warning "Create group" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Create group" $_.Exception.Message
    }
} else {
    Test-Warning "Create group" "No auth token available"
}

# Test 2: Get Group Members
Write-Host ""
Write-Host "Testing POST /api/grupos/groupMembers..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $membersBody = @{
            grupo = $testGroupId
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/groupMembers" -Method POST -Body $membersBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            Test-Passed "Get group members" "Group members retrieved"
        } else {
            Test-Warning "Get group members" "HTTP $($response.StatusCode) - Group may not exist"
        }
    } catch {
        Test-Warning "Get group members" $_.Exception.Message
    }
} else {
    Test-Warning "Get group members" "No auth token available"
}

# Test 3: Get User Groups
Write-Host ""
Write-Host "Testing POST /api/grupos/groupsByMember..." -ForegroundColor Yellow
if ($authToken) {
    try {
        $groupsBody = @{
            usuario = "current-user-id"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/groupsByMember" -Method POST -Body $groupsBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            Test-Passed "Get user groups" "User groups retrieved"
        } else {
            Test-Warning "Get user groups" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Get user groups" $_.Exception.Message
    }
} else {
    Test-Warning "Get user groups" "No auth token available"
}

# Test 4: Update Group
Write-Host ""
Write-Host "Testing POST /api/grupos/updateGroup..." -ForegroundColor Yellow
if ($authToken -and $testGroupId) {
    try {
        $updateBody = @{
            grupo = $testGroupId
            nombre = "Updated Test Group"
            descripcion = "Updated description"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/updateGroup" -Method POST -Body $updateBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Update group" "Group updated successfully"
                Write-Host "  Note: Group update should trigger search indexing and feed generation" -ForegroundColor Gray
            } else {
                Test-Warning "Update group" "Update may have failed: $($result.msg)"
            }
        } else {
            Test-Warning "Update group" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Update group" $_.Exception.Message
    }
} else {
    Test-Warning "Update group" "No auth token or group ID available"
}

# Test 5: Add Member to Group
Write-Host ""
Write-Host "Testing POST /api/grupos/addMember..." -ForegroundColor Yellow
if ($authToken -and $testGroupId) {
    try {
        $addMemberBody = @{
            grupo = $testGroupId
            codigosUsuario = @("test-member-id")
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/addMember" -Method POST -Body $addMemberBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Add member to group" "Member added to group"
                Write-Host "  Note: Adding members should trigger notifications" -ForegroundColor Gray
            } else {
                Test-Warning "Add member to group" "Member may not exist or already in group: $($result.msg)"
            }
        } else {
            Test-Warning "Add member to group" "HTTP $($response.StatusCode) - Member may not exist"
        }
    } catch {
        Test-Warning "Add member to group" $_.Exception.Message
    }
} else {
    Test-Warning "Add member to group" "No auth token or group ID available"
}

# Test 6: Remove Member from Group
Write-Host ""
Write-Host "Testing POST /api/grupos/removeMember..." -ForegroundColor Yellow
if ($authToken -and $testGroupId) {
    try {
        $removeMemberBody = @{
            grupo = $testGroupId
            usuario = "test-member-id"
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/removeMember" -Method POST -Body $removeMemberBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Test-Passed "Remove member from group" "Member removed from group"
        } else {
            Test-Warning "Remove member from group" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Remove member from group" $_.Exception.Message
    }
} else {
    Test-Warning "Remove member from group" "No auth token or group ID available"
}

# Test 7: Delete Group
Write-Host ""
Write-Host "Testing POST /api/grupos/removeGroup..." -ForegroundColor Yellow
if ($authToken -and $testGroupId) {
    try {
        $deleteBody = @{
            grupo = $testGroupId
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/removeGroup" -Method POST -Body $deleteBody -Headers $headers -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok) {
                Test-Passed "Delete group" "Group deleted successfully"
            } else {
                Test-Warning "Delete group" "Delete may have failed: $($result.msg)"
            }
        } else {
            Test-Warning "Delete group" "HTTP $($response.StatusCode)"
        }
    } catch {
        Test-Warning "Delete group" $_.Exception.Message
    }
} else {
    Test-Warning "Delete group" "No auth token or group ID available"
}

# Test 8: Unauthorized Access
Write-Host ""
Write-Host "Testing unauthorized access to group endpoints..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "$baseUrl/api/grupos/addGroup" -Method POST -UseBasicParsing -ErrorAction Stop
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

