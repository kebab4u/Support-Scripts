@echo off
setlocal EnableExtensions

set "DIR=%~dp0"
set "PS1=%DIR%hent-hwhash.ps1"

if not exist "%PS1%" (
  echo Fant ikke: %PS1%
  echo Sjekk at hent-hwhash.ps1 ligger i samme mappe som RUN.cmd
  echo.
  pause
  exit /b 1
)

:: Sjekk admin
net session >nul 2>&1
if %errorlevel%==0 goto :RUN

echo Ber om Administrator-rettigheter...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath 'cmd.exe' -ArgumentList '/c """"%~f0""""' -Verb RunAs"
exit /b

:RUN
:: Bruk PowerShell 7 hvis tilgjengelig, ellers Windows PowerShell
where pwsh >nul 2>&1
if %errorlevel%==0 (
  set "ENGINE=pwsh"
) else (
  set "ENGINE=powershell.exe"
)

echo Kjører %PS1% med %ENGINE% ...
echo.

%ENGINE% -NoProfile -ExecutionPolicy Bypass -File "%PS1%"

echo.
pause
endlocal

