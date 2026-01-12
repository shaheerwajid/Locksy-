# Quick Endpoint Test
$BaseUrl = "http://localhost:3000"
$TestEmail = "testuser@example.com"
$TestPassword = "Test123456!"

Write-Host "=== Quick Endpoint Test ===" -ForegroundColor Yellow
Write-Host ""

# Login
Write-Host "1. Login..." -ForegroundColor Cyan
try {
    $loginBody = @{
        email = $TestEmail
        password = $TestPassword
    } | ConvertTo-Json
    
    $loginResponse = Invoke-RestMethod -Uri "$BaseUrl/api/login" -Method POST -Body $loginBody -ContentType "application/json"
    $token = $loginResponse.accessToken
    $userId = $loginResponse.usuario.uid
    Write-Host "   ✅ Login successful" -ForegroundColor Green
    Write-Host "   User ID: $userId" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$headers = @{
    "x-token" = $token
    "Content-Type" = "application/json"
}

Write-Host ""

# Test endpoints
$tests = @(
    @{Name="Get User"; Method="POST"; Path="/api/usuarios/getUsuario"; Body=@{uid=$userId}},
    @{Name="Get User List"; Method="GET"; Path="/api/usuarios"; Body=$null},
    @{Name="Update User"; Method="POST"; Path="/api/usuarios/updateUsuario"; Body=@{uid=$userId; nombre="Test User Updated"}},
    @{Name="Get Contactos"; Method="POST"; Path="/api/contactos/getContactos"; Body=@{}},
    @{Name="Get Listado Contactos"; Method="POST"; Path="/api/contactos/getListadoContactos"; Body=@{}},
    @{Name="Get Groups"; Method="POST"; Path="/api/grupos/groupsByMember"; Body=@{uid=$userId}},
    @{Name="Get Messages"; Method="POST"; Path="/api/mensajes"; Body=@{de=$userId; para=$userId}}
)

$passed = 0
$failed = 0

foreach ($test in $tests) {
    Write-Host "$($tests.IndexOf($test) + 2). $($test.Name)..." -ForegroundColor Cyan
    try {
        $params = @{
            Uri = "$BaseUrl$($test.Path)"
            Method = $test.Method
            Headers = $headers
            TimeoutSec = 10
            ErrorAction = "Stop"
        }
        
        if ($test.Body) {
            $params.Body = ($test.Body | ConvertTo-Json)
        }
        
        $result = Invoke-RestMethod @params
        Write-Host "   ✅ Works" -ForegroundColor Green
        $passed++
    } catch {
        $errorMsg = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseBody = $reader.ReadToEnd()
                if ($responseBody) {
                    $errorMsg = $responseBody
                }
            } catch {}
        }
        Write-Host "   ❌ Failed: $errorMsg" -ForegroundColor Red
        $failed++
    }
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Yellow
Write-Host "✅ Passed: $passed" -ForegroundColor Green
Write-Host "❌ Failed: $failed" -ForegroundColor Red
Write-Host "Success Rate: $([math]::Round(($passed / ($passed + $failed)) * 100, 1))%" -ForegroundColor $(if (($passed / ($passed + $failed)) -ge 0.7) { "Green" } else { "Yellow" })


