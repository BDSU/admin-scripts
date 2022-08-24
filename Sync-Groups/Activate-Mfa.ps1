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


Connect-MsolService -Credential $credentials | Out-Null

Connect-AzureAD -Credential $credentials | Out-Null

# remove existing Exchange Remote Sessions if any
Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com"} | Remove-PSSession

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $credentials -Authentication Basic -AllowRedirection
Import-PSSession $session
if (!$?) {
    throw "Failed to import Exchange Remote Session"
}

# Groups which require a mfa authentication
$mfaGroups = @{

    "Group name" = "Distribution Group Object-Id"

}

$mfaGroups.GetEnumerator() | ForEach-Object{
    $groupId = $_.Value
    $groupMember = Get-DistributionGroupMember -Identity $groupId

    
    # Activate mfa for groups
    foreach ($distUser in $groupMember) {
        
        $adUser = Get-AzureADUser -ObjectId $distUser.ExternalDirectoryObjectId

        $st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $st.RelyingParty = "*"
        $st.State = "Enabled"
        $sta = @($st)
        Set-MsolUser -UserPrincipalName $adUser.UserPrincipalName -StrongAuthenticationRequirements $sta
        Write-Host $adUser.displayname " 2 FA enabled"

    }

}