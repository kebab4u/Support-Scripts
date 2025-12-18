# nettverkanalyse.ps1
# Lagrer én mappe per kjøring i: <USB>:\NettverksAnalyser\<PC>_<USER>_<timestamp>\
# Lager i tillegg: Short_Summary.txt (rask oversikt)
# Ingen zip.

$ErrorActionPreference = "Stop"

function Sanitize-FileName([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return "Unknown" }
  $invalid = [IO.Path]::GetInvalidFileNameChars()
  foreach ($c in $invalid) { $s = $s.Replace($c, '_') }
  $s = $s.Trim().Trim('.')
  if ($s.Length -gt 60) { $s = $s.Substring(0,60) }
  if ([string]::IsNullOrWhiteSpace($s)) { return "Unknown" }
  return $s
}

function Write-Section([string]$file, [string]$title, [scriptblock]$sb) {
  "===== $title =====" | Out-File -FilePath $file -Encoding utf8 -Append
  try {
    & $sb | Out-String | Out-File -FilePath $file -Encoding utf8 -Append
  } catch {
    "ERROR: $($_.Exception.Message)" | Out-File -FilePath $file -Encoding utf8 -Append
  }
  "" | Out-File -FilePath $file -Encoding utf8 -Append
}

function Export-Events([string]$logName, [string]$outFile, [int]$max=200, [string]$reportFile="") {
  try {
    Get-WinEvent -LogName $logName -MaxEvents $max |
      Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
      Export-Csv -Path $outFile -NoTypeInformation -Encoding utf8
  } catch {
    if ($reportFile) {
      "Could not read ${logName}: $($_.Exception.Message)" | Out-File -FilePath $reportFile -Encoding utf8 -Append
    }
  }
}

function Get-ActiveNetConfig {
  $cfgs = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue)
  if (-not $cfgs -or $cfgs.Count -eq 0) { return $null }

  $preferred = $cfgs | Where-Object { $_.IPv4DefaultGateway -and $_.IPv4DefaultGateway.NextHop } | Select-Object -First 1
  if ($preferred) { return $preferred }

  $up = $cfgs | Where-Object { $_.NetAdapter.Status -eq "Up" } | Select-Object -First 1
  if ($up) { return $up }

  return $cfgs | Select-Object -First 1
}

function Try-Resolve([string]$name) {
  try {
    $r = Resolve-DnsName -Name $name -ErrorAction Stop | Where-Object { $_.IPAddress } | Select-Object -First 1
    if ($r) { return "OK ($($r.IPAddress))" }
    return "FAIL (no IP)"
  } catch {
    return "FAIL ($($_.Exception.Message))"
  }
}

function Try-Tcp443([string]$TargetHost) {
  try {
    $t = Test-NetConnection -ComputerName $TargetHost -Port 443 -WarningAction SilentlyContinue
    if ($t.TcpTestSucceeded) { return "OK" }
    return "FAIL"
  } catch {
    return "FAIL ($($_.Exception.Message))"
  }
}

function Try-Ping([string]$TargetHost) {
  if ([string]::IsNullOrWhiteSpace($TargetHost)) { return "SKIP" }
  try {
    $p = Test-Connection -ComputerName $TargetHost -Count 1 -Quiet -ErrorAction Stop
    return $(if ($p) { "OK" } else { "FAIL" })
  } catch {
    return "FAIL ($($_.Exception.Message))"
  }
}

