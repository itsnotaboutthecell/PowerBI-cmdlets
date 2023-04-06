$datasetId = '<set your id here>'
$url = 'https://api.powerbi.com/v1.0/myorg/datasets/$($datasetId)/executeQueries'
$body = @{
    queries = @(
        @{
            query = "EVALUATE <dax query here>"
        }
    )
} | ConvertTo-Json

Connect-PowerBIServiceAccount

Invoke-PowerBIRestMethod -Url $url -Method Post -Body $body
