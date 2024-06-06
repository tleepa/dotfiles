$env:POSH_SESSION_DEFAULT_USER = "{{ .chezmoi.username }}"

$AllModules = Get-Module -ListAvailable

{{ if eq .chezmoi.os "windows" -}}
$env:PATH = "{{ .chezmoi.homeDir }}/bin;$($env:PATH)"

oh-my-posh init pwsh --config "{{ .chezmoi.homeDir }}/Documents/Powershell/myparadox.omp.json" | Invoke-Expression
{{ else if eq .chezmoi.os "linux" -}}
oh-my-posh init pwsh --config {{ .chezmoi.homeDir }}/.config/powershell/myparadox.omp.json | Invoke-Expression
{{ end -}}

if (Get-Command -Name Get-AzContext -ErrorAction SilentlyContinue) {
    $env:POSH_AZURE_ENABLED = $true
    Clear-AzContext -Scope Process
}

if ('Terminal-Icons' -in $AllModules.Name) {
    Import-Module -Name Terminal-Icons
}

if (Get-Command -Name zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}

if ('PSFzf' -in $AllModules.Name) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
$env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'

# if ('VMware.VimAutomation.Core' -in $AllModules.Name) {
#     if ((Get-PowerCLIConfiguration -Scope User).ParticipateInCEIP) {
#         Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false | Out-Null
#     }
# }

Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord

Set-PSReadLineKeyHandler -Chord 'Alt+Backspace' -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Alt+f -Function ForwardWord
Set-PSReadLineKeyHandler -Key Alt+b -Function Undo

# Search auto-completion from history
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Show auto-complete predictions from history
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -PredictionSource history

Set-PSReadlineOption -Color @{
    Command          = [ConsoleColor]::Green
    Parameter        = [ConsoleColor]::Gray
    Operator         = [ConsoleColor]::Magenta
    Variable         = [ConsoleColor]::White
    String           = [ConsoleColor]::Yellow
    Number           = [ConsoleColor]::Blue
    Type             = [ConsoleColor]::Cyan
    Comment          = [ConsoleColor]::DarkCyan
    InlinePrediction = "#6272A4"
}

. "{{ .chezmoi.homeDir }}/bin/PSFunctions.ps1"
if (Test-Path -Path "{{ .chezmoi.homeDir }}/bin/PSCompletions.ps1") {
    . "{{ .chezmoi.homeDir }}/bin/PSCompletions.ps1"
}

{{ template "PSAliases.ps1" . }}