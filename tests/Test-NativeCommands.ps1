[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Common.ps1')
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $scratch
try {
    $script:Log=Join-Path $scratch 'native.log'
    $engine=(Get-Process -Id $PID).Path
    $fixture=Join-Path $scratch 'native fixture.ps1'
    Set-Content -LiteralPath $fixture -Value 'param([int]$Code) [Console]::Out.WriteLine("fixture output"); [Console]::Error.WriteLine("fixture diagnostic"); exit $Code'
    $arguments=@('-NoProfile','-ExecutionPolicy','RemoteSigned','-File',$fixture,'-Code','0')
    $result=Invoke-Native $engine $arguments -Quiet
    if ($result.Code -ne 0 -or $result.Output -notmatch 'fixture output' -or $result.Output -notmatch 'fixture diagnostic') { throw 'Successful output/stderr not captured correctly' }
    $threw=$false
    try { $null=Invoke-Native 'bootstrap-missing-command-fixture.exe' -Quiet } catch { $threw=$true }
    if (-not $threw) { throw 'Missing command reused previous successful exit code' }
    $arguments[-1]='7'
    $threw=$false
    try { $null=Invoke-Native $engine $arguments -Quiet } catch { $threw=$_.Exception.Message -match 'exit 7' }
    if (-not $threw) { throw 'Nonzero exit code not rejected' }
    $result=Invoke-Native $engine $arguments -Allowed @(0,7) -Quiet
    if ($result.Code -ne 7) { throw 'Explicitly allowed exit code not returned' }
    Write-Host '4 native command checks passed; inert child processes only.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+[IO.Path]::DirectorySeparatorChar)) { throw 'Invalid cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
