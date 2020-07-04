param(
    [string]$DIR
)

if (!$DIR) {
    $DIR = [string](Get-Location)
}

if ($DIR -match '.+?\\$') {
    $DIR = $DIR.Substring(0, $DIR.Length-1)
}

<###
 #
 # Skript zum Hinzufügen aller Mitglieder einer Gruppe im eigenen Tenant
 # als Gast zum O365-Tenant des BDSU
 #
 # Für die Ausführung wird das AzureAD-Modul für PowerShell benötigt:
 # https://docs.microsoft.com/en-us/powershell/azure/active-directory/install-adv2?view=azureadps-2.0
 #
 #
 # Konfiguration:
 # - $bdsuTenantId: GUID des Office365-Tenants des BDSU
 # - $guestGroupId: Object ID der Gruppe, zu der alle Gastbenutzer hinzugefügt werden sollen (für Berechtigungen)
 # - $username: Benutzername des Users mit Admin-Rechten im BDSU-Tenant und Gastzugriff in den JE-Tenants
 # Für jede JE muss eine HashTable zu $configs hinzugefügt werden mit folgenden Keys:
 #     - name: Anzeigename der JE, wird auch dem Anzeigenamen des Benutzers hinzugefügt
 #     - tenantId: GUID des Office365-Tenants der JE
 #     - group (optional): falls vorhanden: füge alle User dieser JE zu dieser JE-spezifischen Gruppe im BDSU-Tenant hinzu
 #     - groups: HashTable mit allen Gruppen, deren Mitglieder übernommen werden sollen
 #         - key ist der Name der Gruppe (wird nicht verwendet, dient nur der Lesbarkeit der Konfiguration
 #         - value ist die Object ID der Gruppe
 # Es werden dabei nur direkte Mitglieder der Gruppe hinzugefügt und verschachtelte Gruppen *nicht* rekursiv aufgelöst!
 #
 # siehe auch:
 # https://justidm.wordpress.com/2017/05/07/azure-ad-b2b-how-to-bulk-add-guest-users-without-invitation-redemption/
 #
 ###>

$bdsuTenantId = "12345678-abcd-abcd-abcd-1234567890ab"
$guestsGroupId = "12345678-abcd-abcd-abcd-1234567890ab"
$configs = @(
    @{
        name = "JE Name"
        tenantId = "12345678-abcd-abcd-abcd-1234567890ab"
        group = "12345678-abcd-abcd-abcd-1234567890ab"
        groups = @{
            "Mitglieder" = "12345678-abcd-abcd-abcd-1234567890ab"
        }
    }
)

Write-Output "Starting:  $((Get-Date).tostring("yyyy-MM-dd_hh-mm"))"

if (Test-Path -Path "$DIR\password.txt") {
    $username = "admin@example.org"

    $secPasswordText = Get-Content "$DIR\password.txt"
    $secPassword = $secPasswordText | ConvertTo-SecureString

    $credentials = New-Object System.Management.Automation.PSCredential ($username, $secPassword)
}

if (!$credentials) {
    $credentials = Get-Credential
}

$configs | ForEach-Object {
    $config = $_

    Write-Output "Inviting users for $($config.name)"
    Connect-AzureAD -TenantId $config.tenantId -Credential $credentials

    $members = $config.groups.Values | ForEach-Object {
        Get-AzureADGroupMember -All $true -ObjectId $_
    } | Where-Object {
        $_.ObjectType -eq "User"
    } | Sort-Object -Unique | Sort-Object DisplayName

    Connect-AzureAD -TenantId $bdsuTenantId -Credential $credentials

    $guests = Get-AzureADGroupMember -ObjectId $guestsGroupId -All $true | select -ExpandProperty ObjectId

    if ($config.group) {
        $guest_group_members = Get-AzureADGroupMember -ObjectId $config.group -All $true | select -ExpandProperty ObjectId
    }

    $members | ForEach-Object {
        $member = $_
        $result = New-AzureADMSInvitation -InvitedUserEmailAddress $member.Mail -InvitedUserDisplayName $member.DisplayName -SendInvitationMessage $false -InvitedUserType guest -InviteRedirectUrl https://bdsuev.sharepoint.com
        if ($?) {
            Set-AzureADUser -ObjectId $result.InvitedUser.Id -Department $member.Department -DisplayName "$($member.DisplayName) | $($config.name)" -GivenName $member.GivenName -JobTitle $member.JobTitle -Surname $member.Surname -ShowInAddressList $true -UserType guest
            if ($result.InvitedUser.Id -notin $guests) {
                Add-AzureADGroupMember -ObjectId $guestsGroupId -RefObjectId $result.InvitedUser.Id
            }
            if ($config.group -and $result.InvitedUser.Id -notin $guest_group_members) {
                Add-AzureADGroupMember -ObjectId $config.group -RefObjectId $result.InvitedUser.Id
            }
        }
        $result
    } | ft
}
