{{ if eq .chezmoi.os "darwin" -}}
$env:TEMP = $env:TMPDIR
{{ end -}}

$env:POSH_SESSION_DEFAULT_USER = "{{ .chezmoi.username }}"
{{ if eq .chezmoi.os "windows" -}}
$env:PATH = "{{ .chezmoi.homeDir }}/.local/bin;{{ .chezmoi.homeDir }}/bin;$($env:PATH)"

oh-my-posh init pwsh --config "{{ .chezmoi.homeDir }}/Documents/Powershell/myparadox.omp.yaml" | Invoke-Expression
{{- else }}
oh-my-posh init pwsh --config {{ .chezmoi.homeDir }}/.config/powershell/myparadox.omp.yaml | Invoke-Expression
{{- end }}

if (Get-Module -Name 'Terminal-Icons' -ListAvailable) {
    Import-Module -Name Terminal-Icons
}

if (Get-Module -Name 'git-aliases' -ListAvailable) {
    Import-Module -Name git-aliases -WarningAction SilentlyContinue
}

if (Get-Command -Name 'zoxide' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}

if (Get-Module -Name 'PSFzf' -ListAvailable) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}
$env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border'

if (Get-Command -Name 'mise' -ErrorAction SilentlyContinue) {
    $env:MISE_DEFAULT_CONFIG_FILENAME = 'mise.local.toml'
    mise activate --shims pwsh | Invoke-Expression
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord

Set-PSReadLineKeyHandler -Chord 'Alt+Backspace' -Function BackwardKillWord
Set-PSReadLineKeyHandler -Key Tab -Function Complete
Set-PSReadLineKeyHandler -Key Alt+f -Function ForwardWord
Set-PSReadLineKeyHandler -Key Alt+b -Function BackwardWord

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

if (Test-Path -Path "{{ .chezmoi.homeDir }}/bin/PSCompletions.ps1") {
    . "{{ .chezmoi.homeDir }}/bin/PSCompletions.ps1"
}

{{ template "PSFunctions.ps1" . }}

{{ template "PSAliases.ps1" . }}
