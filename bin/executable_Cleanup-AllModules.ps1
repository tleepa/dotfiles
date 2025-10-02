[CmdletBinding()]
param (
    [switch] $Noop
)

$Modules = Get-InstalledModule

Write-Host "Processing modules..."
$Modules | ForEach-Object -ThrottleLimit 10 -Parallel {
    $ModName = $_.Name
    Write-Progress -Activity $ModName -PercentComplete (($($using:Modules).IndexOf($_) + 1) / $($using:Modules).Count * 100)
    $CurModule = Get-InstalledModule -Name $ModName -AllVersions | Sort-Object -Property Version -Descending | Select-Object -SkipLast 1 | ForEach-Object {
        Uninstall-Module -Name $ModName -RequiredVersion $_.Version -Force -WhatIf:$using:Noop
    }
}

