@echo off
REM Komodo Periphery Home Assistant Add-on Installation Script (Batch)
REM Simple wrapper for Windows users
REM Usage: install.bat [dev|production]

setlocal EnableDelayedExpansion

echo.
echo ==============================================
echo   Komodo Periphery HA Add-on Installer
echo ==============================================
echo.

REM Check for command line arguments
set MODE=dev
if "%1"=="production" set MODE=production
if "%1"=="prod" set MODE=production
if "%1"=="help" goto :show_help
if "%1"=="/?" goto :show_help
if "%1"=="-h" goto :show_help

echo [INFO] Installation mode: %MODE%
echo.

REM Check if Python is available
python --version >nul 2>&1
if !errorlevel! == 0 (
    echo [INFO] Python found, using Python installer...
    if "%MODE%"=="dev" (
        python install.py --dev
    ) else (
        python install.py --production
    )
    goto :end
)

REM Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell test'" >nul 2>&1
if !errorlevel! == 0 (
    echo [INFO] PowerShell found, using PowerShell installer...
    if "%MODE%"=="dev" (
        powershell -ExecutionPolicy Bypass -File install.ps1 -Dev
    ) else (
        powershell -ExecutionPolicy Bypass -File install.ps1 -Production
    )
    goto :end
)

REM Check if Git Bash is available
where bash >nul 2>&1
if !errorlevel! == 0 (
    echo [INFO] Git Bash found, using Bash installer...
    if "%MODE%"=="dev" (
        bash install.sh --dev
    ) else (
        bash install.sh --production
    )
    goto :end
)

REM No suitable installer found
echo [ERROR] No suitable installer found!
echo.
echo Please install one of the following:
echo   1. Python 3.7+ (recommended)
echo   2. PowerShell 5.1+
echo   3. Git for Windows (includes Git Bash)
echo.
echo Download links:
echo   Python: https://python.org/downloads/
echo   Git: https://git-scm.com/download/win
echo   PowerShell: https://docs.microsoft.com/powershell/scripting/install/installing-powershell
echo.
pause
exit /b 1

:show_help
echo Usage: install.bat [dev^|production^|help]
echo.
echo Options:
echo   dev         Set up development environment (default)
echo   production  Set up production deployment files
echo   help        Show this help message
echo.
echo Examples:
echo   install.bat
echo   install.bat dev
echo   install.bat production
echo.
echo This script will automatically detect and use the best available installer:
echo   1. Python installer (install.py) - recommended
echo   2. PowerShell installer (install.ps1)
echo   3. Bash installer (install.sh) via Git Bash
echo.
pause
exit /b 0

:end
echo.
if !errorlevel! == 0 (
    echo [INFO] Installation completed successfully!
) else (
    echo [ERROR] Installation failed with error code !errorlevel!
)
echo.
pause