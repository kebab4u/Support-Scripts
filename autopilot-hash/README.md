# Autopilot HW Hash Collector

Samler Windows Autopilot hardware hash og lagrer resultatet som CSV på USB.

---

## Filer i mappen
- `hent-hwhash.ps1` – installerer/kjører `Get-WindowsAutoPilotInfo` og skriver CSV
- `RUN.cmd` – starter scriptet (og sørger for admin/korrekt kjøring)

---

## Hvor lagres filene?
Output lagres i:
`<USB>:\AutopilotHash\`

---

## Lagringsmoduser
Når scriptet starter kan du velge:

- **New**: lager ny fil `HWhash_DDMMYYYY.csv` (lager `_2`, `_3` osv. hvis du kjører flere ganger samme dag)
- **Collection**: legger til i fast fil `HWhash_Collection.csv`
- **Latest**: legger til i nyeste `HWhash_*.csv` i `AutopilotHash` (ignorerer Collection)

---

## Bruk etter innlogging (vanlig)
1. Kopier hele mappen til en USB.
2. På PC-en du vil hente hash fra: dobbeltklikk `RUN.cmd`.
3. Velg lagringsmodus (New / Collection / Latest).
4. Finn CSV i: `<USB>:\AutopilotHash\`

---

## Bruk under OOBE / før innlogging
Dette kan brukes mens du står i Windows OOBE (før du har logget inn).

1. I OOBE: trykk **Shift + F10** (på noen laptopper: **Fn + Shift + F10**) for å åpne CMD.
2. Finn hvilken diskbokstav USB-en fikk.

   Kjør denne (fra CMD) for å finne `RUN.cmd`:
   for %i in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do @if exist %i:\RUN.cmd echo Fant: %i:\RUN.cmd

4. Når du ser riktig bokstav (eksempel `E:`), kjør:
- Hvis `RUN.cmd` ligger i root:
  ```
  E:\RUN.cmd
  ```
- Hvis `RUN.cmd` ligger i en mappe (eksempel):
  ```
  E:\autopilot-hash\RUN.cmd
  ```

Hvis `RUN.cmd` ikke fungerer i OOBE-miljøet, kjør PowerShell direkte fra CMD:
---
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "E:\hent-hwhash.ps1"
## Krav / Notater
- Scriptet bruker PowerShell Gallery for å installere `Get-WindowsAutoPilotInfo` (internett kreves første gang hvis den ikke allerede er installert).
- Kjør scriptet fra USB for at output automatisk lagres på riktig sted.
