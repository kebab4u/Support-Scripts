@echo off
setlocal

:: Finn mappen denne CMD-en ligger i
set "DIR=%~dp0"
set "PS1=%DIR%nettverksanalyse.ps1"

:: Sjekk admin
net session >nul 2>&1
if %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
  goto :eof
)

:: Be om admin (UAC) og kjør på nytt som admin
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c """"%~f0""""' -Verb RunAs"
exit /b
