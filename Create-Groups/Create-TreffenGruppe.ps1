# Konfiguration:
$weburl = "URL der SharePoint Seite"
$listName = "Name der SharePoint Liste"
$treffenausrichter = "Object-ID der Sicherheitsgruppe"
$domain = "BDSU Kongress Domain"
$beschreibung = "Ausrichterteam"

$sdk_base_path = Get-Package Microsoft.SharePointOnline.CSOM | Select-Object -ExpandProperty Source | Split-Path
Import-Module "$sdk_base_path\lib\net40-full\Microsoft.SharePoint.Client.dll"

if (!$credentials) {
    $credentials = Get-Credential
}

$context = New-Object Microsoft.SharePoint.Client.ClientContext($weburl)
$context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($credentials.UserName, $credentials.Password)

Connect-AzureAD -Credential $credentials

function Create-TreffenGruppe ($treffenArt, $treffenStadt, $treffenJahr, $treffenName) {
   
    $treffenBeschreibung = "Verteiler für das Ausrichterteam des " +  $treffenArt + " " + $treffenStadt + " " + $treffenJahr + " und für den Zugriff auf den Treffen-SharePoint."
    $alias = "team." + $treffenArt.ToLower() + $treffenJahr
        
    # Neue Treffengruppe ersellen
    $neueTreffenGruppe = New-AzureADGroup -DisplayName $treffenName -Description $treffenBeschreibung -MailEnabled $false -MailNickName $alias -SecurityEnabled $true
    $neueTreffenGruppeObjectId = $neueTreffenGruppe.ObjectId

    # Neue Treffengruppe zur Ausrichterteams Sicherheitsgruppe hinzufügen
    Add-AzureADGroupMember -ObjectId $treffenausrichter -RefObjectId $neueTreffenGruppeObjectId

    return $neueTreffenGruppeObjectId
}

# Eingaben abfragen
$treffenArtUntrimed = Read-Host -Prompt "Treffenart [FK/HK/JK]?"
$treffenArt = $treffenArtUntrimed.Trim()
$treffenStadtUntrimed = Read-Host -Prompt "Welche Stadt?"
$treffenStadt = $treffenStadtUntrimed.Trim()
$treffenJahrUntrimed = Read-Host -Prompt "In welchem Jahr ? (volles Jahr vierstellig)"
$treffenJahr = $treffenJahrUntrimed.Trim()
$treffenName = "BDSU-Treffen - Ausrichterteam $treffenArt $treffenStadt $treffenJahr"
$uebpruefung = Read-Host -Prompt "Passt der Gruppenname [y/n]: $treffenName"

# Eingabeabbruch
if($uebpruefung -ne "y"){
    Exit 
}

Write-Host "$treffenName wird erstellt"
$neuesTreffenOjectId = Create-TreffenGruppe $treffenArt $treffenStadt $treffenJahr $treffenName

# Anzeigename generieren
$anzeigeName = "%Vorname% %Nachname% | $treffenArt $treffenStadt $treffenJahr"

# Titel generieren
$jahrFormatiert = $treffenJahr.Substring($treffenJahr.length - 2)
$title = "Kongress - $treffenArt$jahrFormatiert $treffenStadt"

# SharePoint Liste abfragen
$List = $context.Web.Lists.GetByTitle($listName)
$context.Load($List)
$context.ExecuteQuery()

# Neues SharePoint List Item anlegen
$ListItemCreationInformation = New-Object Microsoft.SharePoint.Client.ListItemCreationInformation
$NewListItem = $List.AddItem($ListItemCreationInformation)
$NewListItem["Title"] = $title
$NewListItem["domain"] = $domain
$NewListItem["ObjectId"] = $neuesTreffenOjectId
$NewListItem["Anzeigename"] = $anzeigeName
$NewListItem["pawp"] = $beschreibung
$NewListItem.Update()
$context.ExecuteQuery()

Write-Host "$treffenName ist erstellt"