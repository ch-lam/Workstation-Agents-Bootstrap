[CmdletBinding()]
param(
    [ValidateSet('00','10','20','30','40','50','60','70')][string[]]$Phase=@('00'),
    [ValidateSet('Preflight','Administrator','User')][string]$Stage,
    [switch]$CheckOnly,[switch]$WindowsUpdateMandatory,
    [string]$ConfigPath
)
$ErrorActionPreference='Stop'
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
$script:WindowsUpdateMandatory=[bool]$WindowsUpdateMandatory
$map=@{ '00'='00-preflight.ps1'; '10'='10-windows-base.ps1'; '20'='20-winget-packages.ps1';
    '30'='30-dev-runtime.ps1'; '40'='40-ai-cli.ps1'; '50'='50-docker-wsl.ps1';
    '60'='60-workstation-config.ps1'; '70'='70-validation.ps1' }
if ($Stage) {
    if ($PSBoundParameters.ContainsKey('Phase')) { throw 'Use either -Stage or -Phase, not both.' }
    $Phase=switch ($Stage) {
        'Preflight' { '00'; $CheckOnly=$true }
        'Administrator' { '10';'20';'50' }
        'User' { '30';'40';'60' }
    }
}
$engine=(Get-Process -Id $PID).Path
$ConfigPath=(Resolve-Path -LiteralPath $ConfigPath).Path
. (Join-Path $PSScriptRoot 'lib\Configuration.ps1')
$failed=$false
$orderedPhases=@('00','10','20','50','30','40','60','70')
foreach ($number in @($orderedPhases | Where-Object {$_ -in $Phase})) {
    $arguments=@('-NoProfile','-File',(Join-Path $PSScriptRoot $map[$number]),'-ConfigPath',$ConfigPath)
    if ($CheckOnly) { $arguments+='-CheckOnly' }
    if ($VerbosePreference -eq 'Continue') { $arguments+='-Verbose' }
    if ($WindowsUpdateMandatory) { $arguments+='-WindowsUpdateMandatory' }
    $previousLauncher=$env:AGENT_BOOTSTRAP_LAUNCHER
    try {
        $env:AGENT_BOOTSTRAP_LAUNCHER='1'
        & $engine @arguments
        $phaseExit=$LASTEXITCODE
    } finally { $env:AGENT_BOOTSTRAP_LAUNCHER=$previousLauncher }
    if ($phaseExit -eq 3010) {
        Write-Host '[MANUAL] Redemarrer Windows, puis reprendre dans un terminal ADMINISTRATEUR du meme compte.' -ForegroundColor Yellow
        $resume=Get-BootstrapLaunchCommand (Join-Path $PSScriptRoot 'Invoke-Bootstrap.ps1') $ConfigPath -Phase ($Phase -join ',')
        Write-Host $resume
        exit 3010
    }
    if ($phaseExit -ne 0) {
        $failed=$true
        if (-not $CheckOnly) { exit $phaseExit }
    }
}
if ($failed) { exit 1 }
Write-BootstrapContinuation $PSScriptRoot $ConfigPath $number ([bool]$CheckOnly)
exit 0
