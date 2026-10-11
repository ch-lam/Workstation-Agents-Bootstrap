Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'Settings.ps1')

function ConvertTo-DataLiteral {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return '$null' }
    if ($Value -is [bool]) { if ($Value) { return '$true' }; return '$false' }
    if ($Value -is [string]) { return "'" + $Value.Replace("'","''") + "'" }
    if ($Value -is [int] -or $Value -is [long]) { return [string]$Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $lines=@('@{')
        foreach ($key in @($Value.Keys | Sort-Object)) {
            $lines+='    '+(ConvertTo-DataLiteral ([string]$key))+' = '+(ConvertTo-DataLiteral $Value[$key])
        }
        return ($lines+ '}' -join "`r`n")
    }
    if ($Value -is [array]) { return '@(' + ((@($Value | ForEach-Object { ConvertTo-DataLiteral $_ })) -join ', ') + ')' }
    throw "Unsupported configuration value: $($Value.GetType().Name)"
}
function Test-AbsoluteWindowsPath {
    param([string]$Value)
    return ($Value -match '^[a-zA-Z]:[\\/]' -or $Value -match '^\\\\[^\\]+\\[^\\]+')
}
function Get-BootstrapLaunchCommand {
    param([string]$ScriptPath,[string]$ConfigPath,[string]$Phase='',[switch]$CheckOnly)
    $command='& '+(ConvertTo-DataLiteral ([IO.Path]::GetFullPath($ScriptPath)))
    if ($Phase) { $command+=' -Phase '+((@($Phase.Split(',') | ForEach-Object { ConvertTo-DataLiteral $_.Trim() })) -join ',') }
    if ($CheckOnly) { $command+=' -CheckOnly' }
    $command+=' -ConfigPath '+(ConvertTo-DataLiteral ([IO.Path]::GetFullPath($ConfigPath)))
    $mandatory=Get-Variable -Name WindowsUpdateMandatory -Scope Script -ErrorAction SilentlyContinue
    if ($mandatory -and $mandatory.Value) { $command+=' -WindowsUpdateMandatory' }
    if ($VerbosePreference -eq 'Continue') { $command+=' -Verbose' }
    return $command
}
function Get-ApplyNextStep {
    param([string]$Root,[string]$ConfigPath,[string]$Phase)
    $nextPhase=if ($Phase -eq '00') {'10,20,50'} else {$Phase}
    $session=if ($Phase -in @('00','10','20','50')) {'Administrator terminal; finish 10,20,50 before switching accounts'} else {'Normal non-elevated terminal under the target workstation user'}
    $command=Get-BootstrapLaunchCommand (Join-Path $Root 'Invoke-Bootstrap.ps1') $ConfigPath -Phase $nextPhase
    [pscustomobject]@{Command=$command;Session=$session}
}
function Get-BootstrapContinuation {
    param([string]$Root,[string]$ConfigPath,[string]$Phase,[bool]$CheckOnly)
    if ($Phase -eq '70') { return $null }
    if ($CheckOnly) { return Get-ApplyNextStep $Root $ConfigPath $Phase }
    if ($Phase -eq '60' -and -not (Test-BackendConfirmation)) {
        $command=Get-BootstrapLaunchCommand (Join-Path $Root 'Configure-Bootstrap.ps1') $ConfigPath
        return [pscustomobject]@{
            Command=($command+' -Action ConfirmLogin')
            Session='Normal non-elevated PowerShell 7 terminal under the target workstation user'
            Detail=(Get-BackendLoginInstructions $Root $ConfigPath)
        }
    }
    $next=@{'00'='10,20,50';'10'='20,50';'20'='50';'30'='40,60';'40'='60';'50'='30,40,60';'60'='70'}[$Phase]
    $session=if ($Phase -in @('00','10','20')) {'Administrator terminal; finish 10,20,50 before switching accounts'} else {'Normal non-elevated PowerShell 7 terminal under the target workstation user'}
    $command=Get-BootstrapLaunchCommand (Join-Path $Root 'Invoke-Bootstrap.ps1') $ConfigPath -Phase $next
    $detail=switch ($Phase) {
        '50' {'Administrator block complete. Switch once to the target standard account for 30,40,60, logins and 70. For LocalDesktop/Both, start Docker Desktop there and wait for its Linux engine.'}
        '60' {'Before validation, complete manual backend login and confirm it through Configure-Bootstrap.ps1 -Action ConfirmLogin.'}
        default {''}
    }
    [pscustomobject]@{Command=$command;Session=$session;Detail=$detail}
}
function Write-BootstrapContinuation {
    param([string]$Root,[string]$ConfigPath,[string]$Phase,[bool]$CheckOnly)
    $hint=Get-BootstrapContinuation $Root $ConfigPath $Phase $CheckOnly
    if (-not $hint) {
        if ($CheckOnly) {
            Write-Host '[PASS] Controles CheckOnly reussis. Bootstrap termine (sonde d ecriture non executee).' -ForegroundColor Green
        } else { Write-Host '[PASS] Socle valide. Bootstrap termine.' -ForegroundColor Green }
        Write-Host 'Vous pouvez installer et configurer le harness de votre choix selon sa propre documentation.' -ForegroundColor Cyan
        return
    }
    Write-Host '[INFO] Next command' -ForegroundColor Cyan
    Write-Host "Session: $($hint.Session)." -ForegroundColor Cyan
    if ($hint.PSObject.Properties['Detail'] -and $hint.Detail) { Write-Host $hint.Detail }
    Write-Host $hint.Command
}
function Get-BackendLoginInstructions {
    param([string]$Root,[string]$ConfigPath)
    $confirm=(Get-BootstrapLaunchCommand (Join-Path $Root 'Configure-Bootstrap.ps1') $ConfigPath)+' -Action ConfirmLogin'
    $resume=Get-BootstrapLaunchCommand (Join-Path $Root 'Invoke-Bootstrap.ps1') $ConfigPath -Phase '70'
    return @"
AVANT la phase 70 : connecter au moins un CLI, Claude OU Codex.
Contexte : PowerShell 7 UTILISATEUR NORMAL, meme compte Windows que le harness.
Claude : lancer claude, suivre le login navigateur (ou /login dans Claude), poser une question et verifier la reponse, puis /exit.
Codex : lancer codex login, terminer le login navigateur, puis codex et tester une conversation avant de quitter.
Apres une conversation reussie, confirmer et enregistrer avec :
$confirm
Cet assistant enregistre une confirmation personnelle liee au SID Windows, hors du depot et de la configuration partagee.
ENSUITE seulement, lancer la validation :
$resume
Les logins GitHub (gh auth login) et Grok (grok login) sont independants de ce prerequis.
"@
}
function Read-Answer {
    param([string]$Question,[string]$Default='', [scriptblock]$Validate={param($v) $true})
    while ($true) {
        $suffix=if ($Default) { " [$Default]" } else { '' }
        $value=Read-Host ($Question+$suffix)
        if (-not $value) { $value=$Default }
        if (& $Validate $value) { return $value }
        Write-Host 'Valeur invalide, recommencez.' -ForegroundColor Yellow
    }
}
function Read-YesNo {
    param([string]$Question,[bool]$Default=$false)
    $choice=if ($Default) {'oui'} else {'non'}
    $value=Read-Answer "$Question (oui/non)" $choice {param($v) $v -match '^(oui|non|o|n|yes|no|y)$'}
    return ($value -match '^(oui|o|yes|y)$')
}
function Save-DataFile {
    param([System.Collections.IDictionary]$Data,[string]$Path,[switch]$PreviewOnly)
    $content=ConvertTo-DataLiteral $Data
    Write-Host "`nApercu : $Path`n$content`n"
    if ($PreviewOnly) { Write-Host 'Apercu uniquement : aucun fichier ecrit.'; return $false }
    if (-not (Read-YesNo 'Enregistrer ce fichier' $true)) { return $false }
    $parent=Split-Path ([IO.Path]::GetFullPath($Path)) -Parent
    $null=New-Item -ItemType Directory -Path $parent -Force
    $temporary=Join-Path $parent ([guid]::NewGuid().ToString()+'.psd1')
    try {
        # BOM keeps non-ASCII identities/paths readable in Windows PowerShell 5.1.
        [IO.File]::WriteAllText($temporary,$content+"`r`n",[Text.UTF8Encoding]::new($true))
        $null=Import-PowerShellDataFile -LiteralPath $temporary
        if (Test-Path -LiteralPath $Path) {
            $backup=$Path+'.'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff')+'.bak'
            Copy-Item -LiteralPath $Path -Destination $backup
            Write-Host "Sauvegarde : $backup"
        }
        Move-Item -LiteralPath $temporary -Destination $Path -Force
        Write-Host "Enregistre : $Path" -ForegroundColor Green
        return $true
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary } }
}
