# The script is used to remove the je contacts that are used in the configuration of the various BDSU distribution groups like BDS MIT Line.
Connect-ExchangeOnline

$Contacts = Get-MailContact -Resultsize unlimited 
$FilteredJeContacts = $Contacts | Where-Object {$_.PrimarySmtpAddress -like '*@je-domain.org'}
$FilteredJeContacts | Sort-Object Identity
$FilteredJeContacts | ForEach-Object {
    Users | ForEach-Object {
    # Before you remove the guest user pls check if everything is correct and than remove the comment
    # Remove-MailContact -Identity $_.PrimarySmtpAddress -Confirm:$false
    Write-Host "Removed contact" $_.Identity
} 