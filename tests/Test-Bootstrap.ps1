[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$passed=0
function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    $script:passed++
    Write-Host "PASS: $Message"
}
$files=@(Get-ChildItem -LiteralPath $root -Recurse -Filter *.ps1)
foreach ($file in $files) {
    $tokens=$null; $errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert-True (@($errors).Count -eq 0) "Syntax: $($file.Name)"
}
$null=Import-PowerShellDataFile (Join-Path $root 'config.psd1')
. (Join-Path $root 'lib\Common.ps1')
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid().ToString())
$null=New-Item -ItemType Directory -Path $scratch
try {
    $script:Log=Join-Path $scratch 'test.log'
    $script:Check=$true
    $script:mutations=0
    Invoke-Change 'Dry run guard' { $script:mutations++ }
    Assert-True ($script:mutations -eq 0) 'CheckOnly never executes the change body'
    $script:Check=$false
    Invoke-Change 'Apply guard' { $script:mutations++ }
    Assert-True ($script:mutations -eq 1) 'Apply executes the change body once'

    $nativeOriginal=(Get-Item Function:\Invoke-Native).ScriptBlock
    function Invoke-Native { param($Command,$Arguments,$Allowed,[switch]$Quiet); [pscustomobject]@{Code=0;Output=$script:fixture} }
    $script:fixture=@'
Power Setting GUID: 29f6c1db-86da-48c5-9fdb-f2b67b1f44da
  Minimum Possible Setting: 0x00000000
  Maximum Possible Setting: 0xffffffff
  Possible Settings increment: 0x00000001
  Current AC Power Setting Index: 0x00000708
  Current DC Power Setting Index: 0x00000384
Power Setting GUID: 9d7815a6-7ee4-497e-8888-515a05f02364
  Minimum Possible Setting: 0x00000000
  Maximum Possible Setting: 0xffffffff
  Current AC Power Setting Index: 0x00000e10
  Current DC Power Setting Index: 0x00000708
'@
    $power=Get-PowerAC
    Assert-True ($power.Sleep -eq 1800 -and $power.Hibernate -eq 3600) 'Power parser selects AC indexes, not possible min/max or DC'
    $script:fixture=$script:fixture.Replace('Power Setting GUID','GUID du parametre').Replace('Current AC Power Setting Index','Index secteur').Replace('Current DC Power Setting Index','Index batterie')
    $power=Get-PowerAC
    Assert-True ($power.Sleep -eq 1800 -and $power.Hibernate -eq 3600) 'AC parsing is independent of localized labels'

    function Invoke-Native { param($Command,$Arguments,$Allowed,[switch]$Quiet); [pscustomobject]@{Code=-1978335212;Output='No apps'} }
    Assert-True (-not (Get-WinGetState 'Example.Id')) 'Only WinGet no-app HRESULT means absent'
    function Invoke-Native { param($Command,$Arguments,$Allowed,[switch]$Quiet); throw 'Network/source failure' }
    $threw=$false
    try { $null=Get-WinGetState 'Example.Id' } catch { $threw=$true }
    Assert-True $threw 'WinGet source/network failure propagates rather than triggering installation'

    $toolOriginal=(Get-Item Function:\Test-Tool).ScriptBlock
    function Test-Tool { param($Command,$Arguments,[switch]$Optional); return $true }
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        $output=if ($Arguments[0] -eq '--version') {$script:nodeVersion} else {$script:nodeLts}
        [pscustomobject]@{Code=0;Output=$output}
    }
    $script:nodeVersion='v20.19.0'; $script:nodeLts='Iron'
    Assert-True (-not (Test-NodeMinimum)) 'Node <22 is rejected'
    $script:nodeVersion='v26.0.0'; $script:nodeLts='not-lts'
    Assert-True (-not (Test-NodeMinimum)) 'Even-major Current release is rejected'
    $script:nodeVersion='v24.0.0'; $script:nodeLts='Krypton'
    Assert-True (Test-NodeMinimum) 'Node >=22 reporting LTS is accepted'
    $script:Config=@{NtpProbeHost='time.example';MaximumTimeOffsetSeconds=5}
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        $output=if ($Arguments[0] -eq '/query') {$script:timeStatus} else {$script:timeProbe}
        [pscustomobject]@{Code=0;Output=$output}
    }
    $script:timeStatus="Indicateur : 3(non synchronise)`nStrate : 0"
    $script:timeProbe='12:00:00, +00.1250000s'
    $script:Rows.Clear()
    Test-TimeSync
    Assert-True (@($script:Rows | Where-Object Status -eq FAIL).Count -eq 1) 'NTP rejects unsynchronized Windows time even with successful query exit'
    Assert-True (@($script:Rows | Where-Object {$_.Name -eq 'NTP recovery' -and $_.Detail -match 'Start-Service -Name W32Time' -and $_.Detail -match 'w32tm /resync /rediscover'}).Count -eq 1) 'Unsynchronized clock prints administrator recovery commands'
    $script:timeStatus="Indicateur : 0(aucun avertissement)`nStrate : 3"
    $script:Rows.Clear()
    Test-TimeSync
    Assert-True (@($script:Rows | Where-Object Status -eq FAIL).Count -eq 0) 'NTP accepts synchronized state and measured offset below threshold'
    $script:timeProbe='12:00:00, +10.0000000s'
    $script:Rows.Clear()
    Test-TimeSync
    Assert-True (@($script:Rows | Where-Object {$_.Name -eq 'NTP recovery' -and $_.Detail -match 'Offset'}).Count -eq 1) 'Excessive drift prints recovery guidance'
    $script:timeProbe='Request timed out'
    $script:Rows.Clear()
    Test-TimeSync
    Assert-True (@($script:Rows | Where-Object {$_.Name -eq 'NTP recovery' -and $_.Detail -match 'UDP 123'}).Count -eq 1) 'Unreachable NTP probe prints network-specific guidance'
    Set-Item Function:\Test-Tool $toolOriginal
    Set-Item Function:\Invoke-Native $nativeOriginal
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        if ($Allowed -notcontains -2147023834) { throw 'Service stopped HRESULT was not handled' }
        [pscustomobject]@{Code=-2147023834;Output='The service has not been started. (0x80070426)'}
    }
    $script:Rows.Clear()
    Test-TimeSync
    Assert-True (@($script:Rows | Where-Object {$_.Name -eq 'NTP recovery' -and $_.Detail -match 'Start-Service'}).Count -eq 1) 'Stopped W32Time HRESULT prints recovery instead of aborting phase'
    Set-Item Function:\Invoke-Native $nativeOriginal
    function Test-Path { param($Path); return $false }
    function Get-ItemProperty { param($Path,$Name,$ErrorAction); [pscustomobject]@{PendingFileRenameOperations=@('','')} }
    Assert-True (-not (Test-PendingReboot)) 'Empty PendingFileRenameOperations is not a pending reboot'
    function Get-ItemProperty { param($Path,$Name,$ErrorAction); [pscustomobject]@{PendingFileRenameOperations=@('\??\C:\Example.dll','')} }
    Assert-True (Test-PendingReboot) 'Nonempty pending file operation remains reported'
    Remove-Item Function:\Test-Path
    Remove-Item Function:\Get-ItemProperty
    Assert-True ((Get-RAMLevel 15.8 8 16) -eq 'PASS') 'Nominal 16 GB with hardware reservation does not warn'
    Assert-True ((Get-RAMLevel 12 8 16) -eq 'WARN') 'Materially lower recommended RAM still warns'
    Assert-True ((Get-RAMLevel 7 8 16) -eq 'FAIL') 'RAM below minimum remains blocking'
    function Get-Command { param($Name,$ErrorAction); return [pscustomobject]@{Source='C:\Users\Fixture\AppData\Local\Microsoft\WindowsApps\python.exe'} }
    $script:Rows.Clear()
    $null=Test-Tool 'python.exe' -Optional
    Assert-True ($script:Rows[0].Status -eq 'WARN') 'Python Store alias is a warning during preflight inventory'
    $script:Rows.Clear()
    $null=Test-Tool 'python.exe'
    Assert-True ($script:Rows[0].Status -eq 'FAIL') 'Python Store alias remains blocking during final runtime validation'
    Remove-Item Function:\Get-Command

    $summary="$passed checks passed. No workstation packages/features installed."
    Write-Host $summary
} finally {
    # Delete only the exact verified scratch directory created by this test.
    $resolved=[IO.Path]::GetFullPath($scratch)
    $testRoot=[IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')+'\'
    if ($resolved.StartsWith($testRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'scratch-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
