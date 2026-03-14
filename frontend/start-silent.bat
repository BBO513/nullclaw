@echo off
echo Starting Silent Pairing System...
echo.

echo 1. Checking if Node.js is installed...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo 2. Checking if CORS Proxy is running...
netstat -ano | findstr :3001 >nul
if %errorlevel% equ 0 (
    echo ✅ CORS Proxy is running
) else (
    echo ❌ CORS Proxy is not running
    echo Starting CORS Proxy...
    start "CORS Proxy" powershell -NoExit -Command "Set-Location '%CD%'; node cors-proxy.cjs"
    timeout /t 3 >nul
)

echo 3. Checking if Gateway is running...
netstat -ano | findstr :3000 >nul
if %errorlevel% equ 0 (
    echo ✅ Gateway is running
) else (
    echo ❌ Gateway is not running
    echo Please start gateway with: powershell -File start-gateway.ps1
    echo Or run start-system.bat first
    pause
    exit /b 1
)

echo 4. Starting Silent Pairing System...
echo    This will monitor the gateway and attempt auto-pairing
echo    Check the new window for pairing status
echo.

start "Silent Pair" powershell -NoExit -Command "Set-Location '%CD%'; node silent-pair.cjs"

echo.
echo Silent pairing system started!
echo - Web Interface: http://localhost:4180/
echo - Gateway: http://127.0.0.1:3000/
echo - CORS Proxy: http://127.0.0.1:3001/
echo.
echo Note: You still need to enter the pairing code in the web interface
echo       for the first time. Future restarts may auto-pair.
echo.
pause