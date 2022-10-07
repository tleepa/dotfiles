function Get-Char {
    param (
        [Parameter(Mandatory=$true, HelpMessage="Single character only")]
        [ValidateLength(1,1)]
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

function Update-AzureCli {
    param (
        [Switch] $DownloadOnly,
        [String] $DownloadDir = $dlDir
    )

    if (Test-Path $DownloadDir) {
        Start-BitsTransfer -Source 'https://aka.ms/installazurecliwindows' -Destination $DownloadDir\AzureCLI.msi
        if (-not $DownloadOnly) {
            Start-Process msiexec.exe -Wait -ArgumentList "/I $DownloadDir\AzureCLI.msi /quiet"
        }
    } else {
        Write-Error "Path $DownloadDir not found!"
    }
}

function Update-AwsCli {
    param (
        [Switch] $DownloadOnly,
        [String] $DownloadDir = $dlDir
    )

    if (Test-Path $DownloadDir) {
        Start-BitsTransfer -Source 'https://awscli.amazonaws.com/AWSCLIV2.msi' -Destination $DownloadDir\AWSCLIV2.msi
        if (-not $DownloadOnly) {
            Start-Process msiexec.exe -Wait -ArgumentList "/I $DownloadDir\AWSCLIV2.msi /quiet"
        }
    } else {
        Write-Error "Path $DownloadDir not found!"
    }
}

function Update-GcpCli {
    param (
        [Switch] $DownloadOnly,
        [String] $DownloadDir = $dlDir
    )

    if (Test-Path $DownloadDir) {
        Start-BitsTransfer -Source 'https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe' -Destination $DownloadDir\GoogleCloudSDKInstaller.exe
        if (-not $DownloadOnly) {
            Start-Process $DownloadDir\GoogleCloudSDKInstaller.exe -Wait -ArgumentList "/S /norepporting /nodesktop /allusers"
        }
    } else {
        Write-Error "Path $DownloadDir not found!"
    }
}

function Check-DO {
param (
    [Parameter(Mandatory=$true)]
    [string] $NrWniosku
)

    $UriDO = 'https://obywatel.gov.pl/esrvProxy/proxy/sprawdzStatusWniosku?numerWniosku={0}'

    $Result = Invoke-WebRequest -Uri ($UriDO -f [uri]::EscapeDataString($NrWniosku))
    $Out = "Wniosek nr: {0} - " -f $NrWniosku
    $Out += (ConvertFrom-Json -InputObject $Result.Content).status.message.replace('&#160;', ' ').replace('<br/>', ' ')

    return $Out
}


function Check-DR {
param (
    [Parameter(Mandatory=$true)]
    [string] $NrRej,
    [Parameter(Mandatory=$true)]
    [string] $NrVin
)

    if ($NrVin.Length -gt 5) {
        $Vin = $NrVin.Substring($NrVin.Length - 5, 5)
    } else {
        $Vin = $NrVin
    }

    $UriDR = 'https://info-car.pl/infocar/dowod-rejestracyjny/sprawdz-status.html?_hn:type=action&_hn:ref=r9_r1_r3_r1'

    $Result = Invoke-WebRequest -Uri $UriDR -Method Post -Body ("plates={0}&vin={1}" -f $NrRej, $Vin)

    $html = New-Object -Com "HTMLFile"
    $html.write([System.Text.Encoding]::Unicode.GetBytes($Result.Content))

    $Status = $html.getElementById('documentStatusGraph').children | Where-Object { $_.className -match 'active' }
    if ($Status) {
        $Out = $Status.outerText
    } else {
        $Out = "Nieprawidłowe dane`n"
    }

    return $Out
}


function Check-PA {
param (
    [Parameter(Mandatory=$true)]
    [string] $NrWniosku
)

    $UriPA = 'https://obywatel.gov.pl/wyjazd-za-granice/sprawdz-czy-twoj-paszport-jest-gotowy'

    $data = Invoke-WebRequest -Uri $UriPA -SessionVariable sv
    $data.Content -match '.*data-auth=\"(.*)\"\>\<\/div\>.*' | Out-Null

    $Result = Invoke-WebRequest -Uri ("{0}?p_p_id=Gotowoscpaszportu_WAR_Gotowoscpaszportuportlet&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_cacheability=cacheLevelPage&p_p_col_id=column-5&p_p_col_count=1" -f $UriPA) `
        -Body ("_Gotowoscpaszportu_WAR_Gotowoscpaszportuportlet_nrSprawy={0}&_Gotowoscpaszportu_WAR_Gotowoscpaszportuportlet_p_auth={1}" -f $NrWniosku, $($Matches[1])) `
        -Method Post -WebSession $sv

    $Out = "Wniosek nr: {0} - " -f $NrWniosku
    $Out += (ConvertFrom-Json -InputObject $Result.Content).status

    return $Out
}
