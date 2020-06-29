# Declare Variables
$outPath = "C:\Power BI\Activity Logs\'
$senderAddress = 'email@domain.com'
 
# Gets Previous X Days Events – Max Value 89
$offsetDays = 7
 
$pbiEvents = # Create
                'CreateReport', 'CreateDataset', 'CreateDashboard',
             # Read
                'ShareDashboard','ShareReport',
             # Update
                 'EditReport', 'EditDataset', 'EditDashboard', 'RefreshDataset', 'SetScheduledRefresh',
             # Delete
                 'DeleteReport', 'DeleteDataset', 'DeleteDashboard'
 
############### SCRIPT BEGINS ###############
Connect-PowerBIServiceAccount # -ServicePrincipal -Credential (Get-Credential)
 
# Erorr Handling: outPath - Final character is forward slash and folder exists
if ($outPath.Substring($outPath.Length - 1, 1) -cne "\") { $outPath = $outPath + "\" } 
if (!(Test-Path $outPath)) { New-Item -ItemType Directory -Force -Path $outPath }
 
# Get Active Power BI v1 Workspaces
$pbiWorkspaces = Get-PowerBIWorkspace -Scope Organization -Filter "type eq 'Group'" | Where-Object {$_.State -eq "Active"} | select-object -property @{N='WorkspaceId';E={$_.Id}}, Name, isReadOnly, isOnDedicatedCapacity, CapacityId, Description, Type, State, IsOrphaned
$pbiWorkspaces | Export-Csv -Path "$($outpath)v1_Workspaces.csv" -NoTypeInformation
Write-Host "Total Number of Workspaces Being Evaluated: $($pbiWorkspaces.Count)`n"
 
# Iterates Offset Date Range
For ($i = 1; $i -le $offsetDays; $i+=1) { 
    $startEvent = ((Get-Date).AddDays(-$i).ToString("yyyy-MM-ddT00:00:00"))
    $endEvent = ((Get-Date).AddDays(-$i).ToString("yyyy-MM-ddT23:59:59"))
 
ForEach ( $activity in $pbiEvents ) {
 
    $pbiActivities = Get-PowerBIActivityEvent -StartDateTime $startEvent -EndDateTime $endEvent -ActivityType $activity | ConvertFrom-Json
    Write-Host "Evaluating $($startEvent.Substring(0,10)): $($activity) - $($pbiActivities.Count) Total Activities"
 
        if ($pbiActivities.Count -ne 0) {
            Compare-Object $pbiActivities -DifferenceObject $pbiWorkspaces -Property 'WorkspaceId' -IncludeEqual -ExcludeDifferent -PassThru |
            ForEach ` { 
                $_ | Select * -ExcludeProperty SideIndicator
            } | Where-Object {$_.RecordType -ne $null} | Export-Csv -Path "$($outpath)Power_BI_V1_Activity_Logs.csv" -NoTypeInformation -Force -Append
    }}}
 
Disconnect-PowerBIServiceAccount
 
############### E-MAIL BLASTER BEGINS ###############
 
if ($outPath.Substring($outPath.Length - 1, 1) -cne "\") { $outPath = $outPath + "\" } 
 
$existingWorkspaces = Import-CSV -Path "$($outPath)v1_Workspaces.csv"
$v1Activities = Import-Csv -Path "$($outPath)\Power_BI_V1_Activity_Logs.csv"
$V1Users = $v1Activities | Select UserId -Unique
 
#Get an Outlook application object
$o = New-Object -com Outlook.Application
 
ForEach ($v1User in $V1Users) {
 
    $V1Workspaces = $v1Activities | Select UserId, WorkSpaceName, WorkspaceId -Unique | Where-Object {$_.UserId -eq $v1User.UserId}
 
    if ($V1Workspaces.Count -ne 0) {
 
        $mail = $o.CreateItem(0)
 
        $mail.Sender= $senderAddress
        $mail.To = $v1User.UserId
        $mail.Subject = 'Action Required: Upgrade Power BI Workspace(s)'
        $mail.HtmlBody = (Compare-Object -ReferenceObject $existingWorkspaces -DifferenceObject $V1Workspaces -Property 'WorkspaceId' -IncludeEqual -ExcludeDifferent -PassThru |
                ForEach ` { $_ | Select Name, WorkspaceId, @{l="URL";e={"https://ddec1-0-en-ctp.trendmicro.com:443/wis/clicktime/v1/query?url=https%3a%2f%2fapp.powerbi.com%2fgroups%2f&umid=874631f4-a2ec-49b0-86ed-9e5bb484c040&auth=65a620fa4b6e2edf0405a6ed61dc7465231096cd-5450d311e70f7751b1de5436ba6c3e3f8e20330b$($_.WorkspaceId)"}}} | 
                ConvertTo-HTML -Title 'Power BI Workspace Upgrade' -Body "The following Power BI workspace(s) are currently out of compliance. Please visit the URL(s) below to upgrade now.<br><br>For instructions on how to upgrade classic workspaces to the new workspace experience, <a href=https://ddec1-0-en-ctp.trendmicro.com:443/wis/clicktime/v1/query?url=https%3a%2f%2fdocs.microsoft.com%2fen%2dus%2fpower%2dbi%2fdesigner%2fservice%2dupgrade%2dworkspaces%3eclick&umid=8a3e0ca7-9b90-481c-a86d-52d6842b1c29&auth=65a620fa4b6e2edf0405a6ed61dc7465231096cd-cc0518f527e63f63f3164e539d3a098b70f9c03d here</a> to learn more.<br><br>" -PostContent "<br>Thank you in advance for your time and assistance." | Out-String )
        $mail.Importance = 2
 
        $mail.Send()
 
        # give time to send the email
        Start-Sleep 20
 
    }
}
# quit Outlook and exit script
$o.Quit()
exit 
