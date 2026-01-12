# Authentication Helper Functions
# Provides shared authentication utilities for test scripts

$global:TestAuthToken = $null
$global:TestUserId = $null
$global:TestUserEmail = $null

function Get-TestAuthToken {
    param(
        [string]$BaseUrl = "http://localhost:3001",
        [string]$Email = $null,
        [string]$Password = $null,
        [switch]$ForceRefresh
    )
    
    # If force refresh, clear cache
    if ($ForceRefresh) {
        $global:TestAuthToken = $null
        $global:TestUserId = $null
        $global:TestUserEmail = $null
    }
    
    # Return cached token if available and validate it
    if ($global:TestAuthToken -and -not $ForceRefresh) {
        # Validate token by making a test API call
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "x-token" = $global:TestAuthToken
            }
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                return $global:TestAuthToken
            }
        } catch {
            # Token is invalid, clear it and get a new one
            $global:TestAuthToken = $null
            $global:TestUserId = $null
        }
    }
    
    # Try to get from environment variable
    if ($env:TEST_AUTH_TOKEN -and -not $ForceRefresh) {
        $global:TestAuthToken = $env:TEST_AUTH_TOKEN
        # Validate it
        try {
            $headers = @{
                "Content-Type" = "application/json"
                "x-token" = $global:TestAuthToken
            }
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                return $global:TestAuthToken
            }
        } catch {
            $global:TestAuthToken = $null
        }
    }
    
    # Try to read from file and validate
    $tokenFile = "$PSScriptRoot/../../.test-auth-token"
    if ((Test-Path $tokenFile) -and (-not $ForceRefresh)) {
        $cachedToken = Get-Content $tokenFile -Raw | ForEach-Object { $_.Trim() }
        if ($cachedToken) {
            # Validate token
            try {
                $headers = @{
                    "Content-Type" = "application/json"
                    "x-token" = $cachedToken
                }
                $response = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
                if ($response.StatusCode -eq 200) {
                    $global:TestAuthToken = $cachedToken
                    return $global:TestAuthToken
                }
            } catch {
                # Token invalid, will create new one below
            }
        }
    }
    
    # Create test user and login
    if (-not $Email) {
        $Email = "test$(Get-Random)@test.com"
    }
    if (-not $Password) {
        $Password = "TestPassword123!"
    }
    
    try {
        # Try to register first
        $registerBody = @{
            nombre = "Test User"
            email = $Email
            password = $Password
        } | ConvertTo-Json

        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/login/new" -Method POST -Body $registerBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
            if ($response.StatusCode -eq 200) {
                $result = $response.Content | ConvertFrom-Json
                if ($result.ok -and ($result.token -or $result.accessToken)) {
                    $global:TestAuthToken = $result.token
                    if (-not $global:TestAuthToken) {
                        $global:TestAuthToken = $result.accessToken
                    }
                    $global:TestUserEmail = $Email
                    if ($result.usuario -and $result.usuario.uid) {
                        $global:TestUserId = $result.usuario.uid
                    }
                    # Save to file
                    $global:TestAuthToken | Out-File $tokenFile -Encoding UTF8 -NoNewline
                    return $global:TestAuthToken
                }
            }
        } catch {
            # User may already exist, try to login
        }
        
        # Try to login
        $loginBody = @{
            email = $Email
            password = $Password
        } | ConvertTo-Json

        $response = Invoke-WebRequest -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $result = $response.Content | ConvertFrom-Json
            if ($result.ok -and ($result.token -or $result.accessToken)) {
                $global:TestAuthToken = $result.token
                if (-not $global:TestAuthToken) {
                    $global:TestAuthToken = $result.accessToken
                }
                $global:TestUserEmail = $Email
                if ($result.usuario -and $result.usuario.uid) {
                    $global:TestUserId = $result.usuario.uid
                }
                # Save to file
                $global:TestAuthToken | Out-File $tokenFile -Encoding UTF8 -NoNewline
                return $global:TestAuthToken
            }
        }
    } catch {
        Write-Warning "Failed to get auth token: $($_.Exception.Message)"
        # Clear invalid token
        $global:TestAuthToken = $null
        $global:TestUserId = $null
        $global:TestUserEmail = $null
        return $null
    }
    
    return $null
}

function Test-TestAuthToken {
    param(
        [string]$BaseUrl = "http://localhost:3001",
        [string]$Token = $null
    )
    
    if (-not $Token) {
        $Token = $global:TestAuthToken
    }
    
    if (-not $Token) {
        return $false
    }
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "x-token" = $Token
        }
        $response = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Get-TestAuthHeaders {
    param(
        [string]$BaseUrl = "http://localhost:3001"
    )
    
    $token = Get-TestAuthToken -BaseUrl $BaseUrl
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    if ($token) {
        $headers["x-token"] = $token
    }
    
    return $headers
}

function Get-TestUserId {
    param(
        [string]$BaseUrl = "http://localhost:3001"
    )
    
    if ($global:TestUserId) {
        return $global:TestUserId
    }
    
    # Try to get user ID from token or API
    $headers = Get-TestAuthHeaders -BaseUrl $BaseUrl
    if ($headers["x-token"]) {
        try {
            $response = Invoke-WebRequest -Uri "$BaseUrl/api/usuarios" -Method GET -Headers $headers -UseBasicParsing -ErrorAction Stop -TimeoutSec 10
            if ($response.StatusCode -eq 200) {
                $result = $response.Content | ConvertFrom-Json
                # Try to extract user ID from response
                # The response might be an array of users or a single user object
                if ($result.usuarios -and $result.usuarios.Count -gt 0) {
                    # If it's an array, get the first user's ID
                    $firstUser = $result.usuarios[0]
                    if ($firstUser._id) {
                        $global:TestUserId = $firstUser._id
                    } elseif ($firstUser.uid) {
                        $global:TestUserId = $firstUser.uid
                    }
                } elseif ($result.usuario) {
                    # If it's a single user object (could be array or single)
                    if ($result.usuario -is [Array] -and $result.usuario.Count -gt 0) {
                        if ($result.usuario[0]._id) {
                            $global:TestUserId = $result.usuario[0]._id
                        } elseif ($result.usuario[0].uid) {
                            $global:TestUserId = $result.usuario[0].uid
                        }
                    } else {
                        if ($result.usuario._id) {
                            $global:TestUserId = $result.usuario._id
                        } elseif ($result.usuario.uid) {
                            $global:TestUserId = $result.usuario.uid
                        }
                    }
                } elseif ($result._id) {
                    # If it's directly a user object
                    $global:TestUserId = $result._id
                } elseif ($result.uid) {
                    $global:TestUserId = $result.uid
                }
            }
        } catch {
            # Ignore errors - user ID might not be available
        }
    }
    
    return $global:TestUserId
}

function Clear-TestAuthToken {
    $global:TestAuthToken = $null
    $global:TestUserId = $null
    $global:TestUserEmail = $null
    $tokenFile = "$PSScriptRoot/../../.test-auth-token"
    if (Test-Path $tokenFile) {
        Remove-Item $tokenFile -ErrorAction SilentlyContinue
    }
    Remove-Item Env:TEST_AUTH_TOKEN -ErrorAction SilentlyContinue
}

# Functions are available when script is sourced with . "$PSScriptRoot/../utils/auth-helper.ps1"

