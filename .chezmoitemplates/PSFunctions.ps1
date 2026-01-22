{{ if eq .chezmoi.os "windows" }}
if ((Get-Command -Name "scoop" -ErrorAction SilentlyContinue)) {

    function sus {
        scoop update
        scoop status
    }

    function sua {
        scoop update -a
        scoop cleanup -a
        scoop cache rm -a
    }
}

{{ end -}}

function _resolvePaths {
    $parsed_args = @()
    $args | ForEach-Object {
        if ($_ -match "\*" -or $_ -match "~") {
            Resolve-Path $_ | ForEach-Object {
                $parsed_args += $_
            }
        } else {
            $parsed_args += $_
        }
    }
    return $parsed_args
}

function _expandBraces {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Pattern
    )

    if ($Pattern -match '(.*?)\{([^}]+)\}(.*)') {
        $prefix = $matches[1]
        $options = $matches[2] -split ','
        $suffix = $matches[3]

        $results = @()
        foreach ($option in $options) {
            $expanded = $prefix + $option.Trim() + $suffix
            $results += _expandBraces $expanded
        }
        return $results
    } else {
        return @($Pattern)
    }
}

function export {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $EnvVar
    )

    try {
        $sepPosition = $EnvVar.IndexOf("=")
        foreach ($envName in (_expandBraces $EnvVar.Substring(0, $sepPosition))) {
            $envValue = $EnvVar.Substring($sepPosition + 1, $EnvVar.Length - ($sepPosition + 1)).Trim() -replace '\$(?!env:)([a-zA-Z_][a-zA-Z0-9_]*)', '$env:$1'
            while ($envValue -match '\$env:([a-zA-Z_][a-zA-Z0-9_]*)') {
                $varName = $matches[1]
                $varValue = [Environment]::GetEnvironmentVariable($varName, 'Process')
                if (!$varValue) {
                    $varValue = Get-Variable -Name $varName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value
                }
                if ($null -ne $varValue) {
                    $envValue = $envValue -replace "\`$env:$varName", $varValue
                } else {
                    $envValue = $envValue -replace "\`$env:$varName", ""
                    Write-Warning "Variable '$varName' is not set, using empty value"
                    break
                }
            }
            [Environment]::SetEnvironmentVariable($envName, $(_resolvePaths $envValue), "Process")
            Write-Debug "export $envName=$envValue"
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}

function unset {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $EnvVar
    )

    try {
        foreach ($envName in (_expandBraces $EnvVar)) {
            [Environment]::SetEnvironmentVariable($envName, [NullString]::Value, "Process")
            Write-Debug "unset $envName"
        }
    } catch {
        Write-Error $_.Exception.Message
    }
}

function source {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $FilePath
    )

    try {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content $FilePath | Where-Object { $_ -notmatch "^#" -and $_ -ne "" } | ForEach-Object {
                        "{0} '{1}';" -f ($_ -replace "^(export|unset)\s+(.*)", '$1'), ($_ -replace "^(export|unset)\s+(.*)", '$2')
                    })))
    } catch {
        Write-Error $_.Exception.Message
    }
}

function unsource {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $FilePath
    )

    try {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content $FilePath | Where-Object { $_ -notmatch "^#" -and $_ -ne "" } | ForEach-Object {
                        if ($_ -match "^export") {
                            "unset '{0}';" -f ($_ -replace "^export\s+(.*?)=(.*)", '$1')
                        }
                    })))
    } catch {
        Write-Error $_.Exception.Message
    }
}

if ((Get-Command -Name "eza" -ErrorAction SilentlyContinue)) {
    $DEFAULT_EZA_ARGS = @(
        "--color-scale=all",
        "--group-directories-first"
    )

    function _ls {
        eza @DEFAULT_EZA_ARGS @(_resolvePaths @args)
    }

    function la {
        _ls -ablg --icons @args
    }

    function ll {
        _ls -blg --icons @args
    }

    function lt {
        _ls -T @args
    }

    function llt {
        ll -T @args
    }

    function lat {
        la -T @args
    }

    function llg {
        ll --git @args
    }

    function lag {
        la --git @args
    }

    Set-Alias -Name ls -Value _ls -Force -Option AllScope
}

if ((Get-Module -Name 'Microsoft.PowerShell.ConsoleGuiTools' -ListAvailable) -and (Get-Module -Name 'Az.Accounts' -ListAvailable)) {
    function Set-AzSub {
        Get-AzSubscription | Out-ConsoleGridView -OutputMode Single | Select-AzSubscription
    }
}

