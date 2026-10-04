[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '60-workstation-config' {
    Require-User
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $extensions = ((Invoke-Native code @('--list-extensions') -Quiet).Output -split "`r?`n")
        foreach ($extension in $script:Config.Extensions) {
            if ($extensions -contains $extension) { Add-Result $extension PASS 'Installed' }
            else { Invoke-Change "VS Code $extension" { $null = Invoke-Native code @('--install-extension',$extension) } }
        }
    } else { Add-Result 'VS Code CLI' FAIL 'Reopen terminal after phase 20; code must be on PATH' }
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Git missing' }
    $pairs = @{ 'user.name'=$script:Config.GitUserName; 'user.email'=$script:Config.GitUserEmail; 'init.defaultBranch'=$script:Config.GitDefaultBranch }
    foreach ($key in $pairs.Keys) {
        if (-not $pairs[$key]) { Add-Result $key MANUAL 'Empty placeholder; existing value preserved'; continue }
        $r = Invoke-Native git.exe @('config','--global','--get',$key) @(0,1) -Quiet
        if ($r.Output.Trim() -eq $pairs[$key]) { Add-Result $key PASS 'Already configured' }
        else { Invoke-Change "Git $key" { $null = Invoke-Native git.exe @('config','--global',$key,$pairs[$key]) } }
    }
    Add-Result 'Terminal / encoding' MANUAL 'Select PowerShell 7 as Windows Terminal default profile. No system locale or UTF-8 registry change required.'
    if (-not $script:Config.BackendLoginConfirmed) {
        Add-Result 'LOGIN REQUIS AVANT PHASE 70' MANUAL (Get-BackendLoginInstructions $script:Root $script:ActiveConfigPath)
    } else {
        Add-Result 'Backend login confirmation' INFO 'Conversation Claude ou Codex deja confirmee dans cette configuration ; vous pouvez passer a la phase 70.'
    }
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
