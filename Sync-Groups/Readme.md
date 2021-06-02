# Über
Diese Skripte helfen dabei rollenbasierte Berechtigung im BDSU besser
umzusetzen, indem Mitglieder aus bestimmten Gruppen automatisch als Mitglieder
in andere Gruppen synchronisiert werden können.

Das ist insbesondere ein Workaround für Office365-Gruppen, die nur direkte
Mitglieder enthalten können und nicht mit anderen Sicherheitsgruppen oder
Verteilern verschachtelt werden können.

Zusätzlich können Gruppenmitglieder nach E-Mail-Domain gefiltert werden. Das
ermöglicht das automatische Sicherstellen, dass in bestimmten (Teams-)Gruppen
ausschließlich interne Accounts zugelassen sind.
Dadurch werden unsere internen IT-Policies technisch erzwungen.

## Zusätzliche Abhängigkeit
Um dieses Skript ausführen zu können, muss erst eine weitere Abhängigkeit
durch einen entsprechenden PowerShell-Befehl installiert werden.

### [Microsoft Teams Module](https://docs.microsoft.com/de-de/microsoftteams/teams-powershell-overview)
```pwsh
Install-Module MicrosoftTeams
```

## Konfiguration
Das Skript wird über zwei Variablen am Anfang konfiguriert:
- `$syncMapping`: konfiguriert von welchen Gruppen die Mitglieder in eine Gruppe
  synchronisiert werden und ob/nach welchen Domains die Benutzer gefiltert
  werden sollen.
- `$groupIds`: Zuordnung von lesbaren Gruppennamen zu ihren IDs

Für Details siehe die ausführlichen Beschreibungen im [Skript](Sync-Groups.ps1)
selber.

## Dateien
- [Sync-Groups.ps1](Sync-Groups.ps1): Hauptskript, das die Synchronisation durchführt.
- [exportPassword.ps1](exportPassword.ps1): Mit diesem interaktiven Skript wird
  die `password.txt` angelegt, in der die Zugangsdaten _sicher_ gespeichert sind
  - die Daten können nur auf dem selben Windows-Host vom selben Windows-User
  entschlüsselt werden, siehe
  https://blog.kloud.com.au/2016/04/21/using-saved-credentials-securely-in-powershell-scripts/
- [Trigger-GroupSync.ps1](Trigger-GroupSync.ps1): Wrapper-Skript zur
  automatischen Ausführung als Cronjob; es kümmert sich um das Loggen aller
  Ausgaben und Durchrotieren/Löschen alter Logs
