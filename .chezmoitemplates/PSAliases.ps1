{{ if eq .chezmoi.os "windows" }}
if (Get-Command -Name scoop -ErrorAction SilentlyContinue) {
    $scoop_root = $(scoop config).root_path
    $scoop_shims = $(scoop shim list)

    function get_scoop_app_path {
        param (
            [string]$shim
        )

        $app_name = ($scoop_shims | Where-Object {$_.Type -eq "Application" -and $_.Name -eq $shim}).Source
        return ("{0}\apps\{1}\current" -f $scoop_root, $app_name)
    }
}

if ((Get-Command -Name scoop -ErrorAction SilentlyContinue) -and ($PSVersionTable.PSEdition -ne "Desktop")) {
    $tools = @{
        "cat" = "bat"
        "curl" = "curl"
        "diff" = "delta"
    }
    $tools.Keys | ForEach-Object {
        $tool = $tools.$_
        $scoop_shim = $scoop_shims | Where-Object {$_.Name -eq $tool}
        if ($scoop_shim) {
            Set-Alias -Name $_ -Value $scoop_shim.Path -Force
        }
    }
}

if (Get-Command -Name bat -ErrorAction SilentlyContinue) {
    $env:BAT_CONFIG_PATH = "$($env:USERPROFILE)\.config\bat\config"
}

if ($scoop_shims | Where-Object {$_.Name -eq "privoxy"}) {
    function privoxy_start {
        param (
            [string]$config_file
        )

        Push-Location
        cd (get_scoop_app_path "privoxy")
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

if ($scoop_shims | Where-Object {$_.Name -eq "wsl-ssh-agent-gui"}) {
    "$(get_scoop_app_path "wsl-ssh-agent-gui")\wsl-ssh-agent-gui -socket $env:USERPROFILE.\.keepassxc.sock" | Invoke-Expression
}
{{- end -}}
