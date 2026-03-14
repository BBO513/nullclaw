@echo off
REM NullClaw Nexus - Production Launcher
REM Uses the built static files (faster, no npm needed)

title NullClaw Nexus

echo Starting NullClaw Nexus...

REM Start NullClaw Gateway (minimized)
if exist "nullclaw.exe" (
    echo [1/2] Starting NullClaw Gateway...
    start "" /MIN nullclaw.exe gateway --bind 127.0.0.1:3000
    timeout /t 2 /nobreak >nul
    echo     Gateway started!
) else (
    echo [!] nullclaw.exe not found - UI only mode
)

REM Start a simple HTTP server for the built files
echo [2/2] Starting Web UI...

REM Try using Python (most common)
where python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    cd build
    start "" http://localhost:8080
    python -m http.server 8080
    goto :end
)

REM Try using Node.js http-server
where npx >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    start "" http://localhost:8080
    npx http-server build -p 8080 -o
    goto :end
)

REM Fallback: use npm run preview
echo Using development server...
npm run preview -- --open

:end
