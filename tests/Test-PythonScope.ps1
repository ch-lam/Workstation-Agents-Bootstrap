$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\Common.ps1')
$passed=0
function Assert-Scope([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }; $script:passed++
}
function Add-Result { param($Name,$Status,$Detail) }
function Get-Command { param($Name,$ErrorAction); return @{Source='fixture'} }
$script:directory=Join-Path $env:ProgramFiles 'Python314'
$script:machineDirectories=@($script:directory)
$script:hasMachine=$true; $script:hasUser=$false; $script:hasExecutable=$true
$script:version='Python 3.14.7'; $script:wingetCode=-1978335212
$script:installs=0; $script:Check=$false
function Get-MachinePathDirectories { $script:machineDirectories }
function Test-Path {
    param($LiteralPath,$PathType)
    if ($LiteralPath -like 'HKCU:*') { return $script:hasUser }
    return $script:hasExecutable
}
function Get-ItemProperty {
    param($LiteralPath,$ErrorAction)
    if ($script:hasMachine -and $LiteralPath -eq 'HKLM:\SOFTWARE\Python\PythonCore\3.14\InstallPath') {
        return [pscustomobject]@{'(default)'=$script:directory}
    }
}
function Invoke-Native {
    param($Command,$Arguments,$Allowed,[switch]$Quiet)
    if ($Command -eq 'winget.exe') {
        if ($Arguments[0] -eq 'install') { $script:installs++; throw 'Unexpected installation' }
        return @{Code=$script:wingetCode;Output=''}
    }
    return @{Code=0;Output=$script:version}
}
Assert-Scope (Get-WinGetState 'Python.Python.3.14' -Scope machine) 'Machine runtime accepted despite absent scoped WinGet row'
Ensure-WinGet 'Python.Python.3.14' -Scope machine
Assert-Scope ($script:installs -eq 0) 'Verified machine runtime never reinstalled'
$script:hasUser=$true
Assert-Scope (-not (Get-WinGetState 'Python.Python.3.14' -Scope machine)) 'Real same-version user runtime prevents fallback'
$script:hasUser=$false; $script:hasMachine=$false
Assert-Scope (-not (Test-PythonMachineInstallation 'Python.Python.3.14')) 'Missing HKLM registration rejected'
$script:hasMachine=$true; $script:hasExecutable=$false
Assert-Scope (-not (Test-PythonMachineInstallation 'Python.Python.3.14')) 'Stale HKLM registration rejected'
$script:hasExecutable=$true; $script:version='Python 3.13.7'
Assert-Scope (-not (Test-PythonMachineInstallation 'Python.Python.3.14')) 'Wrong minor runtime rejected'
$script:version='Python 3.14.7'; $script:machineDirectories=@()
Assert-Scope (-not (Test-PythonMachineInstallation 'Python.Python.3.14')) 'Administrator-only PATH cannot satisfy machine scope'
$script:directory=Join-Path $env:USERPROFILE 'Python314'; $script:machineDirectories=@($script:directory)
Assert-Scope (-not (Test-PythonMachineInstallation 'Python.Python.3.14')) 'User-owned runtime cannot satisfy machine scope'
Assert-Scope (-not (Get-WinGetState 'Fixture.Package' -Scope machine)) 'Fallback limited to official Python runtime IDs'
Assert-Scope (-not (Get-WinGetState 'Python.Python.3.14' -Scope user)) 'Machine evidence cannot satisfy user scope'
$script:directory=Join-Path $env:ProgramFiles 'Python314'; $script:machineDirectories=@($script:directory)
$script:hasMachine=$false
function Refresh-Path {}
function Invoke-Native {
    param($Command,$Arguments,$Allowed,[switch]$Quiet)
    if ($Command -eq 'winget.exe') {
        if ($Arguments[0] -eq 'list') { return @{Code=-1978335212;Output=''} }
        if ($Arguments[0] -eq 'install') { $script:installs++; $script:hasMachine=$true }
        return @{Code=0;Output=''}
    }
    return @{Code=0;Output=$script:version}
}
Ensure-WinGet 'Python.Python.3.14' -Scope machine
Assert-Scope ($script:installs -eq 1) 'Fresh machine installation accepted by independent post-install evidence'
Ensure-WinGet 'Python.Python.3.14' -Scope machine
Assert-Scope ($script:installs -eq 1) 'Resume after WinGet mismatch does not duplicate Python'
Write-Host "$passed Python scope checks passed; no host installation or registry changes."
