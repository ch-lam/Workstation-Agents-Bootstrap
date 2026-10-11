$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Configuration.ps1')
function Test-BackendConfirmation { return $false }
foreach ($phase in @('00','10','20','30','40','50','60')) {
    $hint=Get-BootstrapContinuation $root (Join-Path $root 'config.psd1') $phase $false
    $admin=$phase -in @('00','10','20')
    if (($hint.Session -match '^Administrator') -ne $admin) { throw "Wrong context: $phase" }
    if ($phase -eq '60') { if ($hint.Command -notmatch '-Action ConfirmLogin') { throw 'Phase 60 must propose login confirmation first' } } elseif ($hint.Command -notmatch "-Phase '[0-9]{2}'") { throw "Unquoted phase: $phase" }
}
if ($null -ne (Get-BootstrapContinuation $root (Join-Path $root 'config.psd1') '70' $false)) { throw 'Phase 70 must finish without installer continuation' }
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path (Join-Path $scratch 'lib') -Force
try {
    Copy-Item (Join-Path $root 'Invoke-Bootstrap.ps1') $scratch
    Copy-Item (Join-Path $root 'lib\Configuration.ps1') (Join-Path $scratch 'lib')
    Copy-Item (Join-Path $root 'lib\Settings.ps1') (Join-Path $scratch 'lib')
    Copy-Item (Join-Path $root 'config.psd1') $scratch
    Set-Content (Join-Path $scratch '20-winget-packages.ps1') 'param($ConfigPath,[switch]$CheckOnly) exit 0'
    $engine=(Get-Process -Id $PID).Path
    $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Phase 20 -ConfigPath (Join-Path $scratch 'config.psd1')
    if ($LASTEXITCODE -ne 0 -or @($output | Where-Object {$_ -eq '[INFO] Next command'}).Count -ne 1 -or ($output -join ' ') -notmatch "-Phase '50'") { throw 'Successful launcher continuation failed' }
    Set-Content (Join-Path $scratch '20-winget-packages.ps1') 'param($ConfigPath,[switch]$CheckOnly,[switch]$WindowsUpdateMandatory) if (-not $WindowsUpdateMandatory) {exit 1}; exit 0'
    $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Phase 20 -ConfigPath (Join-Path $scratch 'config.psd1') -WindowsUpdateMandatory
    if ($LASTEXITCODE -ne 0 -or ($output -join ' ') -notmatch '-WindowsUpdateMandatory') { throw 'Mandatory flag not passed to phase/continuation' }
    $script:WindowsUpdateMandatory=$true
    $hint=Get-BootstrapContinuation $root (Join-Path $root 'config.psd1') '60' $false
    if ($hint.Command -notmatch '-WindowsUpdateMandatory' -or $hint.Detail -notmatch '-WindowsUpdateMandatory') { throw 'Mandatory flag lost in login confirmation/resume' }
    $script:WindowsUpdateMandatory=$false
    Set-Content (Join-Path $scratch '20-winget-packages.ps1') '[CmdletBinding()] param($ConfigPath,[switch]$CheckOnly) if ($VerbosePreference -ne "Continue") {exit 1}; exit 0'
    $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Phase 20 -ConfigPath (Join-Path $scratch 'config.psd1') -Verbose
    if ($LASTEXITCODE -ne 0 -or ($output -join ' ') -notmatch '-Verbose') { throw 'Verbose not transmitted to phase/continuation' }
    foreach ($code in @(1,3010)) {
        Set-Content (Join-Path $scratch '20-winget-packages.ps1') "param(`$ConfigPath,[switch]`$CheckOnly) exit $code"
        $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Phase 20 -ConfigPath (Join-Path $scratch 'config.psd1')
        if ($LASTEXITCODE -ne $code -or ($output -join ' ') -match 'Next command') { throw "Unsafe continuation after exit $code" }
    }
    Write-Host '14 continuation checks passed; phases simulated, no installation.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+[IO.Path]::DirectorySeparatorChar)) { throw 'Invalid scratch cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
