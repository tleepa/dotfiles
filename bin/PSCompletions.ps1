# $SshCompletionOptions = New-Object PSObject
# $SshCompletionOptions | Add-Member -NotePropertyName ParseHostnames -NotePropertyValue $true
# $SshCompletionOptions | Add-Member -NotePropertyName ParseKnownHosts -NotePropertyValue $true

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


$PipCompletion = {
    param ($wordToComplete, $commandAst, $cursorPosition)

    (& pip list --format json | ConvertFrom-Json).name | ForEach-Object {
        if ($_ -match $wordToComplete) {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

Register-ArgumentCompleter -Native -CommandName 'pip' -ScriptBlock $PipCompletion
