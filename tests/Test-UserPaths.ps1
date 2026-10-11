$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Common.ps1')
$passed=0
function Assert-Paths([bool]$Condition,[string]$Message){if(-not $Condition){throw "TEST FAILED: $Message"};$script:passed++}
function Add-Result {param($Name,$Status,$Detail)}
function Invoke-Native {param($Command,$Arguments,$Allowed,[switch]$Quiet);return @{Code=0;Output=$script:prefix}}
$script:Check=$true
$script:prefix=Join-Path $env:USERPROFILE 'AppData\Roaming\npm'
Assert-Paths ((Get-UserNpmPrefix) -eq $script:prefix) 'Personal npm prefix accepted in CheckOnly without write probe'
foreach($bad in @((Join-Path $env:ProgramFiles 'nodejs'),($env:USERPROFILE+'-other\npm'),'relative\npm')){
    $script:prefix=$bad;$failed=$false
    try{$null=Get-UserNpmPrefix}catch{$failed=$true}
    Assert-Paths $failed 'System, sibling profile and relative prefixes rejected'
}
$script:mutations=0
function Invoke-Change {param($Name,$Action);if(-not $script:Check){$script:mutations++; & $Action}}
Ensure-PathEntry (Join-Path $env:USERPROFILE 'fixture-npm-path-that-does-not-exist') User
Assert-Paths ($script:mutations -eq 0) 'CheckOnly never writes persistent PATH'
$script:Config=@{OracleDeveloper=@{Enabled=$false}}
Test-OracleDeveloper
Assert-Paths $true 'Disabled Oracle has no prerequisite'
$script:Config.OracleDeveloper=@{Enabled=$true;SqlclHome='';JavaHome=''}
$failed=$false;try{Test-OracleDeveloper}catch{$failed=$true}
Assert-Paths $failed 'Missing Oracle parameters fail before running a command'
$script:Config.OracleDeveloper.SqlclHome=Join-Path $env:USERPROFILE 'sqlcl'
$script:Config.OracleDeveloper.JavaHome=Join-Path $env:ProgramFiles 'fixture-java'
$failed=$false;try{Test-OracleDeveloper}catch{$failed=$true}
Assert-Paths $failed 'User-owned Oracle binaries rejected for machine deployment'
Write-Host "$passed user-path and Oracle checks passed; no persistent PATH or software changes."
