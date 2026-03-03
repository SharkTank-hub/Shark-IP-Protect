@echo off
setlocal enabledelayedexpansion

:: ==============================
:: WELCOME MESSAGE
:: ==============================
echo =========================================================
echo Welcome to Shark's Windows Server Hardening / IP Protect
echo =========================================================
echo This script helps you:
echo 1. Harden your Windows Server baseline (disable SMBv1, print spooler, RDP rules, firewall logging, etc.)
echo 2. Run Shark IP Protect to monitor, detect, and block malicious IPs in real-time
echo.
echo You will be guided through options for resetting environments, auditing, or applying changes.
echo =========================================================
echo.

:: ==============================
:: Check for admin rights
:: ==============================
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo This script requires Administrator privileges. Restarting...
    powershell -Command "Start-Process cmd -Argument '/c \"%~s0\"' -Verb RunAs"
    exit /b
)

:: ==============================
:: Change directory to script location
:: ==============================
cd /d "%~dp0"

:: ==============================
:: Reset / Clean Option
:: ==============================
set "CONTINUE_CHOICE=N"
:RESET_ASK
set /p RESET_CHOICE=Do you want to reset Python packages and PowerShell environment? (Y/N): 
if /I "!RESET_CHOICE!"=="Y" (
    echo.
    echo Cleaning Python packages...
    python -m pip uninstall -y win10toast pypiwin32 pywin32 setuptools pip comtypes pywin32-ctypes colorama requests urllib3 certifi twisted tqdm pycryptodome cryptography >nul 2>&1

    echo Cleaning script folders...
    if exist ".\logs" rmdir /s /q ".\logs"
    if exist ".\cache" rmdir /s /q ".\cache"
    if exist ".\results" rmdir /s /q ".\results"
    echo Cleanup complete.
    echo.

    :: Jump to fresh install question
    goto ASK_CONTINUE
) else if /I "!RESET_CHOICE!"=="N" (
    goto AFTER_RESET
) else (
    echo Please enter Y or N.
    goto RESET_ASK
)

:ASK_CONTINUE
set /p CONTINUE_CHOICE=Do you want to continue with a fresh install of Python packages? (Y/N): 
if /I "!CONTINUE_CHOICE!"=="Y" (
    echo Proceeding with fresh install...
) else if /I "!CONTINUE_CHOICE!"=="N" (
    echo Exiting script as requested.
    pause
    exit /b
) else (
    echo Please enter Y or N.
    goto ASK_CONTINUE
)

:AFTER_RESET

:: ==============================
:: Ensure folders exist before running scripts
:: ==============================
for %%F in (logs cache results) do (
    if not exist ".\%%F" mkdir ".\%%F"
)

:: ==============================
:: Check PowerShell version
:: ==============================
echo.
echo Checking PowerShell version...
powershell -NoProfile -Command "$v=$PSVersionTable.PSVersion.Major; Write-Output $v" > temp.txt
set /p PSVersion=<temp.txt
del temp.txt

if %PSVersion% LSS 5 (
    echo.
    echo WARNING: PowerShell version %PSVersion% detected.
    echo PowerShell 5.0 or higher is required.
    start https://aka.ms/powershell
    pause
) else (
    echo PowerShell version %PSVersion% is supported.
)

:: ==============================
:: Check Python installation
:: ==============================
echo.
echo Checking Python installation...
python --version >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo WARNING: Python is not installed.
    start https://www.python.org/downloads/
    pause
) else (
    echo Python is already installed.
)

:: ==============================
:: Fresh install of Python packages if chosen
:: ==============================
if /I "!CONTINUE_CHOICE!"=="Y" (
    echo Installing required Python packages...
    set PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python313\Scripts
    set PATH=%PATH%;C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Scripts
    python -m ensurepip --upgrade
    python -m pip install --upgrade pip setuptools requests tqdm --break-system-packages
)

:: ==============================
:: Run PowerShell script
:: ==============================
echo.
echo Running Windows Server Baseline PowerShell script...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { .\WinServer22_Hardening.ps1; if ($?) {exit 0} else {exit 1} }"
if %errorLevel% NEQ 0 (
    echo.
    echo PowerShell script failed with exit code %errorLevel%.
    pause
    exit /b
)

:: ==============================
:: Run Python script
:: ==============================
echo.
echo Running Shark IP Protect Python script...
set PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python313\Scripts
set PATH=%PATH%;C:\Users\Administrator\AppData\Local\Programs\Python\Python313\Scripts

python Shark_IP_Protect.py
if %errorLevel% NEQ 0 (
    echo.
    echo Python script failed with exit code %errorLevel%.
    pause
)

echo.
echo All tasks finished. Review logs and results for details.
pause