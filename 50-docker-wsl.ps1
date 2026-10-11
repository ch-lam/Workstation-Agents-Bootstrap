[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '50-docker-wsl' {
    Require-Admin
    if (-not $script:Check) { Test-MachineTools; Test-OracleDeveloper }
    if ($script:Config.DockerMode -eq 'None') { Add-Result 'Docker' INFO 'Disabled by configuration'; return }
    if (Test-RemoteDockerEnabled) { Ensure-OpenSSHClient }
    if ($script:Reboot) { return }
    if ($script:Config.DockerMode -eq 'RemoteCLI') {
        if (Get-WinGetState 'Docker.DockerDesktop' -Scope machine) {
            Add-Result 'Docker CLI' INFO 'Existing Desktop preserved; using its client without starting or validating its engine'
            $null=Test-Tool docker.exe
        } elseif (Get-WinGetState 'Docker.DockerDesktop') {
            throw 'Desktop exists only in another scope; review migration before adding a standalone client.'
        } else { Ensure-WinGet 'Docker.DockerCLI' }
        if (-not $script:Check -and -not $script:Reboot) { Test-MachineTools -Commands @('docker.exe','ssh.exe') }
        return
    }
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
        Add-Result 'Docker Server service prerequisite' FAIL 'LanmanServer must be running with Automatic start. Have the administrator review this prerequisite now; bootstrap does not change networking services.'
        return
    }
    $wsl = Invoke-Native wsl.exe @('--version') @(0,1) -Quiet
    $m = [regex]::Match(($wsl.Output -replace "`0",''),'\d+\.\d+\.\d+')
    if ($wsl.Code -ne 0 -or -not $m.Success) {
        Invoke-Change 'Install modern WSL without distro' { $null = Invoke-Native wsl.exe @('--install','--no-distribution') @(0,3010); $script:Reboot=$true }
    } elseif ([version]$m.Value -lt [version]'2.1.5') {
        Invoke-Change 'Update WSL' { $null = Invoke-Native wsl.exe @('--update'); $script:Reboot=$true }
    } else { Add-Result 'WSL' PASS $m.Value }
    if ($script:Reboot) { return }
    if (Get-WinGetState 'Docker.DockerCLI') { throw 'Standalone Docker CLI already installed; review migration before adding Desktop to avoid competing clients.' }
    Ensure-WinGet 'Docker.DockerDesktop'
    if (-not $script:Check -and -not $script:Reboot) {
        Test-MachineTools -Commands @('docker.exe')
        if (Test-RemoteDockerEnabled) { Test-MachineTools -Commands @('ssh.exe') }
        $null=Test-Tool docker.exe; $null=Test-Tool docker.exe @('compose','version')
    }
    Add-Result 'Docker first launch' MANUAL 'Launch Docker Desktop as your normal user; review licence, choose WSL2/Linux engine, wait for readiness. A personal Linux distro is optional.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
