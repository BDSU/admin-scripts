# The script is used to remove JE guest accounts that allow access to the BDSU intranet. 
Connect-AzureAd

$GuestUsers = Get-AzureADUser -Filter "UserType eq 'Guest'" -All $true
$JeUsers = $GuestUsers | Where-Object {$_.mail -like '*@je-domain.org'}
$JeUsers | Sort-Object DisplayName 
$JeUsers | ForEach-Object {
    # Before you remove the guest user pls check if everything is correct and than remove the comment
    # Remove-AzureADUser -ObjectId $_.ObjectId
    Write-Host "Removed guest user" $_.DisplayName
} 