function Get-Char {
    param (
        [Parameter(Mandatory = $true, HelpMessage = "Single character only")]
        [ValidateLength(1, 1)]
        [String] $Str
    )

    $utf32bytes = [System.Text.Encoding]::UTF32.GetBytes($Str)
    $codePoint = [System.BitConverter]::ToUint32($utf32bytes)
    "0x{0:X}" -f $codePoint
}

function Get-SshSessions {
    Get-Process | Where-Object { $_.Name -eq 'ssh' -and $_.CommandLine -match 'ssh' } `
    | Select-Object -Property Id, Name, CommandLine
}

function Load-PSResourceGetModule {
    $prgModuleName = "Microsoft.PowerShell.PSResourceGet"
    $prgModule = Get-Module -Name $prgModuleName -ListAvailable -ErrorAction SilentlyContinue
    if ($prgModule) {
        $prgInstalledVersion = $prgModule | Sort-Object -Property Version | Select-Object -Last 1 | Select-Object -ExpandProperty Version
    } else {
        $prgInstalledVersion = [Version]"0.0.0"
    }
    $prgRequiredVersion = [System.Management.Automation.SemanticVersion]"1.2.0-rc1"
    if ($prgInstalledVersion -lt $prgRequiredVersion) {
        $prgGalleryVersion = Find-PSResource -Name $prgModuleName | Select-Object -ExpandProperty Version
        $installArgs = @{
            Name   = $prgModuleName
            Scope  = 'CurrentUser'
            Force  = $true
            WhatIf = $false
        }
        if ($prgGalleryVersion -lt $prgRequiredVersion) {
            $installArgs.AllowPrerelease = $true
        }
        Install-Module @installArgs
    }
    Import-Module -Name $prgModuleName -Force
}

function Update-AllModules {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Load-PSResourceGetModule

    $Modules = Get-InstalledModule | Select-Object -ExpandProperty Name | Sort-Object -Unique
    $ModulesToUpdate = $Modules

    if ($Modules -match "^Az\." -and ($Modules -match "Az\.").Count -gt 1) {
        $ModulesToUpdate = $ModulesToUpdate | Where-Object { $_ -notmatch "^Az\." }
        if (Get-InstalledModule -Name "Az.Tools.Installer" -ErrorAction SilentlyContinue) {
            Write-Host "Processing Az.* modules..."
            Update-AzModule -WhatIf:$WhatIfPreference
        } else {
            if ($ModulesToUpdate -notcontains "Az") {
                $ModulesToUpdate += "Az"
            }
        }
    }

    if ($Modules -match "^VMWare\.") {
        $ModulesToUpdate = $ModulesToUpdate | Where-Object { $_ -notmatch "^VMWare\." }
        $ModulesToUpdate += "VMWare.PowerCLI"
    }

    if ($Modules -match "^Microsoft.Entra") {
        $ModulesToUpdate = $ModulesToUpdate | Where-Object { $_ -notmatch "^Microsoft.Entra" }
        $ModulesToUpdate += "Microsoft.Entra"
    }

    Write-Host "Processing modules $($ModulesToUpdate -join ", ")..."
    if ($ModulesToUpdate.Count -eq 0) {
        Write-Host "No modules to update."
        return
    } else {
        Update-PSResource -Name $ModulesToUpdate -TrustRepository -Force -WhatIf:$WhatIfPreference
    }
}

function Cleanup-AllModules {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    Load-PSResourceGetModule

    $Modules = Get-Module -ListAvailable
    $InstalledModules = Get-InstalledModule
    $UserModulePaths = $InstalledModules | ForEach-Object { $_.InstalledLocation } | Sort-Object -Unique

    $Modules = $Modules | Where-Object {
        $modulePath = $_.ModuleBase
        $UserModulePaths | Where-Object { $modulePath -match "^$_" }
    }

    $ModuleNames = $Modules |
        Select-Object -ExpandProperty Name |
        Sort-Object -Unique

    Write-Host "Processing modules..."
    $ModuleNames |
        ForEach-Object -ThrottleLimit 10 -Parallel {
            $ModName = $_
            Write-Progress -Activity $ModName -PercentComplete (($($using:ModuleNames).IndexOf($_) + 1) / $($using:ModuleNames).Count * 100)
            $Using:Modules | Where-Object { $_.Name -eq $ModName } |
                Sort-Object -Property Version |
                Select-Object -SkipLast 1 |
                ForEach-Object {
                    if ($using:WhatIfPreference) {
                        Write-Host "What if: Performing the operation 'Uninstall-PSResource' on target '$ModName', version: '$($_.Version)'"
                    } else {
                        Write-Host "Uninstalling module: '$ModName', version: '$($_.Version)'"
                    }
                    Uninstall-PSResource -Name $ModName -Version $_.Version -SkipDependencyCheck -WarningAction SilentlyContinue -WhatIf:$using:WhatIfPreference
                }
            }
}
