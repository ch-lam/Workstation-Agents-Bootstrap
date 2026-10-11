function Protect-LogText {
    param([AllowEmptyString()][string]$Text)
    $value=$Text -replace '(?i)(Bearer\s+)\S+','$1[REDACTED]'
    $value=$value -replace '(?i)((?:password|passwd|token|api[_-]?key|secret)\s*[=:]\s*)[^\s;,]+','$1[REDACTED]'
    $value=$value -replace '(?i)(https?://)[^\s/@]+:[^\s/@]+@','$1[REDACTED]@'
    return ($value -replace '\bsk-[a-zA-Z0-9_-]+','[REDACTED]')
}
function Ensure-PathEntry {
    param([string]$Path,[ValidateSet('Machine','User')][string]$Scope)
    $pathValue=[IO.Path]::GetFullPath($Path).TrimEnd('\')
    $current=[Environment]::GetEnvironmentVariable('PATH',$Scope)
    $entries=@($current -split ';' | Where-Object {$_})
    $found=@($entries | Where-Object {[Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ieq $pathValue}).Count -gt 0
    if (-not $found) {
        Invoke-Change "Add $Scope PATH entry" { [Environment]::SetEnvironmentVariable('PATH',(($entries+$pathValue) -join ';'),$Scope) }
    }
    if (-not $script:Check) { Refresh-Path }
}
function Get-UserNpmPrefix {
    $prefix=(Invoke-Native npm.cmd @('prefix','--global') -Quiet).Output.Trim()
    if (-not [IO.Path]::IsPathRooted($prefix)) { throw 'npm global prefix must be an absolute personal path' }
    $full=[IO.Path]::GetFullPath($prefix).TrimEnd('\')
    $profile=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
    if (-not $full.StartsWith($profile,[StringComparison]::OrdinalIgnoreCase)) { throw 'npm global prefix is outside this user profile. Configure a personal prefix before phase 40; never grant write access to a system prefix.' }
    if (-not $script:Check) {
        $null=New-Item -ItemType Directory -Path $full -Force
        $probe=Join-Path $full ('.bootstrap-write-'+[guid]::NewGuid())
        try { [IO.File]::WriteAllText($probe,''); }
        finally { if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe } }
    }
    return $full
}
function Get-MachinePackagePlan {
    $catalog=Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot 'Packages.psd1')
    foreach ($package in $catalog.Machine) { $package }
    @{Id=$script:Config.PythonPackage;Extra=@();Commands=@('python.exe')}
}
function Get-MachinePathDirectories {
    @(([Environment]::GetEnvironmentVariable('PATH','Machine') -split ';') | Where-Object {$_} | ForEach-Object {[Environment]::ExpandEnvironmentVariables($_).Trim('"').TrimEnd('\')})
}
function Test-PythonMachineInstallation {
    param([string]$Id)
    # Python's Burn registration can be reported as User by WinGet even for
    # InstallAllUsers=1. Accept only independently verified machine runtimes.
    if ($Id -notmatch '^Python\.Python\.(3\.\d+)$') { return $false }
    $minor=$Matches[1]
    foreach ($tag in @($minor,($minor+'-32'),($minor+'-64'))) {
        if (Test-Path -LiteralPath "HKCU:\SOFTWARE\Python\PythonCore\$tag\InstallPath") { return $false }
    }
    $executables=@(@(foreach ($tag in @($minor,($minor+'-64'))) {
        $key="HKLM:\SOFTWARE\Python\PythonCore\$tag\InstallPath"
        $registration=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if ($registration -and $registration.PSObject.Properties['(default)']) {
            $directory=[string]$registration.'(default)'
            if ($directory -and [IO.Path]::IsPathRooted($directory)) {
                $candidate=Join-Path ([IO.Path]::GetFullPath($directory)) 'python.exe'
                if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
            }
        }
    }) | Select-Object -Unique)
    if ($executables.Count -ne 1) { return $false }
    $executable=$executables[0]
    if (-not $env:ProgramFiles -or -not $executable.StartsWith(($env:ProgramFiles.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) { return $false }
    if (@(Get-MachinePathDirectories) -notcontains (Split-Path $executable -Parent).TrimEnd('\')) { return $false }
    try { $version=(Invoke-Native $executable @('--version') -Quiet).Output.Trim() }
    catch { return $false }
    return ($version -match ('^Python '+[regex]::Escape($minor)+'\.\d+(?:\S*)?$'))
}
function Test-MachineTools {
    param([string[]]$Commands=@((Get-MachinePackagePlan) | ForEach-Object {$_.Commands}))
    # Check actual resolution as well as package scope, including from the standard session.
    $machinePath=@(Get-MachinePathDirectories)
    foreach ($command in $Commands) {
        $resolved=Get-Command $command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $resolved) { Add-Result $command FAIL 'Machine tool unavailable in this session; finish phase 20 and reopen the terminal'; continue }
        $machineRoots=@($env:ProgramFiles,${env:ProgramFiles(x86)},$env:SystemRoot)
        $shared=@($machineRoots | Where-Object {$_ -and $resolved.Source.StartsWith(($_.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)}).Count -gt 0
        if (-not $shared) { Add-Result $command FAIL 'Resolved outside the system installation roots; review user installation or PATH shadowing' }
        elseif ($machinePath -notcontains (Split-Path $resolved.Source -Parent).TrimEnd('\')) { Add-Result $command FAIL 'Executable directory absent from machine PATH; an administrator-only PATH must not satisfy this check' }
        else { Add-Result $command PASS "Machine executable: $($resolved.Source)" }
    }
}
function Ensure-OpenSSHClient {
    $capability=Get-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0'
    if ($capability.State -eq 'Installed') { Add-Result 'OpenSSH client' PASS 'Installed'; return }
    Invoke-Change 'Install Windows OpenSSH client (no SSH server)' {
        $result=Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0'
        if ($result.RestartNeeded) { $script:Reboot=$true }
    }
}
