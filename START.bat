@echo off
setlocal
cd /d "%~dp0"
title Voice Room

set "PYTHON_CMD="

where py >nul 2>&1
if not errorlevel 1 (
    py -3.10 --version >nul 2>&1
    if not errorlevel 1 set "PYTHON_CMD=py -3.10"
)

if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 (
        python --version 2>&1 | findstr /b /c:"Python 3.10." >nul
        if not errorlevel 1 set "PYTHON_CMD=python"
    )
)

if not defined PYTHON_CMD if exist "%LocalAppData%\Programs\Python\Python310\python.exe" set "PYTHON_CMD=%LocalAppData%\Programs\Python\Python310\python.exe"
if not defined PYTHON_CMD if exist "%ProgramFiles%\Python310\python.exe" set "PYTHON_CMD=%ProgramFiles%\Python310\python.exe"
if not defined PYTHON_CMD if exist "%ProgramFiles(x86)%\Python310\python.exe" set "PYTHON_CMD=%ProgramFiles(x86)%\Python310\python.exe"

if not defined PYTHON_CMD (
    echo ERROR: Python 3.10 was not found.
    pause
    exit /b 1
)

echo Using:
%PYTHON_CMD% --version
echo.

echo [1/3] Checking pip...
%PYTHON_CMD% -m pip --version
if errorlevel 1 (
    echo ERROR: pip is unavailable for this Python installation.
    pause
    exit /b 1
)

echo.
echo [2/3] Installing Flask and Socket.IO packages.
echo This step needs an internet connection and may take a minute.
%PYTHON_CMD% -m pip install --disable-pip-version-check --no-input --retries 3 --timeout 30 -v -r requirements.txt
if errorlevel 1 (
    echo.
    echo ERROR: Package installation failed.
    echo Check your internet connection, then run START.bat again.
    pause
    exit /b 1
)

echo.
echo [3/3] Starting Voice Room server...
start "Voice Room Server" /min cmd /c "cd /d ""%~dp0"" && %PYTHON_CMD% app.py"
timeout /t 3 /nobreak >nul

set "CF=%~dp0cloudflared.exe"
if not exist "%CF%" (
    echo Downloading Cloudflare Tunnel...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile '%CF%' -UseBasicParsing } catch { exit 1 }"
)
if not exist "%CF%" (
    echo ERROR: cloudflared download failed. Check your internet connection.
    pause
    exit /b 1
)

echo.
echo Wait for the HTTPS URL ending in trycloudflare.com.
echo Send that URL to your friend. Keep this window open during the call.
echo.
"%CF%" tunnel --url http://localhost:5000
pause
