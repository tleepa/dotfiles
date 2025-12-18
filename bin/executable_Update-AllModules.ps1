[CmdletBinding()]
param (
    [switch] $Noop
)

$Modules = Get-InstalledModule | Where-Object { $_.Name -notmatch '^Az\.' -and $_.Name -notmatch 'VMWare\.' -or $_.Name -match 'VMWare\.PowerCLI' }
# $Modules.Count

if (Get-InstalledModule -Name 'Az.Tools.Installer') {
    Write-Host "Processing AZ modules..."
    Update-AzModule -Repository PSGallery -WhatIf:$Noop
} else {
    $Modules += Get-InstalledModule | Where-Object { $_.Name -eq 'Az' }
}

Write-Host "Processing modules..."
$Modules | ForEach-Object {
    $ModName = $_.Name
    Write-Progress -Activity $ModName -PercentComplete (($Modules.IndexOf($_) + 1) / $Modules.Count * 100)
    Update-Module -Name $ModName -Scope CurrentUser -WhatIf:$Noop
}
