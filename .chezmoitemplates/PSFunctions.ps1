{{ if eq .chezmoi.os "windows" -}}
function source {
    param (
        [Parameter(Mandatory, Position = 0)]
        [string] $Path
    )

    try {
        Invoke-Command -ScriptBlock ([ScriptBlock]::Create((Get-Content $Path | Where-Object { $_ -notmatch "^#" -and $_ -ne "" } | ForEach-Object { $_ + ";" })))
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
        eza @DEFAULT_EZA_ARGS @args
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

    function llg {
        ll --git @args
    }

    function lag {
        la --git @args
    }

    Set-Alias -Name ls -Value _ls -Force -Option AllScope
}

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
