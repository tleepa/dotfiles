[CmdletBinding()]
param (
    [switch] $Noop
)

if (Get-InstalledModule -Name 'Az.Tools.Installer') {
    $Modules = Get-InstalledModule | Where-Object { $_.Name -notmatch '^Az' }
} else {
    $Modules = Get-InstalledModule
}

Write-Host "Processing modules..."
$Modules | ForEach-Object {
    $ModName = $_.Name
    Write-Progress -Activity $ModName -PercentComplete (($Modules.IndexOf($_) + 1) / $Modules.Count * 100)
    $CurModule = Get-InstalledModule -Name $ModName -AllVersions | Sort-Object -Property Version -Descending

    if ($CurModule.length -gt 1) {
        $CurModule[1..$CurModule.Length] | ForEach-Object {
            Uninstall-Module -Name $ModName -RequiredVersion $_.Version -WhatIf:$Noop
        }
    }
}
