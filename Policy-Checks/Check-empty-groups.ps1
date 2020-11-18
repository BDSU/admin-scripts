Connect-AzureAD
$groups = Get-AzureADgroup -all $true
$leeregruppen = $groups | Where-Object {
    $gruppenmitglieder = Get-AzureADGroupMember -ObjectId $_.ObjectId
    !$gruppenmitglieder
}
$leeregruppen
