<#################################################################################################################

Skript um im Tenant für Accounts die 2FA zu aktivieren
Quelle/Referenz: https://docs.microsoft.com/de-de/azure/active-directory/authentication/howto-mfa-userstates

Voraussetzung:
- Installation des Exchange Online Moduls V2
  (siehe https://www.powershellgallery.com/packages/ExchangeOnlineManagement/ )

- Installation des MSOnline Modul
  (Befehl: Install-Module MSOnline)
  (siehe https://docs.microsoft.com/de-de/azure/active-directory/authentication/howto-mfa-userstates#change-state-using-powershell)



################################################################################################################>

# Mit MSOnline verbinden
Connect-MsolService

# Alle Accounts erfassen
$alleAccounts = Get-AzureADUser -All $true

# Mögliche Filter:
# Gastaccounts rausfiltern
$alleNutzer = $alleAccounts | Where-Object {$_.UserType -eq "Member"}

# Accounts überprüfen
#$alleNutzer | ft displayname, usertype

# 2 FA für alle Accounts aktivieren 
foreach ($user in $alleNutzer)
{
    
    $st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
    $st.RelyingParty = "*"
    $st.State = "Enabled"
    $sta = @($st)
    Set-MsolUser -UserPrincipalName $user.UserPrincipalName -StrongAuthenticationRequirements $sta
    Write-Host $user.displayname " wurde fuer 2 FA enabled"
}



    