# Über
Das hier sind die PowerShell-Skripte, die wir im BDSU verwenden, um
automatisiert die Office365-Benutzer von JEs als Gastbenutzer im BDSU-Tenant
hinzuzufügen.

Das Hinzufügen als Gastbenutzer ermöglicht den JE-Mitgliedern direkt mit ihrem
Office365-Account auf Ressourcen im BDSU-Tenant zuzugreifen.

Der Guide zur gesamten Integration ist [hier](Integrationsguide.md) zu finden.

## Funktionsweise
Zuerst muss im JE-Tenant ein Benutzer aus dem BDSU-Tenant als Gastbenutzer
eingeladen werden. Dieser kann sich dann per `Connect-AzureAD` und der Tenant-ID
der JE zu deren Tenant verbinden und mit `Get-AzureADGroupMember` und einer
_bekannten_ Object ID einer Gruppe deren Mitglieder auslesen, siehe Beschreibung
der Konfiguration in [AutoInvite-Guests.ps1](AutoInvite-Guests.ps1).

Die User werden in einer Variablen gespeichert und das Skript verbindet sich mit
`Connect-AzureAD` zum BDSU-Tenant. Dort werden die User mit
`New-AzureADMSInvitation` als Gastbenutzer hinzugefügt:
- dafür benötigt der verwendete Benutzer entsprechende Adminrechte im BDSU-Tenant ("Benutzeradministrator")
- durch `-SendInvitationMessage $false` wird die Einladungs-E-Mail unterdrückt
- dadurch dass der verwendete Benutzer im JE-Tenant Leserechte hat, kann er die Object ID aus dem JE-Tenant direkt mit dem Gastbenutzer im BDSU-Tenant verknüpfen. **Nur dadurch kann der Aktivierungslink in der Einladungsmail übersprungen werden!**

Für mehr Infos siehe [AutoInvite-Guests.ps1](AutoInvite-Guests.ps1) und
https://justidm.wordpress.com/2017/05/07/azure-ad-b2b-how-to-bulk-add-guest-users-without-invitation-redemption/

## Dateien
- [AutoInvite-Guests.ps1](AutoInvite-Guests.ps1): Hauptskript, das die Synchronisation durchführt. Für jede JE muss ein entsprechender Konfigurationsblock hinzugefügt werden, siehe Dokumentation im Skript.
- [exportPassword.ps1](exportPassword.ps1): Mit diesem interaktiven Skript wird die `password.txt` angelegt, in der die Zugangsdaten _sicher_ gespeichert sind - die Daten können nur auf dem selben Windows-Host vom selben Windows-User entschlüsselt werden, siehe https://blog.kloud.com.au/2016/04/21/using-saved-credentials-securely-in-powershell-scripts/
- [Trigger-AutoInvite.ps1](Trigger-AutoInvite.ps1): Wrapper-Skript zur automatischen Ausführung als Cronjob; es kümmert sich um das Loggen aller Ausgaben und Durchrotieren/Löschen alter Logs
