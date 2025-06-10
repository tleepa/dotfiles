# $SshCompletionOptions = New-Object PSObject
# $SshCompletionOptions | Add-Member -NotePropertyName ParseHostnames -NotePropertyValue $true
# $SshCompletionOptions | Add-Member -NotePropertyName ParseKnownHosts -NotePropertyValue $true

if ($PSVersionTable.Platform -match "^Win") {
    $SshCompletion = {
        param ($wordToComplete, $commandAst, $cursorPosition)

        $sshMainConfigFile = "$($env:USERPROFILE)\.ssh\config"
        $sshConfigFiles = @($sshMainConfigFile)

        $sshMainConfigFileContent = Get-Content -Path $sshMainConfigFile

        $sshMainConfigFileContent | ForEach-Object {
            if ($_ -match '^Include ') {
                Get-Item -Path ($_.Split(' ')[-1]) | ForEach-Object {
                    $sshConfigFiles += $_.FullName
                }
            }
        }

        Get-Content -Path $sshConfigFiles | Where-Object {$_ -match '^Host '} | Sort-Object | ForEach-Object {
            $_.Split(' ')[1..$_.Split(' ').Length] | ForEach-Object {
                if ($_ -notmatch '\*' -and $_ -match $wordToComplete) {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            }
        }

        if ($SshCompletionOptions.ParseHostnames) {
            Get-Content -Path $sshConfigFiles | Where-Object {$_ -match '^\s+Hostname '} | Sort-Object | ForEach-Object {
                if ($_.Split(' ')[-1] -match $wordToComplete) {
                    [System.Management.Automation.CompletionResult]::new($_.Split(' ')[-1], $_.Split(' ')[-1], 'ParameterValue', $_.Split(' ')[-1])
                }
            }
        }

        if ($SshCompletionOptions.ParseKnownHosts) {
            Get-Content -Path "$($env:USERPROFILE)\.ssh\known_hosts" | Sort-Object | ForEach-Object {
                if ($_.Split(' ')[0] -match $wordToComplete) {
                    $_.Split(' ')[0].Split(',') | ForEach-Object {
                        $item = $_.Split(':')[0].Trim('[]')
                        [System.Management.Automation.CompletionResult]::new($item, $item, 'ParameterValue', $item)
                    }
                }
            }
        }


    }

    ('ssh', 'scp', 'sftp') | ForEach-Object {
        Register-ArgumentCompleter -Native -CommandName $_ -ScriptBlock $SshCompletion
    }


    if (Get-Command -Name uv -ErrorAction SilentlyContinue) {
        (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
    }
    if (Get-Command -Name uvx -ErrorAction SilentlyContinue) {
        (& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
    }
}

Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}
