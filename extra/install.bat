@echo off
setlocal

:: Self-elevate to administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Move to project root (parent of extra/)
pushd "%~dp0.."
set "PROJECT_DIR=%CD%"

echo ============================================================
echo  Uptime Kuma (Windows Notification Edition) Installer
echo  Project: %PROJECT_DIR%
echo ============================================================
echo.

:: Check Node.js
where node >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found in PATH.
    echo Install Node.js 20.4.0 or later from: https://nodejs.org/
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
echo Detected Node.js: %NODE_VERSION%
echo.

:: Step 1/3 - install dependencies (uses package-lock.json)
echo [1/3] Installing dependencies (npm ci)...
call npm ci
if errorlevel 1 (
    echo [ERROR] npm ci failed.
    pause
    exit /b 1
)
echo.

:: Step 2/3 - build frontend
echo [2/3] Building frontend (npm run build)...
call npm run build
if errorlevel 1 (
    echo [ERROR] Build failed.
    pause
    exit /b 1
)
echo.

:: Step 3/3 - register Windows scheduled task to run on logon
echo [3/3] Registering Windows startup task...
schtasks /create /tn "UptimeKumaServer" /tr "powershell.exe -WindowStyle Hidden -Command \"Set-Location '%PROJECT_DIR%'; node server/server.js\"" /sc onlogon /f
if errorlevel 1 (
    echo [ERROR] Task registration failed.
    pause
    exit /b 1
)
echo.

echo ============================================================
echo  Installation complete.
echo    - Server starts automatically on next Windows logon.
echo    - Start now: schtasks /run /tn "UptimeKumaServer"
echo    - Open UI:   http://localhost:3001
echo ============================================================
pause
