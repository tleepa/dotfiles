{{ if eq .chezmoi.os "windows" }}
if (Get-Command -Name scoop -ErrorAction SilentlyContinue) {
    $tools = @{
        "cat"  = "bat"
        "curl" = "curl"
        "diff" = "delta"
    }
    $tools.Keys | ForEach-Object {
        $tool = scoop which $tools.$_ 2> $null 6> $null
        if ($tool) {
            Set-Alias -Name $_ -Value $tool -Force -Option AllScope
        } else {
            $tool = scoop shim list $tools.$_
            if ($tool) {
                Set-Alias -Name $_ -Value $tool.Path -Force -Option AllScope
            }
        }
    }

    if (scoop which "privoxy" 6> $null) {
        function privoxy_start {
            param (
                [string]$config_file
            )

            Push-Location
            Set-Location $(scoop prefix "privoxy")
            if (Test-Path -Path "conf.d\$config_file") {
                $config_file = "conf.d\$config_file"
            } elseif (!(Test-Path -Path $config_file)) {
                Write-Error "$($config_file) not found in either app root or conf.d directory"
                Pop-Location
                break
            }
            Start-Job -ScriptBlock { privoxy -config $using:config_file } | Out-Null
            Pop-Location
        }
    }

    if ((scoop which "yazi" 6> $null) -and (scoop which "git" 6> $null)) {
        $git_dir = $(scoop prefix git)
        if (Get-Command -Name fd -ErrorAction SilentlyContinue) {
            $file_path = $(fd "file.exe" $git_dir)
            $env:YAZI_FILE_ONE = $file_path
        } else {
            $file_path = Get-ChildItem -Path $git_dir -Recurse -Name "file.exe"
            $env:YAZI_FILE_ONE = "$($git_dir)\$($file_path)"
        }
    }
}

if (Get-Command -Name bat -ErrorAction SilentlyContinue) {
    $env:BAT_CONFIG_PATH = "$($env:USERPROFILE)\.config\bat\config"
}

if (Get-Command -Name rg -ErrorAction SilentlyContinue) {
    Set-Alias -Name grep -Value rg
}

if (-not (Get-Command -Name vim -ErrorAction SilentlyContinue) -and (Get-Command -Name nvim -ErrorAction SilentlyContinue)) {
    Set-Alias -Name vim -Value nvim
}
{{- end -}}
