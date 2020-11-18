Connect-AzureAD
$users = Get-AzureADUser -all $true
$groups = Get-AzureADgroup -all $true
$useringruppe = $groups | ForEach-Object {Get-AzureADGroupMember -ObjectId $_.ObjectId -all $true}
$userohnegruppe = $users | Where-Object {$useringruppe.userprincipalname -notcontains $_.userprincipalname}
$userohnegruppe
