@echo off
echo Deploying Service Time Sheet Templates to SharePoint...
echo (A browser sign-in window will open)
echo.
pwsh.exe -ExecutionPolicy Bypass -File "%~dp0Deploy Templates to SharePoint.ps1"
echo.
pause
