param(
    [string]$DIR = (Get-Location)
)

<##
 # configuration hash map of which group(s) members should be synced to another group
 #
 # key: the name of the group the members to be synced *to* (see $groupIds below)
 # value: a hash map with the two optional key:
 #     domainWhitelist: string|string[] of allowed domains of the UserPrincipalName
 #         all members will be filtered out and removed
 #         if empty members will not be filtered
 #     sources: string|string[] of group name(s) the members to be synced *from* (see $groupIds below)
 #         if empty defaults to the target group itself; useful to only apply the domainWhitelist
 #
 # if the order of processing is important $syncMapping needs to be [ordered]
 #>
$syncMapping = [ordered]@{
    <# examples
    # filter for internal accounts only
    "Group 1" = @{domainWhitelist = "bdsu.de"}

    # sync all members from "Group 1" and "Distribution List 2" into "Teams Group 3"
    "Teams Group 3" = @{sources = "Group 1","Distribution List 2"}
    #>
}

<##
 # map human-readable group names to their ObjectId
 #
 # key: human-readable, unique name of the group to be used in $syncMapping
 #     this can be chosen freely and does not need to be equal to e.g. the DisplayName
 #     it only needs to be consistent within this script and is used for debugging output
 # value: the ObjectId of the group
 #     you can find it in the AzureAD admin portal or via Get-AzureADGroup
 #>
$groupIds = @{
    <# examples
    "Group 1" = "12345678-90ab-4cde-f123-000000000001"
    "Distribution List 2" = "12345678-90ab-4cde-f123-000000000002"
    "Teams Group 3" = "12345678-90ab-4cde-f123-000000000003"
    #>
}

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

Connect-AzureAD -Credential $credentials | Out-Null

# remove existing Exchange Remote Sessions if any
Get-PSSession | Where-Object {$_.ComputerName -eq "outlook.office365.com"} | Remove-PSSession

$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $credentials -Authentication Basic -AllowRedirection
Import-PSSession $session
if (!$?) {
    throw "Failed to import Exchange Remote Session"
}

<##
 # a null-safe wrapper around Compare-Object
 #
 # Compare-Object can't handle $null values and it is RIDICULOUSLY cumbersome to
 # simply cast $null values to an empty array in powershell
 #>
function Compare-ObjectNullSafe($ReferenceObject, $DifferenceObject) {
    if ($ReferenceObject -eq $null) {
        $ReferenceObject = @()
    }
    if ($DifferenceObject -eq $null) {
        $DifferenceObject = @()
    }

    return Compare-Object -ReferenceObject $ReferenceObject -DifferenceObject $DifferenceObject
}

<##
 # verify the config for consistency and bail out if anything smells fishy
 #
 # checks that every group name used in $syncMapping is mapped in $groupIds and
 # that every group in $groupIds exists in AzureAD
 #>
function Check-Config($syncMapping, $groupIds) {
    Write-Host "Checking configuration"

    $usedGroupNames = $syncMapping.GetEnumerator() | ForEach-Object {
        $_.Name
        $_.Value.sources
    } | sort -Unique

    $mappedGroupNames = [array]$groupIds.Keys

    $diff = Compare-ObjectNullSafe -ReferenceObject $usedGroupNames -DifferenceObject $mappedGroupNames

    if ($diff) {
        Write-Warning 'There are groups in $syncMapping which are missing in $groupIds (<=) or unused groups in $groupIds (=>)'
        $diff | ft SideIndicator,InputObject
        throw "Cowardly refusing to continue with inconsistent configs"
    }

    $groupIds.GetEnumerator() | ForEach-Object {
        $group = Get-AzureADGroup -ObjectId $_.Value
        if (!$? -or !$group) {
            throw "Could not find group '$($_.Name)' with objectId $($_.Value) in AzureAD"
        }
    }
}

<##
 # determine the type of a group
 #
 # since the different group types all need to be handle differenty to update
 # their members we try to guess their type here
 # returns "Office365"|"Distribution"|"Security"
 #>
function Get-GroupType($groupName) {
    $group = Get-UnifiedGroup -Identity $groupIds[$groupName] -ErrorAction SilentlyContinue
    if ($group) {
        return "Office365"
    }

    $group = Get-DistributionGroup -Identity $groupIds[$groupName] -ErrorAction SilentlyContinue
    if ($group) {
        return "Distribution"
    }

    $group = Get-AzureADGroup -ObjectId $groupIds[$groupName] -ErrorAction SilentlyContinue
    if ($group -and $group.SecurityEnabled -and !$group.MailEnabled) {
        return "Security"
    }

    throw "Failed to detect group type of '$groupName' ($($groupIds[$groupName]))"
}

<##
 # get all members of a group
 #
 # returns array of AzureADUser
 #>
