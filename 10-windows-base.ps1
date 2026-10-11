[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '10-windows-base' {
    Require-Admin
    if ($script:Config.NoSleepOnAC) {
        $power = Get-PowerAC
        if ($power.Sleep -ne 0 -or $power.Hibernate -ne 0) {
            Invoke-Change 'No sleep/hibernate on AC' {
                $null = Invoke-Native powercfg.exe @('/change','standby-timeout-ac','0')
                $null = Invoke-Native powercfg.exe @('/change','hibernate-timeout-ac','0')
                $after = Get-PowerAC
                if ($after.Sleep -ne 0 -or $after.Hibernate -ne 0) { throw 'AC power settings did not apply; check GPO/MDM.' }
            }
        } else { Add-Result 'No sleep on AC' PASS 'Already set; battery, display and lid policy unchanged' }
    }
    if (Test-LocalDockerEnabled) {
        foreach ($feature in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
            $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
            if ($state.State -eq 'Enabled') { Add-Result $feature PASS 'Enabled' }
            else {
                Invoke-Change $feature {
                    $r = Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
                    if ($r.RestartNeeded) { $script:Reboot = $true }
                }
            }
        }
    }
    if ($script:Config.ResyncTime) { Invoke-Change 'Time resync using existing peers' { $null = Invoke-Native w32tm.exe @('/resync') } }
    Test-TimeSync
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
