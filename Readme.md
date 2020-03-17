# Über
Mit dem PowerShell-Skript [Create-Accounts.ps1](Create-Accounts.ps1) werden neue
Benutzer-Accounts im Office365-Tenant des BDSU erstellt.

## Prozess
Um einen neuen Account zu erstellen, muss dieser durch Eintragen in der
entsprechenden SharePoint-Liste vom
Vorstand/Ressortleiter/Engagiertenbeauftragten beantragt werden. Die IT wird
automatisch über neue Elemente in der SharePoint-Liste informiert und kann dann
mit diesem Skript halbautomatisch die Benutzer erstellen und die Zugangsdaten an
die angegebene E-Mail versenden.

## Funktionsweise
Zum Erstellen ruft das Skript die Elemente aus der entsprechend vorgefilterten
Ansicht der SharePoint-Liste über die
[Client-Side Object Model (CSOM) API von SharePoint](https://docs.microsoft.com/de-de/sharepoint/dev/sp-add-ins/complete-basic-operations-using-sharepoint-client-library-code)
ab und listet diese zur Auswahl auf.

Für einen ausgewählten Benutzer generiert das Skript aus Name und den Angaben
zur Account-Art die neue E-Mail-Adresse/Benutzernamen und erstellt diesen mit
Hilfe des
[AzureAD Modules](https://docs.microsoft.com/en-us/powershell/module/azuread/)
und fügt den Account zu ausgewählten Gruppen hinzu, wozu ggf. eine
[Exchange Remote Session](https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/exchange-online-powershell)
verwendet wird.

Sobald der Account bereit ist, können über das Skript die Zugangsdaten per
E-Mail an die eingetragene Adresse versendet werden und der Eintrag als erledigt
abgehakt werden, wodurch er aus der verwendeten Ansicht durch den Filter
entfernt wird.

## Installation
Um dieses Skript ausführen zu können, müssen erst einige Abhängigkeiten
durch entsprechende PowerShell-Befehle installiert werden.

### [AzureAD Module](https://docs.microsoft.com/en-us/powershell/module/azuread/)
```pwsh
Install-Module AzureAD
```

### [CSOM Libraries](https://docs.microsoft.com/en-us/powershell/exchange/exchange-online/exchange-online-powershell)
```pwsh
Install-Package Microsoft.SharePointOnline.CSOM -Source https://www.nuget.org/api/v2
```

### Security-Einstellungen
Die Ausführung des Skriptes wird ggf. von den lokalen Sicherheits-Einstellungen
von PowerShell verhindert. Diese Einstellungen kann man deaktivieren, indem man
eine PowerShell als Administrator startet und folgendes ausführt:
```pwsh
Set-ExecutionPolicy -ExecutionPolicy Bypass
```

## Besonderheiten

### Verzögerungen durch Synchronisation von AzureAD zu Exchange
Die verschiedenen Schritte des Skriptes werden manuell ausgeführt und können
unabhängig voneinander ausgeführt werden. Optimalerweise würden alle Schritte
automatisch nacheinander ausgeführt werden, was in der Praxis aber leider nicht
funktioniert. Grund dafür ist die Trennung von AzureAD und Exchange:

Gruppen, die auch als Verteiler fungieren, können nicht mit den AzureAD-Befehlen
bearbeitet werden (insbesondere `Add-AzureADGroupMember`), da für diese Exchange
als primäres System gilt. Daher muss zum Hinzufügen von Benutzern zu diesen
Gruppen, das entsprechende Exchange-Cmdlet - `Add-DistributionGroupMember` -
verwendet werden.

Neu angelegte User sind in Exchange aber erst nach ca. 2-5min verfügbar, da sie
initial von AzureAD in die Datenbank von Exchange synchronisiert werden müssen.

### Berechtigungen für Mail-Versand

Der Versand der Zugangsdaten geschieht über das Cmdlet `Send-MailMessage`.
Dieses verbindet sich mit den Admin-Credentials, die zum Anlegen des neuen
Benutzers verwendet wurden per SMTP zu Office365.

Als Absender wird die statisch im Skript eingetragene Adresse verwendet. Damit
der Mail-Versand funktioniert, benötigt der verwendete Admin-Account die `Send
as`-Berechtigungen für die verwendete Absenderadresse.
