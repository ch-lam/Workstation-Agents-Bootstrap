[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '50-docker-wsl' {
    if (-not $script:Config.EnableDocker) { Add-Result 'Docker' INFO 'Disabled by configuration'; return }
    Require-Admin
    $ready = $true
    foreach ($feature in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -ne 'Enabled') { Add-Result $feature FAIL 'Run phase 10 then restart'; $ready=$false }
    }
    if (-not $ready) { return }
    if (Test-PendingReboot) { throw 'Restart Windows before Docker/WSL setup' }
    $server = Get-Service LanmanServer
    $serverCim = Get-CimInstance Win32_Service -Filter "Name='LanmanServer'"
    if ($serverCim.StartMode -ne 'Auto' -or $server.Status -ne 'Running') {
        Invoke-Change 'Docker Server service prerequisite' { Set-Service LanmanServer -StartupType Automatic; Start-Service LanmanServer }
    }
    $wsl = Invoke-Native wsl.exe @('--version') @(0,1) -Quiet
    $m = [regex]::Match(($wsl.Output -replace "`0",''),'\d+\.\d+\.\d+')
    if ($wsl.Code -ne 0 -or -not $m.Success) {
        Invoke-Change 'Install modern WSL without distro' { $null = Invoke-Native wsl.exe @('--install','--no-distribution') @(0,3010); $script:Reboot=$true }
    } elseif ([version]$m.Value -lt [version]'2.1.5') {
        Invoke-Change 'Update WSL' { $null = Invoke-Native wsl.exe @('--update'); $script:Reboot=$true }
    } else { Add-Result 'WSL' PASS $m.Value }
    if ($script:Reboot) { return }
    Invoke-Change 'Default WSL version 2' { $null = Invoke-Native wsl.exe @('--set-default-version','2') }
    Ensure-WinGet 'Docker.DockerDesktop'
    Add-Result 'Docker first launch' MANUAL 'Launch Docker Desktop as your normal user; review licence, choose WSL2/Linux engine, wait for readiness. A personal Linux distro is optional.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
