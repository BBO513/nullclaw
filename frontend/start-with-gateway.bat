@echo off
echo ========================================
echo  NullClaw Nexus - Full Stack Startup
echo ========================================
echo.

REM Check if NullClaw binary exists
set NULLCLAW_PATH=..\nullclaw\zig-out\bin\nullclaw.exe

if exist "%NULLCLAW_PATH%" (
    echo [1/2] Starting NullClaw Gateway...
    start "NullClaw Gateway" cmd /k "%NULLCLAW_PATH% gateway --bind 127.0.0.1:3000"
    timeout /t 2 /nobreak >nul
    echo     Gateway started on http://127.0.0.1:3000
    echo.
) else (
    echo [!] NullClaw binary not found at: %NULLCLAW_PATH%
    echo [!] Only starting the UI...
    echo.
    echo To build NullClaw:
    echo   1. git clone https://github.com/nullclaw/nullclaw.git
    echo   2. cd nullclaw
    echo   3. zig build -Doptimize=ReleaseSmall
    echo.
)

echo [2/2] Starting NullClaw Nexus UI...
npm run dev -- --open

echo.
echo ========================================
echo  Press Ctrl+C to stop
echo ========================================
