[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '40-ai-cli' {
    Require-User
    if (-not (Test-NodeMinimum)) { throw 'Fix Node before installing AI CLIs' }
    if (-not (Test-Tool npm.cmd)) { throw 'npm missing' }
    Ensure-NpmCLI 'codex' '@openai/codex' $script:Config.CodexVersion
    # Official native WinGet installation; npm Claude installation is unnecessary.
    if (Get-Command claude -ErrorAction SilentlyContinue) { $null = Test-Tool claude }
    else { Ensure-WinGet 'Anthropic.ClaudeCode' -Scope user }
    Ensure-NpmCLI 'grok' '@xai-official/grok' $script:Config.GrokVersion @('version')
    Add-Result 'Login' MANUAL 'Outside logs: codex login; claude (browser prompts); grok login; gh auth login. Test an ordinary Codex or Claude conversation.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
