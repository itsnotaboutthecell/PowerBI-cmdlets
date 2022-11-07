$outPath = "C:\"

#########################################

# Azure AD module: https://learn.microsoft.com/powershell/module/azuread/?view=azureadps-2.0
$m = "AzureAD"

try {Import-Module $m -ErrorAction Stop} 
catch {Install-Module -Name $m -Scope CurrentUser -Force} 
finally {Import-Module $m}

Connect-AzureAD

if ($outPath.Substring($outPath.Length - 1, 1) -cne "\") { $outPath = $outPath + "\" }
if (!(Test-Path $outPath)) { New-Item -ItemType Directory -Force -Path $outPath }

# Power BI Licensing Types and Capabilities Official Docs: https://docs.microsoft.com/power-bi/admin/service-admin-licensing-organization#license-types-and-capabilities
# For a complete listing of all Licensing Service Plans visit: https://docs.microsoft.com/azure/active-directory/enterprise-users/licensing-service-plan-reference

$licenseType = "POWER_BI_STANDARD","POWER_BI_ADDON","PBI_PREMIUM_P1_ADDON","PBI_PREMIUM_PER_USER","PBI_PREMIUM_PER_USER_ADDON","PBI_PREMIUM_PER_USER_DEPT","POWER_BI_PRO","POWER_BI_PRO_CE","POWER_BI_PRO_DEPT"

$allUsers = Get-MsolUser -All | where {$_.isLicensed -eq "True"}

foreach ($license in $licenseType) {

    $licenses = $allUsers | Where-Object {($_.licenses).AccountSkuId -match ($license)}

    Write-Host "Now Exporting Report: $($license)"
    $licenses | Export-Csv -Path "$($outPath)$($license)_$(Get-Date -Format "yyyyMMdd").csv" -NoTypeInformation

}
