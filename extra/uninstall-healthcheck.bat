@echo off
echo Removing Uptime Kuma Server...

schtasks /delete /tn "UptimeKumaServer" /f 2>nul
echo [OK] Server task removed.

echo.
echo Done!
pause
