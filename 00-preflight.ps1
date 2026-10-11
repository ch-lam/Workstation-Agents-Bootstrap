[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '00-preflight' {
    $os = Get-CimInstance Win32_OperatingSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $machine = Get-CimInstance Win32_ComputerSystem
    $cpu = @(Get-CimInstance Win32_Processor)[0]
    $status = if ([int]$os.BuildNumber -ge 22631 -and $cv.EditionID -in @('Professional','ProfessionalN')) {'PASS'} else {'FAIL'}
    Add-Result 'Windows 11 Pro' $status "$($os.Caption), build $($os.BuildNumber), edition $($cv.EditionID). Windows must also remain in Microsoft support."
    $status = if ([Environment]::Is64BitProcess -and $env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {'PASS'} else {'FAIL'}
    Add-Result 'Architecture' $status 'This playbook targets native Windows x64, including official Grok x64.'
    Add-Result 'Elevation' INFO "Administrator=$(Test-Administrator); finish 10,20,50 in the administrator account, then switch once for 30,40,60,70"
    $ram = [Math]::Round($machine.TotalPhysicalMemory/1GB,1)
    $status = Get-RAMLevel $ram $script:Config.MinimumRAMGB $script:Config.RecommendedRAMGB
    Add-Result 'RAM' $status "$ram GB usable; minimum $($script:Config.MinimumRAMGB), recommended $($script:Config.RecommendedRAMGB) nominal (0.5 GB allowance for hardware reservation)"
    Test-StorageVolumes
    if (Test-LocalDockerEnabled) {
        $virtualized = $cpu.VirtualizationFirmwareEnabled -and $cpu.SecondLevelAddressTranslationExtensions
        $status = if ($virtualized) {'PASS'} elseif ($machine.HypervisorPresent) {'WARN'} else {'FAIL'}
        Add-Result 'Virtualization / SLAT' $status 'Hypervisor presence alone does not prove nested virtualization. A VM requires host-side nested virtualization and a working WSL2/Desktop engine; Proxmox support is not assumed.'
        if (Test-Administrator) {
            foreach ($feature in @('Microsoft-Windows-Subsystem-Linux','VirtualMachinePlatform')) {
                $state=Get-WindowsOptionalFeature -Online -FeatureName $feature
                Add-Result $feature INFO "$($state.State)"
            }
        } else { Add-Result 'WSL feature inventory' MANUAL 'Run preflight elevated for optional-feature state; phase 10 checks before enabling.' }
        if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
            $r=Invoke-Native wsl.exe @('--version') @(0,1) -Quiet
            $version=[regex]::Match(($r.Output -replace "`0",''),'\d+\.\d+\.\d+')
            Add-Result 'Existing WSL' INFO $r.Output -ConsoleDetail $(if ($version.Success) {$version.Value} else {'Version details available with -Verbose'})
        }
    }
    $null = Test-Tool winget.exe
    foreach ($tool in @('pwsh.exe','git.exe','node.exe','npm.cmd','python.exe','uv.exe','uvx.exe','gh.exe','docker.exe','codex.cmd','claude.exe','grok.cmd')) {
        $null = Test-Tool $tool -Optional
    }
    foreach ($profile in @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)) {
        Add-Result 'Network profile' INFO "$($profile.Name): $($profile.NetworkCategory). Profile unchanged."
    }
    $restartReasons=@(Get-PendingRebootReasons)
    if ($restartReasons.Count -gt 0) {
        Add-Result 'Pending restart' FAIL ("Windows still reports a pending restart. Indicators: " + ($restartReasons -join "`n"))
        Add-Result 'Restart diagnosis' MANUAL 'If you already restarted, these markers may have been recreated by Windows Update/installers or may be stale. Inspect the listed indicators; do not delete registry entries automatically.'
    }
    Test-TimeSync
    Test-WindowsUpdates
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
