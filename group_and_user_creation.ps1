# Script variables
$domain = "test.onmicrosoft.com" # Domain address - ex. example.onmicrosoft.com
$owner = '' # Object ID of security group owner
$experiences = @('') # An array of user groups to be created
$location = "US" # Geo location
$license = "a403ebcc-fae0-4ca2-8c8c-7a907fd6c235" # POWER_BI_STANDARD

$PasswordProfile = @{
    Password                      = "" # Password
    ForceChangePasswordNextSignIn = $true
}

# Function to check and install module if not present
function Ensure-Module {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Install-Module -Name $ModuleName -Scope CurrentUser -Force
    }
}

$modules = @("Microsoft.Graph.Users", "Microsoft.Graph.Users.Actions", "Microsoft.Graph.Authentication", "Microsoft.Graph.Groups")
foreach ($module in $modules) { Ensure-Module -ModuleName $module }

# Connect to Microsoft Graph
Connect-MgGraph -Scopes User.ReadWrite.All, Group.ReadWrite.All -UseDeviceAuthentication

function Create-UserProfile {
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

foreach ($experience in $experiences) {

    $totalUsers = Read-Host -Prompt "Total number of users to create for $($experience)?"
    $numberOfUsers = [int]$totalUsers

    $totalGroups = Read-Host -Prompt "Total number of groups to create for $($experience)?"
    $numberOfGroups = [int]$totalGroups

    if ($numberOfGroups -eq 1) {

        $groupName = "$($experience) Capacity Group"
        $mailNickName = "$($experience)SecurityGroup0"

        # Check if the group already exists
        $existingGroup = Get-MgGroup -Filter "displayName eq '$($groupName)'" -ErrorAction SilentlyContinue

        if ($existingGroup) {
            Write-Output "'$($groupName)' already exists. No action taken."
        } else {
            # Create a new security group
            $group = New-MgGroup -DisplayName $groupName `
                                 -MailEnabled:$false ` 
                                 -MailNickName $mailNickName `
                                 -SecurityEnabled

            $groupId = $group.Id

            # Assign ownership to the Group
            New-MgGroupOwner -GroupId $groupId -DirectoryObjectId $owner

        }

        for ($currentCount = 0; $currentCount -lt $numberOfUsers; $currentCount++) {
            
            $userProfile = Create-UserProfile -experience $experience -userIndex $currentCount

            # Create the user
            $user = New-MgUser -UserPrincipalName $userProfile.Upn -PasswordProfile $PasswordProfile -DisplayName $userProfile.DisplayName -MailNickName $userProfile.MailNickName -AccountEnabled:$true -UsageLocation $location
            Set-MgUserLicense -UserId $user.Id -AddLicenses @{SkuId = $license } -RemoveLicenses @()

            New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
        }
    } else {

        $usersPerGroup = [math]::Ceiling($numberOfUsers / $numberOfGroups)

        for ($groupCount = 0; $groupCount -lt $numberOfGroups; $groupCount++) {

            $groupName = "$($experience) Capacity Group $($groupCount)"

            # Check if the group already exists
            $existingGroup = Get-MgGroup -Filter "displayName eq '$($groupName)'" -ErrorAction SilentlyContinue

            if ($existingGroup) {
                Write-Output "'$($groupName)' already exists. No action taken."
            } else {
                # Create a new security group
                $group = New-MgGroup -DisplayName $groupName `
                                     -MailEnabled:$false `
                                     -MailNickName "$($experience)SecurityGroup$($groupCount)" `
                                     -SecurityEnabled

                $groupId = $group.Id

                # Assign ownership to the Group
                New-MgGroupOwner -GroupId $groupId -DirectoryObjectId $owner
            }

            for ($currentCount = 0; $currentCount -lt $usersPerGroup; $currentCount++) {

                $userIndex = $groupCount * $usersPerGroup + $currentCount

                if ($userIndex -ge $numberOfUsers) { break }

                $userProfile = Create-UserProfile -experience $experience -userIndex $userIndex

                # Create the user
                $user = New-MgUser -UserPrincipalName $userProfile.Upn -PasswordProfile $PasswordProfile -DisplayName $userProfile.DisplayName -MailNickName $userProfile.MailNickName -AccountEnabled:$true -UsageLocation $location
                Set-MgUserLicense -UserId $user.Id -AddLicenses @{SkuId = $license } -RemoveLicenses @()

                New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
            }
        }
    }
}

Disconnect-MgGraph
