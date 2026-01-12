# Zookeeper Coordination Service Test
# Tests coordination service functionality

. "$PSScriptRoot/../utils/test-helpers.ps1"
. "$PSScriptRoot/../utils/docker-helper.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Coordination Service Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Zookeeper is running
$zkStatus = Test-DockerService -ContainerName "locksy-zookeeper" -Port 2181
if (-not $zkStatus.Running) {
    Test-Failed "Zookeeper container not running"
    Write-Host "Zookeeper is not running. Please start it first." -ForegroundColor Red
    exit 1
}

Test-Passed "Zookeeper container running" "Port 2181"

# Test Zookeeper connection (using four-letter commands)
try {
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    $tcpClient.Connect("localhost", 2181)
    $stream = $tcpClient.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $reader = New-Object System.IO.StreamReader($stream)
    
    # Send 'ruok' command (Are you OK?)
    $writer.WriteLine("ruok")
    $writer.Flush()
    Start-Sleep -Milliseconds 100
    $response = $reader.ReadLine()
    
    $stream.Close()
    $tcpClient.Close()
    
    if ($response -eq "imok") {
        Test-Passed "Zookeeper connection" "Zookeeper is responding"
    } else {
        Test-Warning "Zookeeper connection" "Unexpected response: $response"
    }
} catch {
    Test-Warning "Zookeeper connection" "Cannot test connection: $($_.Exception.Message)"
}

# Test coordination service exists
if (Test-Path "services/coordination") {
    Test-Passed "Coordination service directory exists" "services/coordination"
} else {
    Test-Failed "Coordination service directory missing" "services/coordination"
}

# Test coordination components
$coordinationComponents = @(
    "services/coordination/zookeeperClient.js",
    "services/coordination/distributedLock.js"
)

foreach ($component in $coordinationComponents) {
    if (Test-Path $component) {
        Test-Passed "Coordination component exists" $component
    } else {
        Test-Warning "Coordination component" "$component not found"
    }
}

# Test Zookeeper client connection (if available)
try {
    $testScript = @"
const zookeeper = require('node-zookeeper-client');
(async () => {
    try {
        const client = zookeeper.createClient('localhost:2181');
        
        await new Promise((resolve, reject) => {
            client.once('connected', () => {
                client.close();
                console.log('SUCCESS');
                resolve();
            });
            
            client.once('error', (err) => {
                client.close();
                reject(err);
            });
            
            client.connect();
            
            setTimeout(() => {
                client.close();
                reject(new Error('Timeout'));
            }, 5000);
        });
        
        process.exit(0);
    } catch (err) {
        console.error('ERROR:', err.message);
        process.exit(1);
    }
})();
"@
    
    $testScript | Out-File -FilePath "$env:TEMP/test-zookeeper.js" -Encoding UTF8
    $result = node "$env:TEMP/test-zookeeper.js" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Test-Passed "Zookeeper client connection" "Can connect via node-zookeeper-client"
    } else {
        Test-Warning "Zookeeper client connection" "Connection test failed or library not available"
    }
    Remove-Item "$env:TEMP/test-zookeeper.js" -ErrorAction SilentlyContinue
} catch {
    Test-Warning "Zookeeper client connection" "Cannot test connection (node-zookeeper-client may not be available)"
}

Write-TestSummary

exit $(if ($global:TestResults.Failed.Count -eq 0) { 0 } else { 1 })

