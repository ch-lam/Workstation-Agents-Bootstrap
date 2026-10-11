[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '70-validation' {
    Require-User
    if (-not (Test-BackendConfirmation)) {
        Add-Result 'Backend session' FAIL 'Validation non lancee : connecter et tester Claude OU Codex, puis confirmer le login AVANT de lancer la phase 70.'
        Add-Result 'LOGIN REQUIS AVANT PHASE 70' MANUAL (Get-BackendLoginInstructions $script:Root $script:ActiveConfigPath)
        return
    }
    Test-WindowsUpdates
    Test-MachineTools
    Test-OracleDeveloper -EffectiveEnvironment
    Test-StorageVolumes
    if (Test-PendingReboot) { Add-Result 'Restart' FAIL 'Pending restart; restart first' }
    $os=Get-CimInstance Win32_OperatingSystem
    $cv=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $status=if ([int]$os.BuildNumber -ge 22631 -and $cv.EditionID -in @('Professional','ProfessionalN') -and $env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {'PASS'} else {'FAIL'}
    Add-Result 'Windows target' $status "$($os.Caption) $($os.BuildNumber); x64 Pro required"
    $null = Test-NodeMinimum
    foreach ($tool in @('pwsh.exe','npm.cmd','git.exe','code','python.exe','uv.exe','uvx.exe','gh.exe','codex','claude')) { $null = Test-Tool $tool }
    $null = Test-Tool grok @('version')
    foreach ($id in @('Microsoft.WindowsTerminal','Microsoft.Sysinternals.Suite')) {
        $status = if (Get-WinGetState $id) {'PASS'} else {'FAIL'}
        Add-Result $id $status 'WinGet installed inventory'
    }
    if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $r=Invoke-Native pwsh.exe @('-NoProfile','-Command','$PSVersionTable.PSVersion.Major') -Quiet
        if ([int]$r.Output.Trim() -lt 7) { Add-Result 'PowerShell minimum' FAIL 'PowerShell >=7 required' }
    }
    if ($script:Config.NoSleepOnAC) {
        $power=Get-PowerAC
        $status=if ($power.Sleep -eq 0 -and $power.Hibernate -eq 0) {'PASS'} else {'FAIL'}
        Add-Result 'AC sleep and hibernate' $status "Sleep=$($power.Sleep), Hibernate=$($power.Hibernate) seconds"
    }
    Test-TimeSync
    if (Get-Command code -ErrorAction SilentlyContinue) {
        $extensions=((Invoke-Native code @('--list-extensions') -Quiet).Output -split "`r?`n")
        $expectedExtensions=@($script:Config.Extensions)
        if ($script:Config.OracleDeveloper.Enabled) { $expectedExtensions+=$script:Config.OracleDeveloper.VSCodeExtension }
        foreach ($ext in @($expectedExtensions | Select-Object -Unique)) {
            $status=if ($extensions -contains $ext) {'PASS'} else {'FAIL'}
            Add-Result $ext $status 'Extension inventory'
        }
    }
    if (Get-Command git.exe -ErrorAction SilentlyContinue) {
        foreach ($key in @('user.name','user.email')) {
            $r=Invoke-Native git.exe @('config','--get',$key) @(0,1) -Quiet
            $status=if ($r.Code -eq 0 -and $r.Output.Trim()) {'PASS'} else {'WARN'}
            Add-Result "Git $key" $status 'Identity presence checked; configure before commits'
        }
    }
    if (Test-LocalDockerEnabled) {
        $r=Invoke-Native wsl.exe @('--version') -Quiet
        $m=[regex]::Match(($r.Output -replace "`0",''),'\d+\.\d+\.\d+')
        $status=if ($m.Success -and [version]$m.Value -ge [version]'2.1.5') {'PASS'} else {'FAIL'}
        if ($status -eq 'PASS') { Add-Result 'WSL >=2.1.5' PASS $r.Output -ConsoleDetail $m.Value }
        else { Add-Result 'WSL >=2.1.5' FAIL $r.Output }
    }
    Test-DockerEngines
    Add-Result 'Backend session' PASS 'Conversation Claude ou Codex confirmee pour le SID courant ; declaration humaine, pas une verification automatique de session.'
    Add-Result 'Credentials' INFO 'No token files or credential environment values read. Login state is not inferred from binary presence.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
