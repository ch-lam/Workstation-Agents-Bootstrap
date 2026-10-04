$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Configuration.ps1')
$script:Root=$root
$script:ActiveConfigPath=Join-Path $root 'config.psd1'
$script:Config=@{BackendLoginConfirmed=$false}
$script:results=New-Object 'System.Collections.Generic.List[object]'
function Require-User {}
function Add-Result { param($Name,$Status,$Detail);$script:results.Add([pscustomobject]@{Name=$Name;Status=$Status;Detail=$Detail}) }
function Test-WindowsUpdates { throw 'Validation reached' }
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root '70-validation.ps1'),[ref]$tokens,[ref]$errors)
$command=$ast.Find({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-Phase'},$true)
$body=$command.CommandElements[2].ScriptBlock.GetScriptBlock()
& $body
if (@($script:results | Where-Object Status -eq 'FAIL').Count -ne 1) { throw 'Missing early login failure' }
$instructions=($script:results | Where-Object Status -eq 'MANUAL').Detail
if ($instructions -notmatch 'codex login' -or $instructions -notmatch 'Claude OU Codex' -or $instructions -notmatch '-Action ConfirmLogin' -or $instructions -notmatch [regex]::Escape($script:ActiveConfigPath)) { throw 'Incomplete login instructions' }
$script:Config.BackendLoginConfirmed=$true
try { & $body;throw 'Expected validation call' } catch { if ($_.Exception.Message -ne 'Validation reached') { throw } }
Write-Host '3 backend login checks passed; no login, update search or installation executed.'