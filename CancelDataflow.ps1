# Connect to Power BI service account
Connect-PowerBIServiceAccount

# Prompt user for workspace name
$workspaceName = Read-Host "What is the workspace name?"

# Get workspace details
$workspaceDetails = Get-PowerBIWorkspace -Scope Individual -Filter "tolower(name) eq '$($WorkspaceName.ToLower())'"

$workSpaceUrl = "https://api.powerbi.com/v1.0/myorg/groups/$($WorkspaceDetails.Id)"

# Get dataflow details
$dataflowDetails = Get-PowerBIDataflow -WorkspaceId $WorkspaceDetails.Id

# Iterate through each dataflow
foreach ($dataflow in $dataflowDetails) {

    # Get transactions for the dataflow
    $transactions = Invoke-PowerBIRestMethod -Url "$($workSpaceUrl)/dataflows/$($dataflow.Id)/transactions" -Method GET | ConvertFrom-Json

    # Iterate through each transaction
    foreach ($transaction in $transactions.value) {

        # Check if transaction is in progress
        if ($transaction.status -eq 'InProgress') {
            
            # Prompt user to cancel transaction
            $confirm = Read-Host "Cancel the in progress refresh for dataflow: $($dataflow.Name) | transaction id: $($transaction.id) - (Y/N)"
            
            # If user confirms, cancel transaction
            if ($confirm.ToLower() = "y") {

                Invoke-PowerBIRestMethod -Url "$($workSpaceUrl)/dataflows/transactions/$($transaction.id)/cancel" -Method POST

            }
        }
    }
}
