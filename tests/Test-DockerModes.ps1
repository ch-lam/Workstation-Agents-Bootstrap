$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Common.ps1')
$passed=0
$script:operations=New-Object 'System.Collections.Generic.List[string]'
$script:rows=New-Object 'System.Collections.Generic.List[object]'
function Assert-Docker([bool]$Condition,[string]$Message) { if (-not $Condition) {throw "TEST FAILED: $Message"};$script:passed++ }
function Add-Result {param($Name,$Status,$Detail);$script:rows.Add(@{Name=$Name;Status=$Status;Detail=$Detail})}
function Test-Tool {param($Command,$Arguments);return $true}
function Invoke-Change {param($Name,$Action);if(-not $script:Check){& $Action}}
function Invoke-Native {
    param($Command,$Arguments,$Allowed,[switch]$Quiet)
    $script:operations.Add(($Arguments -join ' '))
    if ($Arguments[0] -eq 'context' -and $Arguments[1] -eq 'ls') {return @{Code=0;Output=$script:contextNames}}
    if ($Arguments[1] -eq 'inspect') {return @{Code=0;Output=$script:endpoints[$Arguments[2]]}}
    if ($Arguments[1] -eq 'create') {$script:contextNames+="`n"+$Arguments[2];return @{Code=0;Output=''}}
    throw 'Unexpected native call'
}
function Invoke-DockerEngineProbe {param($Context);$script:operations.Add("probe $Context");if($Context -eq 'desktop-linux' -and $script:localDown){throw 'local engine stopped'};return 'linux'}
$script:Config=@{DockerMode='Both';DockerLocalContext='desktop-linux';DockerRemoteContexts=@(@{Name='remote-dev';Host='ssh://dev@server';Required=$true})}
$script:contextNames='desktop-linux'
$script:endpoints=@{'desktop-linux'='npipe:////./pipe/dockerDesktopLinuxEngine';'remote-dev'='ssh://dev@server'}
$script:localDown=$false
$script:Check=$true
Ensure-DockerContexts
Assert-Docker (@($script:operations | Where-Object {$_ -like 'context create*'}).Count -eq 0) 'CheckOnly leaves contexts unchanged'
$script:Check=$false
Ensure-DockerContexts
Ensure-DockerContexts
Assert-Docker (@($script:operations | Where-Object {$_ -like 'context create*'}).Count -eq 1) 'Repeated configuration creates a context only once'
Assert-Docker (@($script:operations | Where-Object {$_ -like 'context use*' -or $_ -like 'context update*' -or $_ -like 'context rm*'}).Count -eq 0) 'No context switching, replacement or removal'
Test-DockerEngines
Assert-Docker (@($script:operations | Where-Object {$_ -eq 'probe desktop-linux'}).Count -eq 1) 'Explicit local context is probed'
Assert-Docker (@($script:operations | Where-Object {$_ -eq 'probe remote-dev'}).Count -eq 1) 'Explicit remote context is probed'
$script:rows.Clear();$script:localDown=$true
Test-DockerEngines
Assert-Docker (@($script:rows | Where-Object {$_.Name -eq 'Docker local engine' -and $_.Status -eq 'FAIL'}).Count -eq 1) 'Remote success cannot hide stopped local engine'
$script:rows.Clear();$script:endpoints['desktop-linux']='ssh://other-server'
Test-DockerEngines
Assert-Docker (@($script:rows | Where-Object {$_.Name -eq 'Docker local engine' -and $_.Status -eq 'FAIL'}).Count -eq 1) 'Remote endpoint in local context is rejected'
$script:endpoints['remote-dev']='ssh://wrong-server'
$threw=$false;try {Ensure-DockerContexts}catch{$threw=$true}
Assert-Docker $threw 'Existing conflicting context preserved with failure'
$script:rows.Clear();$script:Config.DockerRemoteContexts[0].Required=$false
Test-DockerEngines
Assert-Docker (@($script:rows | Where-Object {$_.Name -eq 'Docker remote remote-dev' -and $_.Status -eq 'WARN'}).Count -eq 1) 'Optional remote failure is a warning'

# Run only extracted phase bodies with every host operation replaced.
function Get-PhaseBody([string]$File) {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $File),[ref]$tokens,[ref]$errors)
    $command=$ast.Find({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-Phase'},$true)
    return $command.CommandElements[2].ScriptBlock.GetScriptBlock()
}
function Require-Admin {}
function Test-MachineTools {}
function Test-OracleDeveloper {}
function Ensure-OpenSSHClient {$script:operations.Add('ssh-client')}
function Get-WinGetState {param($Id);return $false}
function Ensure-WinGet {param($Id);$script:operations.Add("package $Id")}
function Get-WindowsOptionalFeature {throw 'Remote/None must never query WSL features'}
function Test-TimeSync {}
$script:Config.NoSleepOnAC=$false;$script:Config.ResyncTime=$false
$phase10=Get-PhaseBody '10-windows-base.ps1';$phase50=Get-PhaseBody '50-docker-wsl.ps1'
foreach($mode in @('None','RemoteCLI')) {
    $script:operations.Clear();$script:Config.DockerMode=$mode;$script:Reboot=$false
    & $phase10; & $phase50
    $expected=if($mode -eq 'None'){0}else{2}
    Assert-Docker ($script:operations.Count -eq $expected) "$mode has no WSL/Desktop mutations"
}
function Get-WindowsOptionalFeature {return @{State='Enabled'}}
function Test-PendingReboot {return $false}
function Get-Service {return @{Status='Running'}}
function Get-CimInstance {return @{StartMode='Auto'}}
function Invoke-Native {param($Command,$Arguments,$Allowed,[switch]$Quiet);return @{Code=0;Output='2.6.0'}}
foreach($mode in @('LocalDesktop','Both')) {
    $script:operations.Clear();$script:Config.DockerMode=$mode;$script:Reboot=$false
    & $phase50
    Assert-Docker (@($script:operations | Where-Object {$_ -eq 'package Docker.DockerDesktop'}).Count -eq 1) "$mode installs Desktop"
    Assert-Docker (@($script:operations | Where-Object {$_ -eq 'package Docker.DockerCLI'}).Count -eq 0) "$mode never installs a second CLI"
}
Write-Host "$passed Docker checks passed; all engines, packages and Windows features simulated."
