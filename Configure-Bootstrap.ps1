[CmdletBinding()]
param(
    [switch]$WindowsUpdateMandatory,
    [ValidateSet('Menu','Configuration','ConfirmLogin')][string]$Action='Menu',
    [string]$ConfigPath,
    [switch]$PreviewOnly
)
$ErrorActionPreference='Stop'
if (-not $ConfigPath) { $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1' }
$script:WindowsUpdateMandatory=[bool]$WindowsUpdateMandatory
. (Join-Path $PSScriptRoot 'lib\Configuration.ps1')
$source=if (Test-Path -LiteralPath $ConfigPath) {$ConfigPath} else {Join-Path $PSScriptRoot 'config.psd1'}
$config=Read-BootstrapConfig $source
Write-Host "`nAssistant de configuration - workstation d'agents"
Write-Host 'Entree conserve la valeur proposee. Aucun logiciel ne sera installe.'
if ($Action -eq 'Menu') {
    Write-Host "1. Preparer le socle`n2. Confirmer un login backend deja teste"
    $choice=Read-Answer 'Votre choix' '1' {param($v) $v -in @('1','2')}
    $Action=@{'1'='Configuration';'2'='ConfirmLogin'}[$choice]
}
switch ($Action) {
    'Configuration' {
        $config.DockerMode=Read-Answer 'Docker : None, LocalDesktop, RemoteCLI, Both' $config.DockerMode {param($v) $v -in @('None','LocalDesktop','RemoteCLI','Both')}
        $config.NoSleepOnAC=Read-YesNo 'Empecher veille/hibernation automatique sur secteur' $config.NoSleepOnAC
        $config.GitUserName=Read-Answer 'Nom Git (vide : conserver la configuration existante)' $config.GitUserName
        $config.GitUserEmail=Read-Answer 'Email Git (vide : conserver la configuration existante)' $config.GitUserEmail
        $config.NtpProbeHost=Read-Answer 'Serveur NTP autorise pour le diagnostic' $config.NtpProbeHost {param($v) $v -match '^[a-zA-Z0-9][a-zA-Z0-9.:-]*$'}
        if (Read-YesNo 'Afficher les options avancees' $false) {
            $config.GitDefaultBranch=Read-Answer 'Branche Git par defaut' $config.GitDefaultBranch {param($v) -not [string]::IsNullOrWhiteSpace($v)}
            $config.PythonPackage=Read-Answer 'ID WinGet Python' $config.PythonPackage {param($v) $v -match '^Python\.Python\.3\.\d+$'}
            $config.CodexVersion=Read-Answer 'Version npm Codex (vide : latest a la premiere installation)' $config.CodexVersion {param($v) -not $v -or $v -match '^\d+\.\d+\.\d+([+-][a-zA-Z0-9.-]+)?$'}
            $config.GrokVersion=Read-Answer 'Version npm Grok (vide : latest a la premiere installation)' $config.GrokVersion {param($v) -not $v -or $v -match '^\d+\.\d+\.\d+([+-][a-zA-Z0-9.-]+)?$'}
            $config.ResyncTime=Read-YesNo 'Demander une resynchronisation avec les pairs Windows existants' $config.ResyncTime
            $extensions=Read-Answer 'Extensions VS Code separees par des virgules' ($config.Extensions -join ',') {param($v) $v -match '^[a-zA-Z0-9.-]+(\s*,\s*[a-zA-Z0-9.-]+)*$'}
            $config.Extensions=@($extensions -split '\s*,\s*')
            $extra=Read-Answer 'Autres chemins de stockage (Docker/WSL, installations), separes par des virgules; vide : aucun' ($config.AdditionalStoragePaths -join ',') {param($v) -not $v -or @($v -split '\s*,\s*' | Where-Object { -not (Test-AbsoluteWindowsPath $_) }).Count -eq 0}
            $config.AdditionalStoragePaths=if ($extra) {@($extra -split '\s*,\s*')} else {@()}
        }
        $null=Save-DataFile $config $ConfigPath -PreviewOnly:$PreviewOnly
        Write-Host "`nProchaine etape, apres enregistrement : copiez-collez cette commande pour le preflight."
        Write-Host (Get-BootstrapLaunchCommand (Join-Path $PSScriptRoot 'Invoke-Bootstrap.ps1') $ConfigPath -Phase '00' -CheckOnly)
        Write-Host 'Voir README pour les sessions admin/utilisateur des phases suivantes.'
    }
    'ConfirmLogin' {
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        if (([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Confirm login in the target non-elevated user session.' }
        $confirmed=Read-YesNo 'Avez-vous reussi une vraie conversation Claude ou Codex, sous ce compte Windows qui executera le harness' $false
        $state=@{Confirmed=$confirmed;UserSID=(Get-CurrentUserSid);Timestamp=(Get-Date).ToString('o')}
        $null=Save-DataFile $state (Join-Path (Get-BootstrapUserDirectory) 'backend-confirmation.psd1') -PreviewOnly:$PreviewOnly
        Write-Host 'Apres enregistrement, copiez-collez cette commande dans un terminal normal pour valider le socle :'
        Write-Host (Get-BootstrapLaunchCommand (Join-Path $PSScriptRoot 'Invoke-Bootstrap.ps1') $ConfigPath -Phase '70')
    }
}
