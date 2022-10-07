{{ if eq .chezmoi.os "windows" }}
if ((Get-Command -Name scoop -ErrorAction SilentlyContinue) -and ($PSVersionTable.PSEdition ne "Desktop")) {
    $tools = @{
        "cat" = "bat"
        "curl" = "curl"
        "diff" = "delta"
    }
    $tools.Keys | ForEach-Object {
        $scoop_shim = $(scoop shim list $tools.$_)
        if ($scoop_shim) {
            Set-Alias -Name $_ -Value $scoop_shim.Path -Force
        }
    }
}

if (Get-Command -Name bat -ErrorAction SilentlyContinue) {
    $env:BAT_CONFIG_PATH = "$($env:USERPROFILE)\.config\bat\config"
}

if (scoop shim list privoxy) {
    function privoxy_start {
        param (
            [string]$config_file
        )

        Push-Location
        cd $(scoop prefix privoxy)
        if (Test-Path -Path "conf.d\$config_file") {
            $config_file = "conf.d\$config_file"
        }
        elseif (!(Test-Path -Path $config_file)) {
            Write-Error "$($config_file) not found in either app root or conf.d directory"
            Pop-Location
            break
        }
        Start-Job -ScriptBlock { privoxy -config $using:config_file } | Out-Null
        Pop-Location
    }
}
{{- end -}}
