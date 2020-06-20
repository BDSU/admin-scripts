param(
    [string]$DIR = (Get-Location)
)

if ($DIR -match '.+?\\$') {
    $DIR = $DIR.Substring(0, $DIR.Length-1)
}

if (Test-Path -Path "$DIR\password.txt") {
    $username = "sync-admin@bdsu-connect.de"

    $secPasswordText = Get-Content "$DIR\password.txt"
    $secPassword = $secPasswordText | ConvertTo-SecureString

    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secPassword)
}

if (!$credentials) {
    $credentials = Get-Credential
}

Connect-AzureAD -Credential $credentials | Out-Null

# remove existing Exchange Remote Sessions if any
Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com"} | Remove-PSSession

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $credentials -Authentication Basic -AllowRedirection
Import-PSSession $session
if (!$?) {
    throw "Failed to import Exchange Remote Session"
}



#=====Alle Gruppen initalisieren
$alleGruppen = @{
    #Alle Gruppen + Verteiler werden mit ihrer Object-ID initalisiert:

    #"Gruppe1" = "Object-ID"
    #"Verteiler1Gruppe1" = "Object-ID"
}
 
#=====Moderatoren zum Verteiler zuordnen: Verteiler = Moderatoren
$groupMatchingModeration = @{
#Zum Beispiel:

#"Verteiler1Gruppe1" = "Gruppe1"

}

#=====Besitzer zum Verteiler zuordnen: Verteiler = Besitzer
$groupMatchingBesitzer = @{
#Zum Beispiel:

#"Verteiler1Gruppe1" = "Gruppe1"
}


#======Gruppenbesitzer ernennen
$groupMatchingBesitzer.GetEnumerator() | ForEach-Object{

#====zu besetzende Gruppe initalisieren
$zubesetzendeGruppe = $_.name
$zubesetzendeGruppeID = $alleGruppen[$zubesetzendeGruppe]

$aktuelleBesitzer = New-Object System.Collections.ArrayList

foreach ($group in $_.Value) {
  
#====Aktuelle als Moderatoren berechtigt
$aktuelleBesitzerZwischenspeicher = Get-DistributionGroupMember -Identity $alleGruppen[$group]  
$aktuelleBesitzer.Add($aktuelleBesitzerZwischenspeicher)
  
}

#===Berechtigte zur moderierenden Gruppe als Moderatoren hinzufügen
  Set-DistributionGroup $zubesetzendeGruppeID -ManagedBy $aktuelleBesitzer.PrimarySmtpAddress
  
  Write-Host "Aus der Gruppe " $group " wurden alle zu Besitzern von " $zubesetzendeGruppe 

#===Ausgabe neuer Moderatoren
$neueBesitzer = Get-DistributionGroup -Identity $zubesetzendeGruppeID 
Write-Host "Aktuelle Besitzer für " $zubesetzendeGruppe ": " $neueBesitzer.ManagedBy
}




#====Funktion Moderatoren
$groupMatchingModeration.GetEnumerator() | ForEach-Object{

#====Zu moderierende Gruppen initalisieren
$zuModerierendeGruppe = $_.name
$zuModerierendeGruppeID = $alleGruppen[$zuModerierendeGruppe]

$aktuelleModeratoren = New-Object System.Collections.ArrayList

foreach ($group in $_.Value) {
  
#====Aktuelle als Moderatoren berechtigt
$aktuelleModeratorenZwischenspeicher = Get-DistributionGroupMember -Identity $alleGruppen[$group]  
$aktuelleModeratoren.Add($aktuelleModeratorenZwischenspeicher)

  
}

#===Berechtigte zur moderierenden Gruppe als Moderatoren hinzufügen
  Set-DistributionGroup  $zuModerierendeGruppeID -ModerationEnabled $true -ModeratedBy  $aktuelleModeratoren.PrimarySmtpAddress
  Write-Host "Aus der Gruppe " $group " wurden alle zu Moderatoren von " $zuModerierendeGruppe 

#===Ausgabe neuer Moderatoren
$neueModeratoren = Get-DistributionGroup -Identity $zuModerierendeGruppeID
Write-Host "Aktuelle Moderatoren für " $zuModerierendeGruppe ": " $neueModeratoren.ModeratedBy 
}
