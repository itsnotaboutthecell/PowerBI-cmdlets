Connect-PowerBIServiceAccount

### Orphaned workspaces are workspaces that don't have anyone in the access list (no ownership)

$workSpaces = Get-PowerBIWorkspace -Scope Organization -Orphaned

$adminEmail = "<ENTER ADMIN EMAIL ADDRESS/UPN>"

write-host "Total orphaned workspaces: $($workSpaces.count)`n"

ForEach ($w in $workSpaces)
{
    ### In order to delete the orphaned workspace, we need to have admin rights to it. Right now
    ### there are no owners of the workspace, so a delete will fail with a 401 (Unauthorized)
    ### if we do nothing. This is because there is no Admin API for deleting a workspace.

    echo $w.Id

    ### Add an Admin of the workspace
    Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/admin/groups/$($w.id)/users" -Method Post -Body "{ 'emailAddress': '$adminEmail', 'groupUserAccessRight': 'Admin' }"

    ### Delete the workspace
    Invoke-PowerBIRestMethod -Url "https://api.powerbi.com/v1.0/myorg/groups/$($w.id)" -Method Delete
}
