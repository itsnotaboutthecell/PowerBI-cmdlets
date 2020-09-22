$outPath = "C:\"

#########################################

$modules = "MSOnline"

foreach ( $m in $modules ) 
{
    try {Import-Module $m -ErrorAction Stop} 
    catch {Install-Module -Name $m -Scope CurrentUser -Force} 
    finally {Import-Module $m}
}

Connect-MsolService

if ($outPath.Substring($outPath.Length - 1, 1) -cne "\") { $outPath = $outPath + "\" }
if (!(Test-Path $outPath)) { New-Item -ItemType Directory -Force -Path $outPath }

$licenseType = "Power_BI_Pro", "Power_BI_Standard"

$allUsers = Get-MsolUser -All | where {$_.isLicensed -eq "True"}

foreach ($license in $licenseType) {

    $licenses = $allUsers | Where-Object {($_.licenses).AccountSkuId -match ($license)}

    Write-Host "Now Exporting Report: $($license)"
    $licenses | Export-Csv -Path "$($outPath)$($license)_$(Get-Date -Format "yyyyMMdd").csv" -NoTypeInformation

}
