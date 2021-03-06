﻿$sdk_base_path = Get-Package Microsoft.SharePointOnline.CSOM | Select-Object -ExpandProperty Source | Split-Path
Import-Module "$sdk_base_path\lib\net40-full\Microsoft.SharePoint.Client.dll"

if (!$credentials) {
    $credentials = Get-Credential
}

$weburl = "https://bdsuev.sharepoint.com/sites/bdsu.it/"
$context = New-Object Microsoft.SharePoint.Client.ClientContext($weburl)
$context.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($credentials.UserName, $credentials.Password)

Connect-AzureAD -Credential $credentials

$sessions = Get-PSSession
if ($sessions.ComputerName -notcontains "outlook.office365.com") {
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $credentials -Authentication Basic -AllowRedirection
    Import-PSSession $Session
}


function getItemsForView($listname, $viewname) {
    $web = $context.Web
    $list = $web.Lists.GetByTitle($listname)

    $view = $list.Views.GetByTitle($viewname)
    $context.Load($view)
    $context.ExecuteQuery()

    $query = New-Object Microsoft.SharePoint.Client.CamlQuery
    $query.ViewXml = $view.ListViewXml

    $items = $list.GetItems($query)
    $context.Load($items)
    $context.ExecuteQuery()

    return $items
}

<######
 # Hilfsfunktion zum Einlesen von Werten von der Kommandozeile
 #
 # $name: string, anzuzeigender Name
 # $default: string
 # return: vom User eingegebener Wert oder $default, falls Eingabe leer war
 #>
function Read-Value ($name, $default) {
    Write-Host -NoNewline "$name [$default]: ";
    $value = Read-Host;
    if (!$value) {
        $value = $default;
    }
    return [string] $value;
}

<######
 # Generiert ein 10 Zeichen langes Passwort aus Groß-/Kleinbuchstaben, Zahlen und Sonderzeichen
 #>
function Generate-Password {
    $caps = [char[]] "ABCDEFGHJKMNPQRSTUVWXY";
    $lows = [char[]] "abcdefghjkmnpqrstuvwxy";
    $nums = [char[]] "012346789";
    $spl  = [char[]] "/&?$%";

    $first  = $nums | Get-Random -count 4;
    $second = $caps | Get-Random -count 3;
    $third  = $lows | Get-Random -count 4;
    $fourth = $spl  | Get-Random -count 2;

    $pwd = (@($first) + @($second) + @($third) + @($fourth) | Get-Random -Count 12) -join "";
    return $pwd;
}

function Get-CurrentLine {
    return $MyInvocation.ScriptLineNumber
}

<######
 # Generiert eine UID im Muster "$firstname.$lastname" in Kleinbuchstaben,
 # wobei alle Sonderzeichen gemäß $map ersetzt werden.
 #>
function Generate-UID ($firstname, $lastname) {
    $map = @{
        "ä" = "ae";
        "š" = "s";
        "í" = "i";
        "ö" = "oe";
        "ü" = "ue";
        "ß" = "ss";
        "é" = "e";
        "è" = "e";
        "ó" = "o";
        "ø" = "o";
        "ò" = "o";
        "á" = "a";
        "à" = "a";
        "Č" = "c";
        "'" = "-";
        "c" = "c";
        "ć" = "c";
        "ý" = "y";
        "Ž" = "z";
        "ń" = "n";
        "ś" = "s";
        "ı" = "i";
        "ô" = "o";
        "đ" = "d";
        "ą" = "a";
        "Ř" = "r";
        "ł" = "l";
        "ź" = "z";
        "ż" = "z";
        "ï" = "i";
        "ë" = "e";
    };
    $line = $(Get-CurrentLine) - 2

    $uid = "$firstname.$lastname" -replace " ","-";
    $uid = $uid.ToLower();
    foreach ($search in $map.Keys) {
        $uid = $uid -replace $search, $map[$search];
    }

    $regex = "[^a-z0-9.-]"
    if ($uid -match $regex) {
        Write-Warning "Die generierte UID enthält ungültige Zeichen!"
        Write-Warning "Bitte füge folgende Zeile im Skript in Zeile $line hinzu, um das/die ungültigen Zeichen durch ein gültiges zu ersetzen (`"?`")"
        Select-String $regex -Input $uid -AllMatches | ForEach-Object {$_.matches} | sort -Unique | ForEach-Object {
            Write-Host "`t`t`"$_`" = `"?`";"
        }
        Write-Host
        return ""
    }

    return $uid;
}

function Create-Account($firstname, $lastname, $display_name, $uid, $mail, $private_mail) {
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.ForceChangePasswordNextLogin = $true
    $PasswordProfile.Password = Generate-Password

    $user = New-AzureADUser -AccountEnabled $true -UserPrincipalName $mail -DisplayName $display_name -GivenName $firstname -Surname $lastname -UsageLocation DE -OtherMails $private_mail -PasswordProfile $PasswordProfile -MailNickName $uid
    if (!$? -or !$user) {
        Write-Warning "failed to create user"
        return $false
    }

    $skuId = Get-AzureADSubscribedSku | Where-Object {$_.SkuPartNumber -eq "STANDARDWOFFPACK_STUDENT"} | Select-Object -ExpandProperty skuId
    $license = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    $license.SkuId = $skuId
    $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $licenses.AddLicenses = $license
    Set-AzureADUserLicense -ObjectId $user.ObjectId -AssignedLicenses $licenses
    if (!$?) {
        Write-Warning "failed to assign license"
    }

    return $true
}

