$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path (Join-Path $scratch 'lib') -Force
try {
    Copy-Item (Join-Path $root 'Invoke-Bootstrap.ps1') $scratch
    Copy-Item (Join-Path $root 'lib\Configuration.ps1') (Join-Path $scratch 'lib')
    Copy-Item (Join-Path $root 'lib\Settings.ps1') (Join-Path $scratch 'lib')
    Copy-Item (Join-Path $root 'config.psd1') $scratch
    $files=@{'00'='00-preflight';'10'='10-windows-base';'20'='20-winget-packages';'50'='50-docker-wsl';'30'='30-dev-runtime';'40'='40-ai-cli';'60'='60-workstation-config'}
    foreach($phase in $files.Keys) {
        $fixture="param(`$ConfigPath,[switch]`$CheckOnly) Write-Output 'PHASE:$phase'; exit 0"
        if($phase -eq '00') { $fixture="param(`$ConfigPath,[switch]`$CheckOnly) if (-not `$CheckOnly) {exit 1}; Write-Output 'PHASE:00'; Write-Output ('CONFIG:'+[IO.Path]::GetFileName(`$ConfigPath)); exit 0" }
        Set-Content (Join-Path $scratch ($files[$phase]+'.ps1')) $fixture
    }
    $engine=(Get-Process -Id $PID).Path
    foreach($stage in @('Preflight','Administrator','User')) {
        $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Stage $stage
        if($LASTEXITCODE -ne 0) { throw "Stage failed: $stage" }
        $phases=@($output | Where-Object {$_ -like 'PHASE:*'}) -join ','
        $expected=@{Preflight='PHASE:00';Administrator='PHASE:10,PHASE:20,PHASE:50';User='PHASE:30,PHASE:40,PHASE:60'}[$stage]
        if($phases -ne $expected) {throw "Wrong stage order: $phases"}
    }
    Copy-Item (Join-Path $scratch 'config.psd1') (Join-Path $scratch 'config.local.psd1')
    $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Stage Preflight
    if ($LASTEXITCODE -ne 0 -or $output -notcontains 'CONFIG:config.local.psd1') { throw 'Local configuration not selected by default' }
    $output=& $engine -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $scratch 'Invoke-Bootstrap.ps1') -Stage Preflight -ConfigPath (Join-Path $scratch 'config.psd1')
    if ($LASTEXITCODE -ne 0 -or $output -notcontains 'CONFIG:config.psd1') { throw 'Explicit configuration not respected' }
    Write-Host '5 stage checks passed; simulated phases only, default/local/explicit configuration verified.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+[IO.Path]::DirectorySeparatorChar)) {throw 'Invalid cleanup target'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
