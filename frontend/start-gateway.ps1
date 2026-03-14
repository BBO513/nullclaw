# PowerShell script to start NullClaw gateway with auto-restart
# Run this script to start the gateway and automatically restart if it crashes

$gatewayProcess = $null
$gatewayPath = "nullclaw-wsl"  # Path to your gateway executable
$wslPath = "wsl"  # WSL command
$wslCommand = "cd ~/nullclaw-wsl && ./zig-out/bin/nullclaw gateway --bind 127.0.0.1:3000"

Write-Host "Starting NullClaw Gateway Manager..." -ForegroundColor Green
Write-Host "Gateway will auto-restart on crash" -ForegroundColor Yellow

function Start-Gateway {
    Write-Host "Starting NullClaw Gateway..." -ForegroundColor Cyan
    $script:gatewayProcess = Start-Process -FilePath "wsl" -ArgumentList "-e", "bash", "-c", "cd ~/nullclaw-wsl && ./zig-out/bin/nullclaw gateway --bind 127.0.0.1:3000" -NoNewWindow -PassThru
    Write-Host "Gateway started with PID: $($gatewayProcess.Id)" -ForegroundColor Green
}

function Stop-Gateway {
    if ($gatewayProcess -and !$gatewayProcess.HasExited) {
        Write-Host "Stopping gateway..." -ForegroundColor Yellow
        Stop-Process -Id $gatewayProcess.Id -Force -ErrorAction SilentlyContinue
    }
}

# Handle script termination
$script:terminated = $false
$script:originalTitle = $host.ui.RawUI.WindowTitle
$host.UI.RawUI.WindowTitle = "NullClaw Gateway Manager"

# Set up Ctrl+C handler
[console]::TreatControlCAsInput = $false
$trap = {
    Write-Host "`nStopping gateway and cleaning up..." -ForegroundColor Yellow
    Stop-Gateway
    $host.UI.RawUI.WindowTitle = $script:originalTitle
    exit 0
}

# Register the trap
$null = Register-EngineEvent PowerShell.Exiting -Action $trap

# Main loop
while ($true) {
    try {
        Write-Host "Starting gateway..." -ForegroundColor Cyan
        Start-Gateway
        
        # Monitor the process
        while ($gatewayProcess -and !$gatewayProcess.HasExited) {
            Start-Sleep -Seconds 1
        }
        
        Write-Host "Gateway process ended. Restarting in 3 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 3
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Restarting in 5 seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}