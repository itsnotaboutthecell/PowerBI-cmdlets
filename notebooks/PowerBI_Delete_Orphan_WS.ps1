Connect-PowerBIServiceAccount

$workSpaces = Get-PowerBIWorkspace -Scope Organization -Orphaned

write-host "Total orphaned workspaces: $($workSpaces.count)`n"

ForEach ($w in $workSpaces)
{
    echo $w.Id
    Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/groups/$($w.id)" -Method Delete
}
