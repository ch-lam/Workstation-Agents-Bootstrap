$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Storage.ps1')
$script:results=New-Object 'System.Collections.Generic.List[object]'
$script:volumes=@(
    [pscustomobject]@{Name='C:\';DeviceID='system';FreeSpace=20GB;Capacity=100GB},
    [pscustomobject]@{Name='D:\';DeviceID='data';FreeSpace=40GB;Capacity=200GB},
    [pscustomobject]@{Name='C:\MountedData\';DeviceID='mounted';FreeSpace=50GB;Capacity=200GB}
)
function Get-CimInstance { param($ClassName); return $script:volumes }
function Add-Result { param($Name,$Status,$Detail); $script:results.Add([pscustomobject]@{Name=$Name;Status=$Status;Detail=$Detail}) }
$passed=0
function Assert-Storage([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    $script:passed++; Write-Host "PASS: $Message"
}
$targets=@(
    [pscustomobject]@{Role='Workspace';Path='D:\AI\Projects';MinimumGB=30},
    [pscustomobject]@{Role='Cache';Path='D:\AI\Cache';MinimumGB=30},
    [pscustomobject]@{Role='System';Path='C:\Windows';MinimumGB=10}
)
Test-StorageVolumes $targets
Assert-Storage ($script:results.Count -eq 2 -and @($script:results | Where-Object Status -ne PASS).Count -eq 0) 'D targets and C system checked once each with different thresholds'
Assert-Storage (@($script:results | Where-Object {$_.Name -eq 'Disk D:\' -and $_.Detail -match 'Workspace=.*Cache='}).Count -eq 1) 'Disk report explains every configured use'
$script:results.Clear(); $script:volumes[1].FreeSpace=29GB
Test-StorageVolumes $targets
Assert-Storage (@($script:results | Where-Object {$_.Name -eq 'Disk D:\' -and $_.Status -eq 'FAIL'}).Count -eq 1) 'Insufficient D space fails even when C has enough system space'
$script:results.Clear(); $script:volumes[1].FreeSpace=40GB; $script:volumes[0].FreeSpace=9GB
Test-StorageVolumes $targets
Assert-Storage (@($script:results | Where-Object {$_.Name -eq 'Disk C:\' -and $_.Status -eq 'FAIL'}).Count -eq 1) 'Windows/temp volume remains checked with workspace on D'
$script:results.Clear()
Test-StorageVolumes @([pscustomobject]@{Role='Workspace';Path='E:\New\Projects';MinimumGB=30})
Assert-Storage ($script:results[0].Status -eq 'FAIL') 'Missing destination drive fails before installation'
$script:results.Clear()
Test-StorageVolumes @([pscustomobject]@{Role='Workspace';Path='C:\MountedData\New\Projects';MinimumGB=30})
Assert-Storage ($script:results[0].Name -eq 'Disk C:\MountedData\' -and $script:results[0].Status -eq 'PASS') 'Longest volume mount prefix selected for uncreated directory'
$script:results.Clear()
Test-StorageVolumes @([pscustomobject]@{Role='Workspace';Path='.\Projects';MinimumGB=30})
Assert-Storage ($script:results[0].Status -eq 'FAIL') 'Relative target is not silently evaluated on C'
Write-Host "$passed storage checks passed."
