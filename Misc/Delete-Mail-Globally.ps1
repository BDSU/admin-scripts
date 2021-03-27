# Präventiv Direktausführung unterbinden
Write-Host -ForegroundColor red "Skript nicht als Gesamtes ausführen, sondern Kommentare lesen und in PowerShell ISE schrittweise durchgehen"
Read-Host "Enter zum Beenden"
exit

<#################################################################################################################

Skript zum Entfernen bestimmter Mails aus sämtlichen Exchange Online Postfächern
Quelle/Referenz: https://adamtheautomator.com/office-365-delete-email/

Voraussetzung:
- Installation des Exchange Online Moduls V2
  (siehe https://www.powershellgallery.com/packages/ExchangeOnlineManagement/ )
- Ausführung des Skripts mit einem Admin-Account
- Um einsehen zu können, welche exakten Emails betroffen sind, muss der ausführende Account als eDiscovery Manager
  hinterlegt sein. Anleitung: https://docs.microsoft.com/en-us/microsoft-365/compliance/assign-ediscovery-permissions?view=o365-worldwide#assign-ediscovery-permissions-in-the-security--compliance-center-1

Durchführung:
1. Erst das gesamte Skript und alle Kommentare aufmerksam lesen, bevor irgendetwas ausgeführt wird
2. Anpassung auf den eigenen Use Case:
    a) Einfach: Variable $sender auf den Absender und $date auf das Zustellungsdatum setzen
    b) Fortgeschritten: Beim cmdlet New-ComplianceSearch den Parameter -ContentMatchQuery anpassen 
                        (siehe https://docs.microsoft.com/en-us/powershell/module/exchange/new-compliancesearch )
3. Ggf. Variable $searchName anpassen, da der Name nicht mehrfach verwendet werden kann.
4. Skript nicht als Ganzes, sondern schrittweise ausführen und Kommentare beachten.

###### Anpassungen vornehmen ####################################################################################>
$sender = "evil_phisher@example.org"
$date = "12/31/1999" # Absende-Tag als MM/DD/YYYY
$searchName = "Phishing" # Identifier
<################################################################################################################>

# Mit Compliance Center verbinden
if (!$credentials) {
    $credentials = Get-Credential
}
Connect-IPPSSession -Credential $credentials

# Starte Suche nach passenden Mails
New-ComplianceSearch -Name $searchName -ExchangeLocation All -ContentMatchQuery "from:$sender AND sent:$date"
Start-ComplianceSearch -Identity $searchName

# Überpruefe Status bis "Completed"
Get-ComplianceSearch -Identity $searchName

# Frage Ergebnisse als Daten an
New-ComplianceSearchAction -SearchName $searchName -Preview

# Überprüfe Status, dann zeige an
Get-ComplianceSearchAction "$($searchName)_Preview"
(Get-ComplianceSearchAction "$($searchName)_Preview" | Select-Object -ExpandProperty Results) -split ","

# OPTIONAL: Speichere Ergebnisse in Datei (im aktuellen Prompt-Ordner als phishing.log, ggf. anpassen)
(Get-ComplianceSearchAction "$($searchName)_Preview" | Select-Object -ExpandProperty Results) -split "," | `
Out-File -FilePath "./phishing.log"

<#################################################################################################################
ACHTUNG!
Die übernächste Zeile leitet das Löschen der Mails ein. Es ist dringend empfohlen, vorher die Ergebnisse durchzusehen
und ggf. die Anfrage zu korrieren. Hierzu wäre notwendig, die Variable $searchName anzupassen (s.o.), da diese 
eindeutig sein muss und bereits verwendet wurde.

Um unvorsichtiges Löschen zu unterbinden, steht folgt erst ein "exit", welches bei Ausführung das Skript abbricht.
Bei schrittweiser Ausführung muss es übersprungen werden.
#################################################################################################################>
exit
New-ComplianceSearchAction -SearchName $searchName -Purge -PurgeType SoftDelete

# Überpruefe Status
Get-ComplianceSearchAction "$($searchName)_Purge"
