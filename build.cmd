@echo off
setlocal
if "%~2"=="" (
  echo Usage: build.cmd "GAME_DIRECTORY" "SDK_DIRECTORY"
  exit /b 2
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0build.ps1" -GameDirectory "%~1" -SdkDirectory "%~2"
exit /b %ERRORLEVEL%
