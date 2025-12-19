param(
  [string]$FolderName = "AutopilotHash",
  [string]$CollectionName = "HWhash_Collection.csv",
  [ValidateSet("Prompt","New","Collection","Latest")]
  [string]$Mode = "Prompt"
)

$ErrorActionPreference = "Stop"

# Finn roten på disken scriptet kjører fra (typisk USB)
$usbRoot = (Split-Path -Path $PSCommandPath -Qualifier)  # f.eks. "D:\"
if (-not $usbRoot) { throw "Kunne ikke finne hvilken disk skriptet kjører fra. Kjør scriptet som fil (.ps1)." }

# Lag mappe i root på USB: \AutopilotHash\
$outDir = Join-Path $usbRoot $FolderName
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function New-HWhashCsvPath([string]$dir) {
  $date = Get-Date -Format "ddMMyyyy"
  $base = "HWhash_{0}" -f $date
  $path = Join-Path $dir ($base + ".csv")

  # Hvis filen allerede finnes (flere kjøringer samme dag), lag HWhash_DDMMYYYY_2.csv osv.
  $i = 2
  while (Test-Path -LiteralPath $path) {
    $path = Join-Path $dir ("{0}_{1}.csv" -f $base, $i)
    $i++
  }
  return $path
}

# --- Velg modus (hvis Prompt) ---
if ($Mode -eq "Prompt") {
  Write-Host ""
  Write-Host "Velg hvordan CSV skal lagres:" -ForegroundColor Cyan
  Write-Host "  1 = New        (lag ny CSV: HWhash_DDMMYYYY.csv)"
  Write-Host "  2 = Collection (append til fast fil: $CollectionName)"
  Write-Host "  3 = Latest     (append til nyeste HWhash_*.csv - ignorerer Collection)"
  $choice = (Read-Host "Valg [1/2/3]").Trim()

  switch ($choice) {
    "1" { $Mode = "New" }
    "2" { $Mode = "Collection" }
    "3" { $Mode = "Latest" }
    default { throw "Ugyldig valg. Bruk 1, 2 eller 3." }
  }
}

# --- Bestem outputfil + om vi skal bruke -Append ---
$appendSwitch = $false
$outFile = $null

switch ($Mode) {
  "New" {
    $outFile = New-HWhashCsvPath -dir $outDir
    $appendSwitch = $false
  }
  "Collection" {
    $outFile = Join-Path $outDir $CollectionName
    $appendSwitch = $true
  }
  "Latest" {
    $latest = Get-ChildItem -Path $outDir -Filter "HWhash_*.csv" -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne $CollectionName } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1

    if ($latest) {
      $outFile = $latest.FullName
      $appendSwitch = $true
    } else {
      $outFile = New-HWhashCsvPath -dir $outDir
      $appendSwitch = $false
    }
  }
  default { throw "Ugyldig Mode: $Mode" }
}

Write-Host ""
Write-Host "USB root:   $usbRoot" -ForegroundColor Yellow
Write-Host "Output dir: $outDir"  -ForegroundColor Yellow
Write-Host "Output CSV: $outFile" -ForegroundColor Yellow
Write-Host "Append:     $appendSwitch" -ForegroundColor Yellow
Write-Host ""

# TLS 1.2 for PSGallery
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# Unngå PSGallery prompt hvis mulig
try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted } catch {}

# NuGet provider (trengs ofte for Install-Script)
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# Installer Get-WindowsAutoPilotInfo (online)
try {
  Install-Script -Name Get-WindowsAutoPilotInfo -Force -Scope AllUsers
} catch {
  Install-Script -Name Get-WindowsAutoPilotInfo -Force -Scope CurrentUser
}

# Finn script-sti robust
function Find-AutopilotScriptPath {
  $candidates = @(
    "C:\Program Files\WindowsPowerShell\Scripts\Get-WindowsAutoPilotInfo.ps1",
    (Join-Path $HOME "Documents\WindowsPowerShell\Scripts\Get-WindowsAutoPilotInfo.ps1"),
    (Join-Path $HOME "Documents\PowerShell\Scripts\Get-WindowsAutoPilotInfo.ps1")
  ) | Where-Object { Test-Path $_ }

  if ($candidates.Count -gt 0) {
    return ($candidates | Sort-Object { (Get-Item $_).LastWriteTime } -Descending | Select-Object -First 1)
  }

  $installed = @(Get-InstalledScript -Name Get-WindowsAutoPilotInfo -ErrorAction SilentlyContinue)
  if ($installed.Count -gt 0) {
    $pick = $installed | Sort-Object InstalledDate -Descending | Select-Object -First 1
    $p = Join-Path $pick.InstalledLocation "Get-WindowsAutoPilotInfo.ps1"
    if (Test-Path $p) { return $p }
  }

  return $null
}

$scriptPath = Find-AutopilotScriptPath
if (-not $scriptPath) { throw "Fant ikke Get-WindowsAutoPilotInfo.ps1 etter installasjon." }

Write-Host "Kjorer: $scriptPath" -ForegroundColor Cyan

# Kjør eksport
if ($appendSwitch) {
  & $scriptPath -OutputFile $outFile -Append
} else {
  & $scriptPath -OutputFile $outFile
}

# Verifiser at filen ble laget
if (-not (Test-Path -LiteralPath $outFile)) {
  throw "Fullfort, men fant ikke outputfilen: $outFile"
}

Write-Host ""
Write-Host "Ferdig!" -ForegroundColor Green
Write-Host "Modus: $Mode"
Write-Host "Lagret til: $outFile"
