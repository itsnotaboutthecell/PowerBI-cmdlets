$outPath = 'C:\temp'

# Azure AD module: https://learn.microsoft.com/powershell/module/azuread/?view=azureadps-2.0
$m = 'Microsoft.Graph'

try {
    Import-Module $m -ErrorAction Stop
}
catch {
    Install-Module -Name $m -Scope CurrentUser -Force
}
finally {
    Import-Module $m
}

if (!$outPath.EndsWith('\')) {
    $outPath += '\'
}

if (!(Test-Path $outPath -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outPath
}

Connect-Graph -Scopes Organization.Read.All -UseSSL -Credential (Get-Credential)

# Power BI Licensing Types and Capabilities Official Docs: https://docs.microsoft.com/power-bi/admin/service-admin-licensing-organization#license-types-and-capabilities
# For a complete listing of all Licensing Service Plans visit: https://docs.microsoft.com/azure/active-directory/enterprise-users/licensing-service-plan-reference

$pbiSubscriptions = Get-MgSubscribedSku -Filter "SkuPartNumber eq 'POWER_BI' or SkuPartNumber eq 'PBI'" | 
                    Select-Object Sku*, ConsumedUnits, @{Name='PrepaidUnits';Expression={$_.PrepaidUnits}}
$pbiSubscriptions | Format-List

$licenseType = $pbiSubscriptions | Select-Object -ExpandProperty SkuPartNumber

# Graph licensing search: https://learn.microsoft.com/microsoft-365/enterprise/view-licensed-and-unlicensed-users-with-microsoft-365-powershell?view=o365-worldwide

$licenseType | ForEach-Object {
    $licenseName = $_
    Write-Host "Now Searching: $licenseName"
    $licenses = Get-MgSubscribedSku -Filter "SkuPartNumber eq '$licenseName'"
    $licenses | Select-Object Id, Sku*, CapabilityStatus, ConsumedUnits

    if ($licenses.ConsumedUnits -ne 0) {
        Write-Host "Now Exporting Report: $licenseName`n"
        $licenses | Export-Csv -Path ($outPath -Join "$licenseName" + '_' + (Get-Date -Format 'yyyyMMdd') + '.csv') -NoTypeInformation
    }
}
