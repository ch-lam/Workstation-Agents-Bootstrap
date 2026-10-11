[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$engine=(Get-Process -Id $PID).Path
$failed=@()
foreach ($test in @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'Test-*.ps1' | Sort-Object Name)) {
    & $engine -NoProfile -File $test.FullName
    if ($LASTEXITCODE -ne 0) {$failed+=$test.Name}
}
if ($failed.Count -gt 0) { throw "Failed tests: $($failed -join ', ')" }
Write-Host 'All isolated test scripts passed. No bootstrap or host installer was run.'
