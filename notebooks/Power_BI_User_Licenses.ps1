$outPath = "C:\temp"

#########################################

# Azure AD module: https://learn.microsoft.com/powershell/module/azuread/?view=azureadps-2.0
$m = "Microsoft.Graph"

try { Import-Module $m -ErrorAction Stop } 
catch { Install-Module -Name $m -Scope CurrentUser -Force } 
finally { Import-Module $m }

if ($outPath.Substring($outPath.Length - 1, 1) -cne "\") { $outPath = $outPath + "\" }
if (!(Test-Path $outPath)) { New-Item -ItemType Directory -Force -Path $outPath }

Connect-Graph -Scopes Organization.Read.All

# Power BI Licensing Types and Capabilities Official Docs: https://docs.microsoft.com/power-bi/admin/service-admin-licensing-organization#license-types-and-capabilities
# For a complete listing of all Licensing Service Plans visit: https://docs.microsoft.com/azure/active-directory/enterprise-users/licensing-service-plan-reference

$pbiSubscriptions = Get-MgSubscribedSku | Select -Property Sku*, ConsumedUnits -ExpandProperty PrepaidUnits | Where-Object { ($_.SkuPartNumber.contains("POWER_BI") -or $_.SkuPartNumber.contains("PBI")) }
$pbiSubscriptions | Format-List

$licenseType = $pbiSubscriptions | Select SkuPartNumber

# Graph licensing search: https://learn.microsoft.com/microsoft-365/enterprise/view-licensed-and-unlicensed-users-with-microsoft-365-powershell?view=o365-worldwide

foreach ($license in $licenseType) {

    $licenseName = $license.SkuPartNumber
    Write-Host "Now Searching: $($licenseName)"
    $licenses = Get-MgSubscribedSku -All | Where SkuPartNumber -eq $licenseName
    $licenses | Select -Property Id, Sku*, CapabilityStatus, ConsumedUnits

    if ($licenses.ConsumedUnits -ne 0) {

        Write-Host "Now Exporting Report: $($licenseName)`n"
        $licenses | Export-Csv -Path "$($outPath)$($licenseName)_$(Get-Date -Format "yyyyMMdd").csv" -NoTypeInformation

    }

}
