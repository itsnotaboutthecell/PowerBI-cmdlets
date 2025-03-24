# Script variables
$domain = "test.onmicrosoft.com" # Domain address - ex. example.onmicrosoft.com
$owners = @('') # Object ID of security group owners
$experiences = @('') # An array of user group names to be created
$location = "US" # Geo location
$license = "a403ebcc-fae0-4ca2-8c8c-7a907fd6c235" # POWER_BI_STANDARD

$PasswordProfile = @{
    Password                      = "" # Password
    ForceChangePasswordNextSignIn = $true
}

# Function to check and install module if not present
function Install-ModuleIfNeeded {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force
    }
}

# Function to create a user profile
function New-UserProfile {
    param (
        [string]$experience,
        [int]$userIndex
    )

    return [PSCustomObject]@{
        DisplayName  = "$($experience) Demo User $($userIndex)"
        MailNickName = "$($experience)DemoUser$($userIndex)"
        Upn          = "$($experience).user$($userIndex)@$($domain)"
    }
}

# Function to add group owner
function Add-GroupOwner {
    param(
        [string]$groupId,
        [string]$owner
    )

    New-MgGroupOwner -GroupId $groupId -DirectoryObjectId $owner
}

# Function to create a new security group
function New-SecurityGroup {
    param (
        [string]$groupName,
        [string]$mailNickName,
        [array]$owners
    )

    # Check if the group already exists
    $existingGroup = Get-MgGroup -Filter "displayName eq '$($groupName)'" -ErrorAction SilentlyContinue

    if ($existingGroup) {
        Write-Output "'$($groupName)' already exists. No action taken."
        return $existingGroup.Id
    }
    else {
        # Create a new security group
        $group = New-MgGroup -DisplayName $groupName `
            -MailEnabled:$false `
            -MailNickName $mailNickName `
            -SecurityEnabled

        $groupId = $group.Id

        # Loop through each owner ID and add them to the group
        foreach ($owner in $owners) {
            Add-GroupOwner -groupId $groupId -owner $owner
        }

        return $groupId
    }
}

# Function to create users and add them to a group
function New-UsersAndAddToGroup {
    param (
        [string]$experience,
        [int]$numberOfUsers,
        [string]$groupId,
        [int]$startIndex = 0
    )

    for ($currentCount = 0; $currentCount -lt $numberOfUsers; $currentCount++) {
        
        $userIndex = $startIndex + $currentCount

        $userProfile = Create-UserProfile -experience $experience -userIndex $userIndex

        # Create the user
        $user = New-MgUser -UserPrincipalName $userProfile.Upn `
            -PasswordProfile $PasswordProfile `
            -DisplayName $userProfile.DisplayName `
            -MailNickName $userProfile.MailNickName `
            -AccountEnabled:$true -UsageLocation $location

        Set-MgUserLicense -UserId $user.Id -AddLicenses @{SkuId = $license } -RemoveLicenses @()

        New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
    }
}

# Ensure required modules are installed
$modules = @("Microsoft.Graph.Users", "Microsoft.Graph.Users.Actions", "Microsoft.Graph.Authentication", "Microsoft.Graph.Groups")
foreach ($module in $modules) { Ensure-Module -ModuleName $module }

# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All, Group.ReadWrite.All -UseDeviceAuthentication

foreach ($experience in $experiences) {

    $totalUsers = Read-Host -Prompt "Total number of users to create for $($experience)?"
    $numberOfUsers = [int]$totalUsers

    $totalGroups = Read-Host -Prompt "Total number of groups to create for $($experience)?"
    $numberOfGroups = [int]$totalGroups

    if ($numberOfGroups -eq 1) {

        $groupName = "$($experience) Capacity Group"
        $mailNickName = "$($experience)SecurityGroup"

        # Create a new security group and get its ID
        $groupId = Create-SecurityGroup -groupName $groupName -mailNickName $mailNickName -owners $owners

        # Create users and add them to the group
        New-UsersAndAddToGroup -experience $experience -numberOfUsers $numberOfUsers -groupId $groupId

    }
    else {

        $usersPerGroup = [math]::Ceiling($numberOfUsers / $numberOfGroups)

        for ($groupCount = 0; $groupCount -lt $numberOfGroups; $groupCount++) {

            $groupName = "$($experience) Capacity Group $($groupCount)"
            $mailNickName = "$($experience)SecurityGroup$($groupCount)"

            # Create a new security group and get its ID
            $groupId = Create-SecurityGroup -groupName $groupName -mailNickName $mailNickName -owners $owners

            # Create users and add them to the group with appropriate start index
            New-UsersAndAddToGroup  -experience $experience `
                -numberOfUsers ([math]::Min($usersPerGroup, ($numberOfUsers - ($groupCount * $usersPerGroup)))) `
                -groupId $groupId `
                -startIndex ($groupCount * $usersPerGroup)
        }
    }
}

Disconnect-MgGraph
