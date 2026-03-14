@echo off
REM NullClaw Nexus - One-Click Launcher
REM This is the main launcher for the packaged app

title NullClaw Nexus

REM Start NullClaw Gateway (minimized)
if exist "nullclaw.exe" (
    start "" /MIN nullclaw.exe gateway --bind 127.0.0.1:3000
    timeout /t 2 /nobreak >nul
)

REM Start Web UI and open browser
npm run dev -- --open

REM If npm fails, try alternative
if errorlevel 1 (
    node node_modules\vite\bin\vite.js --open
)
