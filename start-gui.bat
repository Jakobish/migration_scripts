@echo off
REM IIS Migration Scripts GUI Launcher
REM Requires administrator privileges

echo =========================================
echo   IIS Migration Scripts - GUI Launcher
echo =========================================
echo.
echo Starting GUI with administrator privileges...
echo Note: You may be prompted for administrator access
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo Error: PowerShell is not available
    echo Please install PowerShell to run the GUI
    pause
    exit /b 1
)

REM Launch PowerShell with elevated privileges
powershell -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-NoExit', '-ExecutionPolicy Bypass', '-File \"%~dp0gui-migrate.ps1\"'"

echo GUI launched! Check for the PowerShell window that opened with administrator privileges.
echo.
pause