try {
  $scriptPath = $PSCommandPath
  if (-not $scriptPath) { throw "PSCommandPath er tom. Kjør scriptet som fil." }

  $root = (Split-Path -Path $scriptPath -Qualifier)
  if (-not $root) { throw "Kunne ikke finne disk-root for scriptet." }

  $outRoot = Join-Path $root "NettverksAnalyser"
  New-Item -ItemType Directory -Path $outRoot -Force | Out-Null

  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $pc   = Sanitize-FileName $env:COMPUTERNAME
  $user = Sanitize-FileName $env:USERNAME
  $folderName = "{0}_{1}_{2}" -f $pc, $user, $stamp

  $outFolder = Join-Path $outRoot $folderName
  New-Item -ItemType Directory -Path $outFolder -Force | Out-Null

  $txt     = Join-Path $outFolder "NetDiag_Report.txt"
  $summary = Join-Path $outFolder "Short_Summary.txt"

  # SHORT SUMMARY
  $cfg = Get-ActiveNetConfig
  if (-not $cfg) { throw "Fant ingen nettverkskonfig (Get-NetIPConfiguration returnerte tomt)." }

  $adapterName = $cfg.InterfaceAlias
  $adapterStatus = $cfg.NetAdapter.Status

  $ipv4 = ($cfg.IPv4Address | Select-Object -First 1).IPv4Address
  $gateway = $cfg.IPv4DefaultGateway.NextHop
  $dnsList = @($cfg.DnsServer.ServerAddresses) -join ", "
  $dhcpEnabled = try { (Get-NetIPInterface -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4).Dhcp } catch { $null }

  $ipHealth =
    if ([string]::IsNullOrWhiteSpace($ipv4)) { "FAIL (no IPv4)" }
    elseif ($ipv4 -like "169.254.*") { "FAIL (APIPA 169.254.x.x)" }
    else { "OK ($ipv4)" }

  $gwHealth = if ([string]::IsNullOrWhiteSpace($gateway)) { "FAIL (no gateway)" } else { "OK ($gateway)" }

  $pingGw = Try-Ping $gateway

  $dnsMicrosoft = Try-Resolve "microsoft.com"
  $dnsLogin     = Try-Resolve "login.microsoftonline.com"
  $tcpLogin     = Try-Tcp443 "login.microsoftonline.com"

  $winhttpProxy = try { (netsh winhttp show proxy | Out-String).Trim() } catch { "N/A" }
  $ieProxy = try {
    $p = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop
    "ProxyEnable=$($p.ProxyEnable); ProxyServer=$($p.ProxyServer); AutoConfigURL=$($p.AutoConfigURL)"
  } catch { "N/A" }

  $wifiInfo = try { (netsh wlan show interfaces | Out-String) } catch { "" }
  $ssid = ""
  $signal = ""
  if ($wifiInfo) {
    $ssidLine = ($wifiInfo -split "`r?`n" | Where-Object { $_ -match "^\s*SSID\s*:" } | Select-Object -First 1)
    $sigLine  = ($wifiInfo -split "`r?`n" | Where-Object { $_ -match "^\s*Signal\s*:" } | Select-Object -First 1)
    if ($ssidLine) { $ssid = ($ssidLine -split ":\s*",2)[1].Trim() }
    if ($sigLine)  { $signal = ($sigLine  -split ":\s*",2)[1].Trim() }
  }

  @(
    "NetDiag Short Summary",
    "Time:      $(Get-Date -Format s)",
    "Computer:  $env:COMPUTERNAME",
    "User:      $env:USERNAME",
    "",
    "Adapter:   $adapterName (Status: $adapterStatus)",
    "IPv4:      $ipHealth",
    "Gateway:   $gwHealth (Ping: $pingGw)",
    "DHCP:      $dhcpEnabled",
    "DNS:       $dnsList",
    "",
    "DNS test microsoft.com:             $dnsMicrosoft",
    "DNS test login.microsoftonline.com: $dnsLogin",
    "TCP 443 login.microsoftonline.com:  $tcpLogin",
    "",
    "Wi-Fi SSID: $ssid",
    "Wi-Fi Signal: $signal",
    "",
    "WinHTTP proxy:",
    $winhttpProxy,
    "",
    "User proxy (HKCU Internet Settings):",
    $ieProxy,
    "",
    "Output folder: $outFolder"
  ) | Out-File -FilePath $summary -Encoding utf8

  # FULL REPORT
  "NetDiag collection started: $(Get-Date -Format s)" | Out-File -FilePath $txt -Encoding utf8
  "ScriptPath: $scriptPath" | Out-File -FilePath $txt -Encoding utf8 -Append
  "OutputFolder: $outFolder" | Out-File -FilePath $txt -Encoding utf8 -Append
  "" | Out-File -FilePath $txt -Encoding utf8 -Append

  Write-Host "Samler info... (lagrer i $outFolder)" -ForegroundColor Cyan

  Write-Section $txt "Systeminfo" { systeminfo }
  Write-Section $txt "Time/Timezone" { Get-Date; tzutil /g }

  Write-Section $txt "ipconfig /all" { ipconfig /all }
  Write-Section $txt "Routes (route print)" { route print }
  Write-Section $txt "Net adapters (Get-NetAdapter)" { Get-NetAdapter | Format-Table -AutoSize }
  Write-Section $txt "IP configuration (Get-NetIPConfiguration)" { Get-NetIPConfiguration | Format-List * }
  Write-Section $txt "DNS servers (Get-DnsClientServerAddress)" { Get-DnsClientServerAddress | Format-Table -AutoSize }
  Write-Section $txt "DNS cache (ipconfig /displaydns)" { ipconfig /displaydns }

  Write-Section $txt "WinHTTP proxy" { netsh winhttp show proxy }
  Write-Section $txt "Internet Settings proxy (HKCU)" {
    Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
      Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
  }

  Write-Section $txt "Wi-Fi interfaces" { netsh wlan show interfaces }
  Write-Section $txt "Wi-Fi profiles (names)" { netsh wlan show profiles }

  try { Get-NetIPConfiguration | ConvertTo-Json -Depth 5 | Out-File (Join-Path $outFolder "NetIPConfiguration.json") -Encoding utf8 } catch {}
  try { Get-NetAdapter | Export-Csv (Join-Path $outFolder "NetAdapter.csv") -NoTypeInformation -Encoding utf8 } catch {}

  Export-Events "System" (Join-Path $outFolder "Events_System.csv") 200 $txt
  Export-Events "Microsoft-Windows-DNS-Client/Operational" (Join-Path $outFolder "Events_DNSClient_Operational.csv") 200 $txt
  Export-Events "Microsoft-Windows-Dhcp-Client/Operational" (Join-Path $outFolder "Events_DHCPClient_Operational.csv") 200 $txt
  Export-Events "Microsoft-Windows-WLAN-AutoConfig/Operational" (Join-Path $outFolder "Events_WLAN_AutoConfig.csv") 200 $txt

  Write-Host "Ferdig!" -ForegroundColor Green
  Write-Host "Mappe:"; Write-Host $outFolder
  Write-Host "Kort oppsummering:"; Write-Host $summary

} catch {
  $fallback = Join-Path $env:PUBLIC ("NetDiag_ERROR_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  ("ERROR: " + $_.Exception.Message) | Out-File -FilePath $fallback -Encoding utf8
  "Full error:" | Out-File -FilePath $fallback -Encoding utf8 -Append
  $_ | Out-String | Out-File -FilePath $fallback -Encoding utf8 -Append

  Write-Host "Scriptet feilet. Feillogg skrevet til:" -ForegroundColor Red
  Write-Host $fallback
}

Read-Host "Trykk Enter for å lukke"