function Get-GroupType($groupId) {
    $group = Get-UnifiedGroup -Identity $groupId -ErrorAction SilentlyContinue
    if ($group) {
        return "Office365"
    }

    $group = Get-DistributionGroup -Identity $groupId -ErrorAction SilentlyContinue
    if ($group) {
        return "Distribution"
    }

    $group = Get-AzureADGroup -ObjectId $groupId -ErrorAction SilentlyContinue
    if ($group -and $group.SecurityEnabled -and !$group.MailEnabled) {
        return "Security"
    }

    throw "Failed to detect group type '$groupId'"
}

function Send-WelcomeMail($firstname, $lastname, $private_mail, $mail, $password) {
    $body = @"
        Hallo $firstname,<br />
        <br />
        wir haben dir soeben deinen brandneuen Account für <strong>$mail</strong> erstellt!<br />
        Zugriff auf dein neues Postfach bekommst du <a href="https://outlook.office.com/">online unter [1]</a> mit diesen Zugangsdaten:
        <ul>
            <li>Benutzername: <strong>$mail</strong></li>
            <li>Passwort: <strong>$password</strong></li>
        </ul>
        Bei Problemen mit deinem neuen Account kannst du dich an die BDSU-IT (<a href="mailto:it@bdsu.de">it@bdsu.de</a>) wenden.
        Wenn du mal dein Passwort vergessen hast, kannst du es selbst über die Passwort-vergessen-Funktion im Login-Formular zurücksetzen lassen.<br />
        <br />
        [1]&nbsp;<a href="https://outlook.office.com/">https://outlook.office.com/</a><br />
        <br />
        Beste Grüße<br />
        Deine BDSU-IT
"@

    Send-MailMessage `
        -From 'BDSU IT Helpdesk <it@bdsu.de>' `
        -To $private_mail `
        -Subject "[BDSU] Zugangsdaten für deinen neuen Account" `
        -Body $body `
        -BodyAsHtml `
        -Encoding UTF8 `
        -SmtpServer "smtp.office365.com" `
        -Port 587 `
        -UseSsl `
        -Credential $credentials

    return $?
}

do {
    $items = getItemsForView Accounts IT
    $items | ForEach-Object {
        $item = $_
        $row = @{}
        "ID","Vorname","Nachname","email","Accountart","Gruppen","Freigabe" | ForEach-Object {
            $value = $item[$_]
            if ($value -and $value.LookupId) {
                $value = $value.LookupValue
            }
            $row[$_] = $value
        }
        [psCustomObject]$row
    } | ft -AutoSize "ID","Vorname","Nachname","email","Accountart","Gruppen","Freigabe"

    $selected = Read-Host -Prompt "Account ID wählen (beenden mit 'q')"
    if ($selected -eq "q") {
        break
    }

    $item = $context.Web.Lists.GetByTitle("Accounts").GetItemById($selected)
    $context.Load($item)
    $context.ExecuteQuery()
    if (!$?) {
        Write-Warning "Angebene ID nicht gefunden"
        continue
    }


    $domain = $item["Accountart_x003a_domain"].LookupValue
    $display_name_pattern = $item["Accountart_x003a_Anzeigename"].LookupValue

    $firstname = $item["Vorname"].Trim()
    $lastname = $item["Nachname"].Trim()
    $private_mail = $item["email"].Trim()

    $uid = Generate-UID $firstname $lastname
    $mail = "$uid@$domain"
    $display_name = $display_name_pattern -replace "%Vorname%",$firstname -replace "%Nachname%",$lastname


    $action = Read-Value "Neuen Account erstellen für $($display_name)? [y/N]" "n"
    if ($action -eq "y") {
        $success = Create-Account $firstname $lastname $display_name $uid $mail $private_mail
        if (!$success) {
            Write-Warning "Fehler beim Erstellen des User"
            Read-Host -Prompt "Enter drücken"
            continue
        }

        Write-Host -ForegroundColor Green "Erfolg"
    }

    $user = Get-AzureADUser -ObjectId $mail
    if (!$? -or !$user) {
        Write-Warning "User konnte nicht gefunden werden!"
        continue
    }

    if ($item["Gruppen_x003a_ObjectID"]) {
        $action = Read-Value "Zu Gruppen hinzufügen? [y/N]" "n"
        if ($action -eq "y") {
            Write-Host "Füge zu Gruppen hinzu:"
            $item["Gruppen_x003a_ObjectID"].LookupValue | ForEach-Object {
                $group = Get-AzureADGroup -ObjectId $_
                Write-Host $group.DisplayName
                $groupType = Get-GroupType $group.ObjectId
                switch ($groupType){
                    "Office365" {
                        Add-UnifiedGroupLinks -Identity $group.ObjectId -LinkType member -Links $mail
                    }
                    "Distribution" {
                        Add-DistributionGroupMember -Identity $group.Mail -Member $user.UserPrincipalName -BypassSecurityGroupManagerCheck
                    }
                    "Security" {
                        Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $user.ObjectId
                    }
                }
            }
        }
    }


    $action = Read-Value "Welcome-Mail versenden? [y/N]" "n"
    if ($action -eq "y") {
        $password = Generate-Password
        Set-AzureADUserPassword -ObjectId $user.ObjectId -Password (ConvertTo-SecureString -AsPlainText -Force $password) -ForceChangePasswordNextLogin $true

        Write-Host "Sende Welcome-Mail"
        Send-WelcomeMail $user.GivenName $user.Surname $item["email"] $user.UserPrincipalName $password
    }


    $action = Read-Value "Als erledigt abhaken? [y/N]" "n"
    if ($action -eq "y") {
        $item["erledigt"] = $true
        $item.Update()
        $context.ExecuteQuery()
    }
} while ($choice -ne "q")