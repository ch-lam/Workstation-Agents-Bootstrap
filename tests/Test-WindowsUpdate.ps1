$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\WindowsUpdate.ps1')
$script:rows=New-Object 'System.Collections.Generic.List[object]'
function Add-Result { param($Name,$Status,$Detail); $script:rows.Add([pscustomobject]@{Name=$Name;Status=$Status;Detail=$Detail}) }
function Get-WindowsUpdateInventory { return $script:fixture }
$script:WindowsUpdateMandatory=$true
$passed=0
function Assert-Update([bool]$Condition,[string]$Message) { if (-not $Condition) {throw "TEST FAILED: $Message"}; $script:passed++; Write-Host "PASS: $Message" }
$script:fixture=[pscustomobject]@{ResultCode=2;Updates=@();RebootRequired=$false}
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object {$_.Name -eq 'Windows Update' -and $_.Status -eq 'PASS'}).Count -eq 1) 'Clean successful search produces PASS'
$script:rows.Clear()
$script:fixture.Updates=@([pscustomobject]@{Title='Security update';Optional=$false;Downloaded=$true})
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -eq 'FAIL').Count -eq 1 -and @($script:rows | Where-Object Detail -eq 'Security update').Count -eq 1) 'Downloaded but uninstalled update remains pending and listed'
$script:rows.Clear()
$script:fixture.Updates=@([pscustomobject]@{Title='Optional driver';Optional=$true;Downloaded=$false})
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -eq 'FAIL').Count -eq 0 -and @($script:rows | Where-Object Name -eq 'Optional updates').Count -eq 1) 'Optional updates informational rather than blocking'
$script:rows.Clear(); $script:fixture.Updates=@(); $script:fixture.RebootRequired=$true
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object {$_.Name -eq 'Windows Update restart' -and $_.Status -eq 'FAIL'}).Count -eq 1) 'Update Agent reboot requirement reported separately'
$script:rows.Clear(); $script:fixture.ResultCode=3
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -eq 'PASS').Count -eq 0 -and @($script:rows | Where-Object Status -eq 'FAIL').Count -eq 1) 'Partial success cannot certify no updates'
$script:rows.Clear()
function Get-WindowsUpdateInventory { throw 'Search timed out or server unavailable' }
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -eq 'PASS').Count -eq 0 -and @($script:rows | Where-Object Status -eq 'FAIL').Count -eq 1) 'Unavailable service/timeout produces unknown failure'
$script:WindowsUpdateMandatory=$false
$script:rows.Clear()
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -ne 'INFO').Count -eq 0) 'Default unavailable service is informational'
function Get-WindowsUpdateInventory { return $script:fixture }
$script:rows.Clear(); $script:fixture.ResultCode=2; $script:fixture.RebootRequired=$true
$script:fixture.Updates=@([pscustomobject]@{Title='Defender update';Optional=$false;Downloaded=$true})
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -ne 'INFO').Count -eq 0 -and @($script:rows | Where-Object Name -eq 'Windows Update restart').Count -eq 1) 'Default pending update and WUA restart are informational'
$script:rows.Clear(); $script:fixture.ResultCode=3
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object Status -ne 'INFO').Count -eq 0) 'Default partial search is informational'
$script:rows.Clear(); $script:fixture.ResultCode=2; $script:fixture.RebootRequired=$false; $script:fixture.Updates=@()
Test-WindowsUpdates
Assert-Update (@($script:rows | Where-Object {$_.Name -eq 'Windows Update' -and $_.Status -eq 'INFO'}).Count -eq 1) 'Default clean scan is INFO'
Write-Host "$passed Windows Update checks passed. No live update search performed."

. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\Common.ps1')
function Test-Path { param($Path); return $Path -like '*\WindowsUpdate\*' }
function Get-ItemProperty { return $null }
$script:WindowsUpdateMandatory=$false
if (Test-PendingReboot) { throw 'WU-only registry marker blocks default mode' }
$script:WindowsUpdateMandatory=$true
if (-not (Test-PendingReboot)) { throw 'WU registry marker missing in mandatory mode' }
Write-Host '2 Windows Update registry policy checks passed.'