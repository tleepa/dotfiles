$env:POSH_SESSION_DEFAULT_USER = "{{ .chezmoi.username }}"
{{ if eq .chezmoi.os "windows" -}}
$env:PATH = "{{ .chezmoi.homeDir }}/bin;$($env:PATH)"

if (!(Get-Module -Name ZLocation -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-Module -Name ZLocation -Scope CurrentUser
}
Import-Module -Name ZLocation

oh-my-posh init pwsh --config "{{ .chezmoi.homeDir }}/Documents/Powershell/myparadox.omp.json" | Invoke-Expression
{{ else if eq .chezmoi.os "linux" -}}
oh-my-posh init pwsh --config {{ .chezmoi.homeDir }}/.config/powershell/myparadox.omp.json | Invoke-Expression
{{ end -}}

if (Get-Module -Name Az.Accounts -ListAvailable -ErrorAction SilentlyContinue) {
    $env:POSH_AZURE_ENABLED = $true
}

# if (Get-Module -Name VMware.VimAutomation.Core -ListAvailable -ErrorAction SilentlyContinue) {
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
{{ if eq .chezmoi.os "windows" -}}
. "{{ .chezmoi.homeDir }}/bin/PSCompletions.ps1"
{{- end }}
{{ template "PSAliases.ps1" . }}