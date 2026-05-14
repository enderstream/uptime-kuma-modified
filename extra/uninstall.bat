@echo off
setlocal

:: Self-elevate to administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Stopping Uptime Kuma server (if running)...
schtasks /end /tn "UptimeKumaServer" >nul 2>&1

echo Removing scheduled task...
schtasks /delete /tn "UptimeKumaServer" /f >nul 2>&1
if errorlevel 1 (
    echo [INFO] Task was not registered (nothing to remove).
) else (
    echo [OK] Task removed.
)

echo.
echo Done. Project files were left intact.
pause
