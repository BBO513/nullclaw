@echo off
title NullClaw Nexus
color 0B
cls

echo.
echo  ███╗   ██╗██╗   ██╗██╗     ██╗      ██████╗██╗      █████╗ ██╗    ██╗
echo  ████╗  ██║██║   ██║██║     ██║     ██╔════╝██║     ██╔══██╗██║    ██║
echo  ██╔██╗ ██║██║   ██║██║     ██║     ██║     ██║     ███████║██║ █╗ ██║
echo  ██║╚██╗██║██║   ██║██║     ██║     ██║     ██║     ██╔══██║██║███╗██║
echo  ██║ ╚████║╚██████╔╝███████╗███████╗╚██████╗███████╗██║  ██║╚███╔███╔╝
echo  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝╚══════╝╚═╝  ╚═╝ ╚══╝╚══╝ 
echo.
echo  ═══════════════════════════════════════════════════════════════════════
echo   NullClaw Nexus - Ultra-Lightweight AI Agent Control Center
echo  ═══════════════════════════════════════════════════════════════════════
echo.

REM Check if NullClaw binary exists
set NULLCLAW_PATH=nullclaw.exe
if not exist "%NULLCLAW_PATH%" (
    set NULLCLAW_PATH=..\nullclaw\zig-out\bin\nullclaw.exe
)
if not exist "%NULLCLAW_PATH%" (
    set NULLCLAW_PATH=bin\nullclaw.exe
)

if exist "%NULLCLAW_PATH%" (
    echo  [✓] NullClaw binary found
    echo  [1/2] Starting NullClaw Gateway...
    echo.
    start "NullClaw Gateway" /MIN cmd /k "%NULLCLAW_PATH% gateway --bind 127.0.0.1:3000"
    timeout /t 3 /nobreak >nul
    echo  [✓] Gateway running on http://127.0.0.1:3000
    echo.
) else (
    echo  [!] NullClaw binary not found!
    echo  [!] Place nullclaw.exe in the same folder as this script
    echo.
    echo  Press any key to continue with UI only...
    pause >nul
)

echo  [2/2] Starting Web UI...
echo.
start "NullClaw Nexus UI" cmd /k "npm run dev -- --open"

timeout /t 2 /nobreak >nul

echo.
echo  ═══════════════════════════════════════════════════════════════════════
echo   ✓ NullClaw Nexus is starting!
echo  ═══════════════════════════════════════════════════════════════════════
echo.
echo   Your browser will open automatically to: http://localhost:5173
echo.
echo   Gateway API: http://127.0.0.1:3000
echo   Web UI:      http://localhost:5173
echo.
echo   To stop: Close this window or press Ctrl+C
echo  ═══════════════════════════════════════════════════════════════════════
echo.

REM Keep this window open
pause
