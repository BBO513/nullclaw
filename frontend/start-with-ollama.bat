@echo off
echo ========================================
echo  NullClaw Nexus - With Ollama
echo ========================================
echo.

REM Check if Ollama is installed
where ollama >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [1/3] Starting Ollama...
    start "Ollama" cmd /k "ollama serve"
    timeout /t 2 /nobreak >nul
    echo     Ollama started on http://localhost:11434
    echo.
) else (
    echo [!] Ollama not found. Install from: https://ollama.com
    echo.
)

REM Check if NullClaw binary exists
set NULLCLAW_PATH=..\nullclaw\zig-out\bin\nullclaw.exe

if exist "%NULLCLAW_PATH%" (
    echo [2/3] Starting NullClaw Gateway...
    start "NullClaw Gateway" cmd /k "%NULLCLAW_PATH% gateway --bind 127.0.0.1:3000"
    timeout /t 2 /nobreak >nul
    echo     Gateway started on http://127.0.0.1:3000
    echo.
) else (
    echo [!] NullClaw binary not found
    echo.
)

echo [3/3] Starting NullClaw Nexus UI...
npm run dev -- --open

echo.
echo ========================================
echo  All services started!
echo  Press Ctrl+C to stop
echo ========================================
