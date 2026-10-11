[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '20-winget-packages' {
    Require-Admin
    foreach ($package in @(Get-MachinePackagePlan)) {
        Ensure-WinGet $package.Id $package.Extra -Scope machine
        if ($script:Reboot) { return }
    }
    Ensure-OracleDeveloper
    if (-not $script:Check -and -not $script:Reboot) { Test-MachineTools }
    Add-Result 'Windows Terminal' INFO 'Packaged MSIX is registered per user in phase 30; no administrator-profile installation.'
    Add-Result 'PATH' MANUAL 'Close and reopen the terminal after installation; use PowerShell 7 for remaining user phases.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
