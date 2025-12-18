Dette scriptet samler inn nettverksrelatert informasjon fra en Windows-PC og lagrer resultatet i en mappe på samme disk som scriptet kjøres fra (typisk USB). Det lager også en kort oppsummering som er rask å sjekke først.

#Filer i denne mappen
- `nettverksanalyse.ps1` – selve PowerShell-scriptet
- `RUN.cmd` – starter scriptet med ExecutionPolicy Bypass og ber om admin (UAC) automatisk
- `.gitignore`

#Hvordan kjøre

#Alternativ 1 (anbefalt):

1. Kopiér mappen `netdiag` til en USB (eller behold den der den er)
2. Kjør `RUN.cmd`
3. Godkjenn UAC (Kjør som administrator)

#Alternativ 2: PowerShell:

Åpne PowerShell (som administrator) og kjør:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "(DISK).\nettverksanalyse.ps1"
```

Hvor lagres filene?
(DISK):\NettverksAnalyser\<PC>_<BRUKER>_<YYYYMMDD_HHMMSS>\

Hvis scriptet feiler, skrives en feillogg til:
C:\Users\Public\NetDiag_ERROR_*.txt
