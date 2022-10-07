param (
    [switch]$withProcessInfo
)

$netstatTCP = Get-NetTCPConnection
$netstatUDP = Get-NetUDPEndpoint

$processList = @{}
if ($withProcessInfo) {
    Get-Process -IncludeUserName | %{
        $pNfo = "" | select Name, Path, UserName
        $pNfo.Name = $_.Name
        $pNfo.Path = $_.Path
        $pNfo.UserName = $_.UserName
        $processList[[int]($_.ID)] = $pNfo
    }
}

$netstat = [System.Collections.ArrayList]::new()
foreach ($ns in ($netstatTCP + $netstatUDP)) {
    $data = "" | select Proto,LocalAddr,LocalPort,RemoteAddr,RemotePort,State,CreationTime,PID

    $data.Proto = $ns.CimClass.CimClassName.Substring(8,3)
    $data.LocalAddr = $ns.LocalAddr
    $data.LocalPort = $ns.LocalPort
    $data.RemoteAddr = $ns.RemoteAddr
    $data.RemotePort = $ns.RemotePort
    $data.CreationTime = $ns.CreationTime
    $data.State = $ns.State
    $data.PID = $ns.OwningProcess
    if ($withProcessInfo) {
        Add-Member -InputObject $data -MemberType NoteProperty -Name ProcessName  -Value ($processList[[int]($data.PID)]).Name
        Add-Member -InputObject $data -MemberType NoteProperty -Name ProcessPath  -Value ($processList[[int]($data.PID)]).Path
        Add-Member -InputObject $data -MemberType NoteProperty -Name ProcessOwner -Value ($processList[[int]($data.PID)]).UserName
    }
    $null = $netstat.Add($data)
}

$netstat