function Get-GroupMembers($groupName) {
    $groupType = Get-GroupType $groupName
    switch ($groupType) {
        "Distribution" {
            return Get-DistributionGroupMember -Identity $groupIds[$groupName] | Where-Object {
                # filter out nested groups and contacts
                $_.RecipientType -like "*User*"
            } | ForEach-Object {
                Get-AzureADUser -ObjectId $_.ExternalDirectoryObjectId
            }
        }
        "Office365" {
            # although group owners are always also members of the group they
            # are not always included in Get-UnifiedGroupLinks -LinkType Members ...
            [array]$members = Get-UnifiedGroupLinks -Identity $groupIds[$groupName] -LinkType Members
            [array]$members += Get-UnifiedGroupLinks -Identity $groupIds[$groupName] -LinkType Owners
            return $members.ExternalDirectoryObjectId | sort -Unique | ForEach-Object {
                Get-AzureADUser -ObjectId $_
            }
        }
        "Security" {
            return Get-AzureADGroupMember -ObjectId $groupIds[$groupName] | Where-Object {
                $_.ObjectType -eq "User"
            }
        }

        Default {
            throw "Unsupported group type $groupType"
        }
    }
}

<##
 # wrapper to add a user to a group
 #
 # we need to wrap this since each group type needs another cmdlet for adding
 #>
function Add-GroupMember($groupType, $groupName, $user) {
    switch ($groupType) {
        "Distribution" {
            Add-DistributionGroupMember -Identity $groupIds[$groupName] -Member $user.ObjectId -BypassSecurityGroupManagerCheck -Confirm:$false
        }
        "Office365" {
            Add-UnifiedGroupLinks -Identity $groupIds[$groupName] -LinkType member -Links $user.ObjectId -Confirm:$false
        }
        "Security" {
            Add-AzureADGroupMember -ObjectId $groupIds[$groupName] -RefObjectId $user.ObjectId
        }

        Default {
            throw "Unsupported group type $groupType"
        }
    }
}

<##
 # wrapper to remove a user from a group
 #
 # we need to wrap this since each group type needs another cmdlet for removing
 #>
function Remove-GroupMember($groupType, $groupName, $user) {
    switch ($groupType) {
        "Distribution" {
            Remove-DistributionGroupMember -Identity $groupIds[$groupName] -Member $user.ObjectId -BypassSecurityGroupManagerCheck -Confirm:$false
        }
        "Office365" {
            # if the member is also an owner we can not remove them; so we first have to drop owner status
            # since we don't actually care if the member was an owner before we just SilentlyContinue if not
            Remove-UnifiedGroupLinks -Identity $groupIds[$groupName] -LinkType Owners -Links $user.ObjectId -Confirm:$false -ErrorAction SilentlyContinue
            Remove-UnifiedGroupLinks -Identity $groupIds[$groupName] -LinkType Members -Links $user.ObjectId -Confirm:$false
        }
        "Security" {
            Remove-AzureADGroupMember -ObjectId $groupIds[$groupName] -MemberId $user.ObjectId
        }

        Default {
            throw "Unsupported group type $groupType"
        }
    }
}

<##
 # set the members of a group
 #
 # diffs the given members with the current ones
 # adds missing ones and removes everyone else
 #>
function Set-GroupMembers($groupName, $newMembers) {
    $currentMembers = Get-GroupMembers $groupName | sort -Unique DisplayName

    $diff = Compare-ObjectNullSafe -ReferenceObject $currentMembers -DifferenceObject $newMembers

    if (!$diff) {
        # no difference, nothing to do here
        return
    }

    $groupType = Get-GroupType $groupName

    $diff | Where-Object {$_.SideIndicator -eq "<="} | ForEach-Object {
        $user = $_.InputObject
        Write-Host "`tRemoving '$($user.DisplayName)' ($($user.UserPrincipalName))"
        Remove-GroupMember $groupType $groupName $user
    }

    $diff | Where-Object {$_.SideIndicator -eq "=>"} | ForEach-Object {
        $user = $_.InputObject
        Write-Host "`tAdding '$($user.DisplayName)' ($($user.UserPrincipalName))"
        Add-GroupMember $groupType $groupName $user
    }
}

Check-Config $syncMapping $groupIds

$syncMapping.GetEnumerator() | ForEach-Object {
    $targetGroup = $_.Name
    $domainWhitelist = $_.Value.domainWhitelist
    $sources = $_.Value.sources

    if (!$sources) {
        # if no sources specified default to the group itself
        # useful when you only want to apply the domain filter
        $sources = $targetGroup
    }

    Write-Host "Updating group '$targetGroup' from '$($sources -join "', '")'"

    $newMembers = $sources | ForEach-Object {
        Get-GroupMembers $_
    } | sort -Unique DisplayName

    if ($domainWhitelist) {
        $newMembers = $newMembers | Where-Object {
            ($_.UserPrincipalName -replace "^.*@","") -in $domainWhitelist
        }
    }

    Set-GroupMembers $targetGroup $newMembers
}