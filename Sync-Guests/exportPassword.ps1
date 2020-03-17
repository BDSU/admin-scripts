param(
    [string]$DIR
)

if (!$DIR) {
    $DIR = [string](Get-Location)
}

if ($DIR -match '.+?\\$') {
    $DIR = $DIR.Substring(0, $DIR.Length-1)
}

# https://blog.kloud.com.au/2016/04/21/using-saved-credentials-securely-in-powershell-scripts/
# Properly escape special chars! -> http://www.rlmueller.net/PowerShellEscape.htm
$password = Read-Host -AsSecureString
#$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$secureStringText = $password | ConvertFrom-SecureString
Set-Content "$DIR\password.txt" $secureStringText
