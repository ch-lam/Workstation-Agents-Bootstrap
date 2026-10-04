$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Configuration.ps1')
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid().ToString())
$null=New-Item -ItemType Directory -Path $scratch
$passed=0
function Assert-Configuration([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }
    $script:passed++
    Write-Host "PASS: $Message"
}
try {
    $sample=@{Name="O'Brien";Path='C:\AI\Projects';Enabled=$true;Count=3;Items=@('one',"a'b");Literal='$(throw ''must not execute'')'}
    $path=Join-Path $scratch 'roundtrip.psd1'
    [IO.File]::WriteAllText($path,(ConvertTo-DataLiteral $sample),[Text.UTF8Encoding]::new($true))
    $loaded=Import-PowerShellDataFile -LiteralPath $path
    Assert-Configuration ($loaded.Name -eq $sample.Name -and $loaded.Literal -eq $sample.Literal) 'Quoted values roundtrip as data without execution'
    Assert-Configuration ($loaded.Enabled -eq $true -and $loaded.Count -eq 3 -and $loaded.Items.Count -eq 2) 'Boolean, integer and array types preserved'
    Assert-Configuration ((Test-AbsoluteWindowsPath 'C:\AI\Projects') -and -not (Test-AbsoluteWindowsPath '.\Projects')) 'Relative Windows paths rejected'
    $command=Get-BootstrapLaunchCommand "D:\Test User's Folder\Invoke-Bootstrap.ps1" "D:\Test User's Folder\config.local.psd1" -Phase '00' -CheckOnly
    Assert-Configuration ($command -eq "& 'D:\Test User''s Folder\Invoke-Bootstrap.ps1' -Phase '00' -CheckOnly -ConfigPath 'D:\Test User''s Folder\config.local.psd1'") 'Copy/paste command preserves paths with spaces/apostrophes and exact config'
    $hint=Get-ApplyNextStep 'D:\Test User\Bootstrap' 'D:\Test User\config.local.psd1' '00'
    Assert-Configuration ($hint.Command -match '-Phase ''10'',''20'',''50''' -and $hint.Command -notmatch '-CheckOnly' -and $hint.Session -match 'Administrator') 'Preflight suggests actual base installation in administrator session'
    $hint=Get-ApplyNextStep 'D:\Bootstrap' 'D:\config.local.psd1' '40'
    Assert-Configuration ($hint.Command -match '-Phase ''40'' ' -and $hint.Session -match 'non-elevated') 'User phase suggests matching installation without elevation'
    $probePath=Join-Path $scratch 'argument-probe.ps1'
    [IO.File]::WriteAllText($probePath, '[CmdletBinding()] param([ValidateSet("00","10","20")][string[]]$Phase,[string]$ConfigPath,[switch]$CheckOnly) $Phase -join "|"')
    $probeCommand=Get-BootstrapLaunchCommand $probePath $path -Phase '00,10,20'
    $bound=& ([scriptblock]::Create($probeCommand))
    Assert-Configuration ($bound -eq '00|10|20') 'Generated command binds quoted phases with leading zero preserved'
    $wizardAnswers=New-Object 'System.Collections.Generic.Queue[string]'
    function Read-Host { param($Prompt); if ($wizardAnswers.Count -eq 0) { throw "Unexpected prompt: $Prompt" }; return $wizardAnswers.Dequeue() }
    $configPath=Join-Path $scratch 'config.local.psd1'
    foreach ($answer in @('non','oui',"O'Brien",'user@example.invalid','','non','oui')) { $wizardAnswers.Enqueue($answer) }
    & (Join-Path $root 'Configure-Bootstrap.ps1') -Action Configuration -ConfigPath $configPath
    $config=Import-PowerShellDataFile -LiteralPath $configPath
    Assert-Configuration ($config.EnableDocker -eq $false -and $config.GitUserName -eq "O'Brien" -and $config.Extensions.Count -eq 7 -and $config.BackendLoginConfirmed -eq $false) 'Question/answer flow creates complete usable config with preserved defaults'
    foreach ($answer in @('oui','oui','','','','non')) { $wizardAnswers.Enqueue($answer) }
    & (Join-Path $root 'Configure-Bootstrap.ps1') -Action Configuration -ConfigPath $configPath -PreviewOnly
    $after=Import-PowerShellDataFile -LiteralPath $configPath
    Assert-Configuration ($after.EnableDocker -eq $false) 'PreviewOnly does not save changed answers'
    $wizardAnswers.Enqueue('oui')
    $null=Save-DataFile $config $configPath
    Assert-Configuration (@(Get-ChildItem -LiteralPath $scratch -Filter '*.bak').Count -eq 1) 'Existing configuration backed up before replacement'
    $extended=Import-PowerShellDataFile -LiteralPath $configPath
    $extended.UnknownOption='Z:\missing\release.psd1'
    $extended.AnotherUnknownOption='Z:\missing'
    [IO.File]::WriteAllText($configPath,(ConvertTo-DataLiteral $extended),[Text.UTF8Encoding]::new($true))
    foreach ($answer in @('oui','oui')) { $wizardAnswers.Enqueue($answer) }
    & (Join-Path $root 'Configure-Bootstrap.ps1') -Action ConfirmLogin -ConfigPath $configPath
    $saved=Import-PowerShellDataFile -LiteralPath $configPath
    Assert-Configuration ($saved.BackendLoginConfirmed -and -not $saved.ContainsKey('UnknownOption') -and -not $saved.ContainsKey('AnotherUnknownOption') -and $saved.NoSleepOnAC -eq $extended.NoSleepOnAC) 'Saving config ignores unknown keys and preserves workstation settings'
    Write-Host "$passed configuration checks passed."
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    $testRoot=[IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')+'\'
    if ($resolved.StartsWith($testRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'scratch-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
