@echo off
echo Installing Uptime Kuma Server...

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%.."

schtasks /create /tn "UptimeKumaServer" /tr "powershell.exe -WindowStyle Hidden -Command \"Set-Location '%PROJECT_DIR%'; node server/server.js\"" /sc onlogon /f

if %errorlevel% equ 0 (
    echo [OK] Uptime Kuma Server registered.
) else (
    echo [FAIL] Server registration failed. Try running as Administrator.
)

echo.
echo Done! Server will start automatically on next login.
pause
