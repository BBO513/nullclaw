# NullClaw Nexus Development Server Startup Script
Write-Host "Starting NullClaw Nexus..." -ForegroundColor Cyan

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Start the development server
npm run dev -- --open
