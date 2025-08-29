@echo off
chcp 65001 >nul
title Script Runner - By Ahmed
cd /d "%~dp0"

:MENU
cls
echo ================================
echo        🛠️ Script Launcher
echo ================================
echo [1] Change Device ID
echo [2] Reset Cursor
echo [3] Reset Windsurf
echo [0] Exit
echo.

set /p choice=Enter your choice: 

if "%choice%"=="1" (
    powershell -ExecutionPolicy Bypass -File "change_device_id.ps1"
    pause
    goto MENU
)
if "%choice%"=="2" (
    powershell -ExecutionPolicy Bypass -File "reset_cursor_windows-v0.1.ps1"
    pause
    goto MENU
)
if "%choice%"=="3" (
    powershell -ExecutionPolicy Bypass -File "reset_windsurf_windows-v0.1.ps1"
    pause
    goto MENU
)
if "%choice%"=="0" (
    echo See you later, Ahmed 👋
    timeout /t 1 >nul
    exit
)

echo Invalid choice. Please try again.
pause
goto MENU
