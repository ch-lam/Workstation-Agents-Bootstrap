Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Root = Split-Path $PSScriptRoot -Parent
$script:Rows = New-Object 'System.Collections.Generic.List[object]'
$script:Reboot = $false
$script:Check = $false
$script:WindowsUpdateMandatory = $false
. (Join-Path $PSScriptRoot 'Storage.ps1')
. (Join-Path $PSScriptRoot 'WindowsUpdate.ps1')
. (Join-Path $PSScriptRoot 'Configuration.ps1')
. (Join-Path $PSScriptRoot 'Provisioning.ps1')
. (Join-Path $PSScriptRoot 'Portable.ps1')
. (Join-Path $PSScriptRoot 'Docker.ps1')
. (Join-Path $PSScriptRoot 'Oracle.ps1')

function Test-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Add-Result {
    param([string]$Name, [ValidateSet('PASS','FAIL','WARN','PLAN','MANUAL','INFO','UNKNOWN')][string]$Status, [string]$Detail, [switch]$LogOnly,[AllowEmptyString()][string]$ConsoleDetail)
    $Detail=Protect-LogText $Detail
    if ($ConsoleDetail) { $ConsoleDetail=Protect-LogText $ConsoleDetail }
    $script:Rows.Add([pscustomobject]@{ Name=$Name; Status=$Status; Detail=$Detail })
    $line = '{0:o} [{1}] {2}: {3}' -f (Get-Date),$Status,$Name,$Detail
    $color=switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'INFO' { 'Cyan' }
        'PLAN' { 'Cyan' }
        default { 'Yellow' }
    }
    if (-not $LogOnly) {
        $display=$line
        if ($PSBoundParameters.ContainsKey('ConsoleDetail')) {
            $display='{0:o} [{1}] {2}' -f (Get-Date),$Status,$Name
            if ($ConsoleDetail) { $display+=': '+$ConsoleDetail }
        }
        Write-Host $display -ForegroundColor $color
    }
    if ($LogOnly -or $PSBoundParameters.ContainsKey('ConsoleDetail')) { Write-Verbose $line }
    Add-Content -LiteralPath $script:Log -Value $line -Encoding UTF8
}
function Invoke-Native {
    param([string]$Command, [string[]]$Arguments=@(), [int[]]$Allowed=@(0), [switch]$Quiet)
    # Do not use transcripts, environment dumps, or login commands here.
    if ($Command -notmatch '[\\/]' -and -not [IO.Path]::GetExtension($Command)) {
        foreach ($suffix in @('.exe','.cmd')) {
            if (Get-Command ($Command+$suffix) -ErrorAction SilentlyContinue) { $Command+=$suffix; break }
        }
    }
    # Resolve before invocation: a missing command must never reuse a previous exit code.
    $native = Get-Command -Name $Command -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $old = $ErrorActionPreference
    if (-not $Quiet) { Add-Result 'Execution' INFO $Command }
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = $null
    try { $output = @(& $native.Source @Arguments 2>&1 | ForEach-Object { $_.ToString() }); $code = $global:LASTEXITCODE }
    finally { $ErrorActionPreference = $old }
    if ($null -eq $code) { throw "Unable to start native command: $Command" }
    # npm, proxies and SSH may echo credentials: never persist arbitrary child output.
    Add-Content -LiteralPath $script:Log -Value ("Native exit: {0}; code={1}" -f [IO.Path]::GetFileName($native.Source),$code) -Encoding UTF8
    if ($Allowed -notcontains $code) { throw "$Command failed (exit $code). Raw output omitted to protect credentials; diagnose manually outside bootstrap logs." }
    [pscustomobject]@{ Code=$code; Output=($output -join "`n") }
}
function Invoke-Change {
    param([string]$Name, [scriptblock]$Action)
    if ($script:Check) { Add-Result $Name PLAN 'Would apply'; return }
    & $Action
    Add-Result $Name PASS 'Applied'
}
function Require-Admin {
    if (-not $script:Check -and -not (Test-Administrator)) { throw 'Run phases 10,20,50 in an administrator account before switching to the standard workstation account.' }
}
function Require-User {
    if (-not $script:Check -and (Test-Administrator)) { throw 'Run this phase in a non-elevated terminal under the workstation user account.' }
}
function Refresh-Path {
    $parts = @($env:PATH,[Environment]::GetEnvironmentVariable('PATH','Machine'),[Environment]::GetEnvironmentVariable('PATH','User'))
    # Only change this process, never rewrite the persistent PATH.
    $env:PATH = ((($parts -join ';') -split ';' | Where-Object {$_} | Select-Object -Unique) -join ';')
}
function Get-PendingRebootReasons {
    $keys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    foreach ($key in $keys) {
        if ($key -like '*\WindowsUpdate\*' -and -not $script:WindowsUpdateMandatory) { continue }
        if (Test-Path $key) { "Registry marker: $key" }
    }
    $value = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($value -and $value.PSObject.Properties['PendingFileRenameOperations']) {
        $operations=@($value.PendingFileRenameOperations | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($operations.Count -gt 0) { 'PendingFileRenameOperations: '+($operations -join '; ') }
    }
}
function Test-PendingReboot {
    return (@(Get-PendingRebootReasons).Count -gt 0)
}
function Test-Tool {
    param([string]$Command,[string[]]$Arguments=@('--version'),[switch]$Optional)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        $status = if ($Optional) {'WARN'} else {'FAIL'}
        Add-Result $Command $status 'Absent from current PATH'; return $false
    }
    $resolved=Get-Command $Command -ErrorAction Stop
    if ($Command -eq 'python.exe' -and $resolved.Source -like '*\Microsoft\WindowsApps\*') {
        $status = if ($Optional) {'WARN'} else {'FAIL'}
        Add-Result $Command $status 'Windows Store execution alias detected; install machine Python in phase 20, then reopen terminal or disable the alias if it still shadows Python.'
        return $false
    }
    try {
        $r = Invoke-Native $Command $Arguments -Quiet
        Add-Result $Command PASS ("Command succeeded; path: $($resolved.Source)") -ConsoleDetail ''
        return $true
    } catch {
        $status = if ($Optional) {'WARN'} else {'FAIL'}
        Add-Result $Command $status $_.Exception.Message; return $false
    }
}
function Get-RAMLevel {
    param([double]$UsableGB,[double]$MinimumGB,[double]$RecommendedGB)
    if ($UsableGB -lt $MinimumGB) { return 'FAIL' }
    # Firmware/hardware reservations commonly leave a nominal 16 GB machine at 15.8 GB.
    if ($UsableGB -lt ($RecommendedGB-0.5)) { return 'WARN' }
    return 'PASS'
}
function Get-WinGetState {
    param([string]$Id,[ValidateSet('','machine','user')][string]$Scope='')
    # Only the documented no-applications HRESULT means absent; other errors stop.
    $noApps = -1978335212 # 0x8A150014
    $arguments=@('list','--id',$Id,'--exact','--source','winget','--disable-interactivity')
    if ($Scope) { $arguments+=@('--scope',$Scope) }
    $r = Invoke-Native 'winget.exe' $arguments @(0,$noApps) -Quiet
    if ($r.Code -eq $noApps -and $Scope -eq 'machine' -and (Test-PythonMachineInstallation $Id)) {
        Add-Result $Id WARN 'WinGet scope mismatch: machine Python independently verified via HKLM PythonCore, Program Files executable/version and machine PATH; no reinstall. No same-version HKCU runtime detected.'
        return $true
    }
    return ($r.Code -eq 0)
}
function Ensure-WinGet {
    param([string]$Id,[string[]]$Extra=@(),[ValidateSet('machine','user')][string]$Scope='machine')
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Add-Result $Id FAIL 'WinGet absent; repair App Installer using Microsoft Store'; return
    }
    if ($Extra -contains '--scope') { throw 'Use the Scope parameter, not Extra, for installation scope' }
    if (Get-WinGetState $Id -Scope $Scope) { Add-Result $Id PASS "Already installed ($Scope); no automatic upgrade"; return }
    if (Get-WinGetState $Id) { throw "$Id is detected by WinGet but its requested scope ($Scope) could not be verified. Inspect installed paths/registrations; this may be a scope inventory mismatch. No duplicate installation or automatic uninstall." }
    Invoke-Change "Install $Id" {
        # Explicit source, exact IDs and normal hash checks. Never override hash/security checks.
        $null = Invoke-Native 'winget.exe' (@('show','--id',$Id,'--exact','--source','winget','--accept-source-agreements','--disable-interactivity'))
        $r = Invoke-Native 'winget.exe' (@('install','--id',$Id,'--exact','--source','winget','--silent',
            '--accept-source-agreements','--accept-package-agreements','--disable-interactivity','--scope',$Scope) + $Extra) @(0,3010,1641)
        if ($r.Code -ne 0) { $script:Reboot = $true; return }
        Refresh-Path
        if (-not (Get-WinGetState $Id -Scope $Scope)) { throw "Installation not detected in requested scope: $Id ($Scope)" }
    }
}
function Test-NodeMinimum {
    if (-not (Test-Tool node.exe)) { return $false }
    $r = Invoke-Native node.exe @('--version') -Quiet
    $major = [int](($r.Output.Trim() -replace '^v','').Split('.')[0])
    if ($major -lt 22) { Add-Result 'Node minimum' FAIL 'Node >=22 required. Upgrade Node LTS explicitly, then reopen terminal.'; return $false }
    $lts = (Invoke-Native node.exe @('-p','process.release.lts || "not-lts"') -Quiet).Output.Trim()
    if ($lts -eq 'not-lts') { Add-Result 'Node LTS' FAIL 'This binary is not an LTS release; install OpenJS.NodeJS.LTS.'; return $false }
    Add-Result 'Node minimum' PASS "Major $major >=22; LTS=$lts; verify support lifecycle in SOURCES.md"
    return $true
}
function Ensure-NpmCLI {
    param([string]$Command,[string]$Package,[string]$Version,[string[]]$VersionArguments=@('--version'))
    $prefix=Get-UserNpmPrefix
    Ensure-PathEntry $prefix User
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        if (-not (Test-Tool $Command $VersionArguments)) { throw "Existing $Command is broken; resolve before reinstalling." }
        $r = Invoke-Native npm.cmd @('list','-g',$Package,'--depth=0','--json') @(0,1) -Quiet
        $data = $r.Output | ConvertFrom-Json
        $dependencyProperty=$data.PSObject.Properties['dependencies']
        if (-not $dependencyProperty -or -not $dependencyProperty.Value.PSObject.Properties[$Package]) {
            throw "Existing $Command is not registered as official npm package $Package. Review its origin/install method and PATH before using this npm profile; no unknown CLI is silently accepted."
        }
        $actual=$dependencyProperty.Value.PSObject.Properties[$Package].Value.version
        Add-Result "Official package $Package" PASS 'Registered in the current npm prefix'
        $prefix=(Invoke-Native npm.cmd @('prefix','--global') -Quiet).Output.Trim()
        $resolved=Get-Command ($Command+'.cmd') -ErrorAction SilentlyContinue
        if (-not $resolved -or -not $resolved.Source.Equals((Join-Path $prefix ($Command+'.cmd')),[StringComparison]::OrdinalIgnoreCase)) {
            throw "$Command is shadowed or comes from another installation; correct PATH before continuing."
        }
        if ($Version) {
            if ($actual -ne $Version) { throw "$Package is $actual, requested $Version. Upgrade explicitly; no implicit downgrade." }
        }
        return
    }
    $target = if ($Version) { "$Package@$Version" } else { "$Package@latest" }
    Invoke-Change "Install $Package" {
        $null = Invoke-Native npm.cmd @('install','--global','--registry=https://registry.npmjs.org/',$target)
        Refresh-Path
        $prefix = (Invoke-Native npm.cmd @('prefix','--global') -Quiet).Output.Trim()
        $env:PATH = "$prefix;$env:PATH"
        if (-not (Test-Tool $Command $VersionArguments)) { throw "$Command was not usable after install" }
    }
}
function Show-TimeRecovery {
    param([ValidateSet('Service','Synchronization','Offset','Probe')][string]$Reason)
    $message="NTP action required ($Reason). In a PowerShell terminal opened as Administrator, run these commands using the existing Windows/domain time sources:`n`nStart-Service -Name W32Time`nw32tm /resync /rediscover`nw32tm /query /status`n"
    if ($Reason -eq 'Probe') { $message+="`nIf the diagnostic server remains unreachable, check UDP 123 and NtpProbeHost; resync alone cannot fix an unreachable server.`n" }
    $message+="`nIf resync reports no time data, inspect:`nw32tm /query /configuration`nw32tm /query /peers`n"
    $phase=Get-Variable -Name ActivePhase -Scope Script -ErrorAction SilentlyContinue
    $configuration=Get-Variable -Name ActiveConfigPath -Scope Script -ErrorAction SilentlyContinue
    if ($phase -and $configuration) {
        $file=Join-Path $script:Root ($phase.Value+'.ps1')
        $escapedFile=$file.Replace("'","''")
        $escapedConfig=([string]$configuration.Value).Replace("'","''")
        $checkFlag=if ($script:Check) {' -CheckOnly'} else {''}
        if ($script:WindowsUpdateMandatory) { $checkFlag+=' -WindowsUpdateMandatory' }
        $message+="`nAfter synchronization, return to this terminal and rerun the same phase/configuration:`n& '$escapedFile' -ConfigPath '$escapedConfig'$checkFlag"
    } else { $message+="`nAfter synchronization, rerun the same bootstrap phase with your existing config.local.psd1." }
    Add-Result 'NTP recovery' MANUAL $message
}
function Test-TimeSync {
    try { $r = Invoke-Native w32tm.exe @('/query','/status','/verbose') @(0,1,-2147023834) -Quiet }
    catch { Add-Result 'Windows time' FAIL $_.Exception.Message; Show-TimeRecovery Service; return }
    Add-Result 'Windows time status (raw)' INFO $r.Output -LogOnly
    if ($r.Code -ne 0) { Add-Result 'Windows time' FAIL 'Time service unsynchronized/unavailable; inspect w32tm /query /status'; Show-TimeRecovery Service; return }
    # Status starts with Leap Indicator and Stratum on supported Windows locales.
    # Numeric values avoid relying on translated field labels.
    $numbers=@([regex]::Matches($r.Output,'(?m)^[^\r\n:]+:\s*(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
    if ($numbers.Count -lt 2 -or $numbers[0] -eq 3 -or $numbers[1] -lt 1 -or $numbers[1] -gt 15) {
        Add-Result 'Windows time synchronized' FAIL 'Leap/stratum indicate unsynchronized time, or status cannot be parsed; inspect Windows time service.'
        Show-TimeRecovery Synchronization
        return
    }
    Add-Result 'Windows time synchronized' PASS "Leap=$($numbers[0]); Stratum=$($numbers[1])"
    # Stripchart is diagnostic only: it does not change time or peers.
    $r = Invoke-Native w32tm.exe @('/stripchart',"/computer:$($script:Config.NtpProbeHost)",'/dataonly','/samples:3') @(0,1) -Quiet
    Add-Result 'NTP stripchart (raw)' INFO $r.Output -LogOnly
    $matches = [regex]::Matches($r.Output,'([+-]\d+[.,]\d+)s')
    if ($r.Code -ne 0 -or $matches.Count -eq 0) {
        Add-Result 'NTP offset' FAIL 'No measurable NTP response (UDP 123/firewall/proxy?). Set NtpProbeHost to an approved reachable NTP server.'; Show-TimeRecovery Probe; return
    }
    $offsets = @($matches | ForEach-Object { [Math]::Abs([double]::Parse(($_.Groups[1].Value -replace ',','.'),[Globalization.CultureInfo]::InvariantCulture)) })
    $maximum = ($offsets | Measure-Object -Maximum).Maximum
    $status = if ($maximum -le $script:Config.MaximumTimeOffsetSeconds) {'PASS'} else {'FAIL'}
    $measured=($maximum*1000).ToString('0.000',[Globalization.CultureInfo]::InvariantCulture)
    Add-Result 'NTP offset' $status "Server=$($script:Config.NtpProbeHost); maximum=$measured ms; limit=$($script:Config.MaximumTimeOffsetSeconds) s; samples=$($offsets.Count)"
    if ($status -eq 'FAIL') { Show-TimeRecovery Offset }
}
function Get-PowerAC {
    $r = Invoke-Native powercfg.exe @('/query','SCHEME_CURRENT','SUB_SLEEP') -Quiet
    # Locale-independent: GUIDs identify settings; final 0x value is DC, prior is AC.
    $result = @{}
    foreach ($entry in @(@('Sleep','29f6c1db-86da-48c5-9fdb-f2b67b1f44da'),@('Hibernate','9d7815a6-7ee4-497e-8888-515a05f02364'))) {
        $m = [regex]::Match($r.Output, '(?is)' + $entry[1] + '(.*?)(?=[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|$)')
        if (-not $m.Success) { throw "Unable to read AC power setting $($entry[0])" }
        $hex = [regex]::Matches($m.Groups[1].Value,'(?i)0x[0-9a-f]+')
        if ($hex.Count -lt 2) { throw "Missing AC/DC indexes for $($entry[0])" }
        $result[$entry[0]] = [Convert]::ToInt32($hex[$hex.Count-2].Value.Substring(2),16)
    }
    return $result
}
function Invoke-Phase {
    param([string]$Name,[scriptblock]$Body,[string]$ConfigPath,[switch]$CheckOnly,[switch]$WindowsUpdateMandatory)
    $script:WindowsUpdateMandatory = [bool]$WindowsUpdateMandatory
    $script:Check = [bool]$CheckOnly
    $script:ActivePhase=$Name
    $script:ActiveConfigPath=[IO.Path]::GetFullPath($ConfigPath)
    $script:Config = Read-BootstrapConfig $ConfigPath
    $kind=if ($Name.Substring(0,2) -in @('10','20','50')) {'machine-logs'} else {'user-logs'}
    $logs = Join-Path (Get-BootstrapUserDirectory) $kind
    $null = New-Item -ItemType Directory -Path $logs -Force
    $script:Log = Join-Path $logs ("{0}-{1}-{2}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'),$PID,$Name)
    $exitCode = 0
    try {
        Add-Result $Name INFO "Bootstrap; CheckOnly=$script:Check; WindowsUpdateMandatory=$script:WindowsUpdateMandatory; config=$ConfigPath; account=$([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
        Refresh-Path
        & $Body
    } catch { Add-Result $Name FAIL $_.Exception.Message }
    if (@($script:Rows | Where-Object Status -eq FAIL).Count -gt 0) { $exitCode = 1 }
    if ($exitCode -eq 0 -and ($script:Reboot -or (Test-PendingReboot)) -and -not $script:Check) {
        Add-Result 'Restart' MANUAL 'Restart Windows, sign in, reopen terminal, rerun the same phase.'
        $exitCode = 3010
    }
    if ($exitCode -eq 0 -and $env:AGENT_BOOTSTRAP_LAUNCHER -ne '1') {
        Write-BootstrapContinuation $script:Root $ConfigPath $Name.Substring(0,2) $script:Check
    }
    $report = [ordered]@{ Phase=$Name; CheckOnly=$script:Check; WindowsUpdateMandatory=$script:WindowsUpdateMandatory; Timestamp=(Get-Date).ToString('o');
        UserSID=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;
        ConfigSHA256=(Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash;
        ExitCode=$exitCode; Results=@($script:Rows.ToArray()) }
    $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ($script:Log -replace '\.log$','.json') -Encoding UTF8
    if ($Name -eq '70-validation' -and -not $script:Check -and $exitCode -eq 0) {
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $logs 'validation-success.json') -Encoding UTF8
    }
    exit $exitCode
}
