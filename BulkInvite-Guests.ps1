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
 # Für jede JE muss eine HashTable zu $configs hinzugefügt werden mit folgenden Keys:
 #     - name: Anzeigename der JE, wird auch dem Anzeigenamen des Benutzers hinzugefügt
 #     - tenantId: GUID des Office365-Tenants der JE
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
        groups = @{
            "Mitglieder" = "12345678-abcd-abcd-abcd-1234567890ab"
        }
    }
)

$credentials = Get-Credential -Message "Admin in main tenant"

$configs | ForEach-Object {
    $config = $_

    Write-Host -ForegroundColor Green "Inviting users for $($config.name)"
    Connect-AzureAD -TenantId $config.tenantId -Credential $credentials

    $members = $config.groups.Values | ForEach-Object {
        Get-AzureADGroupMember -ObjectId $_
    } | Where-Object {
        $_.ObjectType -eq "User"
    } | Sort-Object -Unique DisplayName

    Connect-AzureAD -TenantId $bdsuTenantId -Credential $credentials

    $guests = Get-AzureADGroupMember -ObjectId $guestsGroupId -All $true | select -ExpandProperty ObjectId

    $members | ForEach-Object {
        $member = $_
        $result = New-AzureADMSInvitation -InvitedUserEmailAddress $member.Mail -InvitedUserDisplayName $member.DisplayName -SendInvitationMessage $false -InvitedUserType guest -InviteRedirectUrl https://bdsuev.sharepoint.com
        if ($?) {
            Set-AzureADUser -ObjectId $result.InvitedUser.Id -Department $member.Department -DisplayName "$($member.DisplayName) | $($config.name)" -GivenName $member.GivenName -JobTitle $member.JobTitle -Surname $member.Surname -ShowInAddressList $true -UserType guest
            if ($result.InvitedUser.Id -notin $guests) {
                Add-AzureADGroupMember -ObjectId $guestsGroupId -RefObjectId $result.InvitedUser.Id
            }
        }
        $result
    } | ft
}
