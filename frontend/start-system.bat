@echo off
echo Starting NullClaw Nexus System...
echo.

echo Checking if CORS Proxy is already running...
netstat -ano | findstr :3001 >nul
if %errorlevel% equ 0 (
    echo CORS Proxy is already running on port 3001
) else (
    echo 1. Starting CORS Proxy...
    start "CORS Proxy" powershell -NoExit -Command "Set-Location '%CD%'; node cors-proxy.cjs"
)

echo Checking if Gateway is already running...
netstat -ano | findstr :3000 >nul
if %errorlevel% equ 0 (
    echo Gateway is already running on port 3000
) else (
    echo 2. Starting Gateway Manager...
    start "Gateway Manager" powershell -NoExit -File "%~dp0start-gateway.ps1"
)

echo.
echo 3. Web Interface Options:
echo    a) Already running at: http://localhost:4180/
echo    b) Start new on port 4174: npm run preview -- --port 4174
echo    c) Start new on port 4175: npm run preview -- --port 4175
echo.

echo System status:
echo - CORS Proxy: http://127.0.0.1:3001/
echo - Gateway: http://127.0.0.1:3000/
echo - Web Interface: http://localhost:4180/
echo.
pause