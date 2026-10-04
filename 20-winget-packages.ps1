[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '20-winget-packages' {
    Require-Admin
    Ensure-WinGet 'Microsoft.PowerShell' @('--installer-type','wix')
    foreach ($id in @('Microsoft.WindowsTerminal','Git.Git','Microsoft.VisualStudioCode','OpenJS.NodeJS.LTS','GitHub.cli','Microsoft.Sysinternals.Suite')) {
        Ensure-WinGet $id
    }
    Add-Result 'PATH' MANUAL 'Close and reopen the terminal after installation; use PowerShell 7 for remaining user phases.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
