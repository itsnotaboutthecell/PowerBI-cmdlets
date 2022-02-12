Connect-PowerBIServiceAccount

$ws = Get-PowerBIWorkspace -Scope Organization -Orphaned

write-host "Total orphaned workspaces: $($ws.count)`n"

ForEach ($orphan in $ws)
{
    write-host $orphan.Id
    Invoke-PowerBIRestMethod -Url 'https://api.powerbi.com/v1.0/myorg/groups/$($orphan.id)' -Method Delete
}
