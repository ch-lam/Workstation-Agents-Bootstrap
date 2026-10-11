function Read-BootstrapConfig {
    param([string]$Path)
    $defaults=Import-PowerShellDataFile -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'config.psd1')
    $inputData=Import-PowerShellDataFile -LiteralPath $Path
    if ($inputData.ContainsKey('SchemaVersion') -and $inputData.SchemaVersion -notin @(1,2)) { throw 'Unsupported SchemaVersion' }
    if ($inputData.ContainsKey('EnableDocker') -and $inputData.EnableDocker -isnot [bool]) { throw 'EnableDocker must be a Boolean' }
    if (-not $inputData.ContainsKey('DockerMode') -and $inputData.ContainsKey('EnableDocker')) {
        $defaults.DockerMode=if ($inputData.EnableDocker) {'LocalDesktop'} else {'None'}
    }
    foreach ($key in $inputData.Keys) {
        if (-not $defaults.ContainsKey($key)) { continue }
        if ($defaults[$key] -is [hashtable]) {
            if ($inputData[$key] -isnot [hashtable]) { throw "Invalid configuration section: $key" }
            foreach ($child in $inputData[$key].Keys) {
                if (-not $defaults[$key].ContainsKey($child)) { throw "Unknown configuration field: $key.$child" }
                $defaults[$key][$child]=$inputData[$key][$child]
            }
        } else { $defaults[$key]=$inputData[$key] }
    }
    if ($defaults.DockerMode -notin @('None','LocalDesktop','RemoteCLI','Both')) { throw 'Invalid DockerMode' }
    if ($inputData.ContainsKey('DockerMode') -and $inputData.ContainsKey('EnableDocker')) {
        $legacyMode=if ($inputData.EnableDocker) {'LocalDesktop'} else {'None'}
        if ($defaults.DockerMode -ne $legacyMode) { throw 'DockerMode conflicts with EnableDocker; remove the legacy key explicitly.' }
    }
    if ($defaults.DockerLocalContext -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]*$') { throw 'Invalid DockerLocalContext' }
    $names=@{}
    if ($defaults.DockerRemoteContexts -isnot [array]) { throw 'DockerRemoteContexts must be an array' }
    foreach ($remote in $defaults.DockerRemoteContexts) {
        if ($remote -isnot [hashtable] -or -not $remote.ContainsKey('Name') -or -not $remote.ContainsKey('Host')) { throw 'Each remote context requires Name and Host' }
        if ($remote.Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_.-]*$' -or $remote.Name -in @('default','desktop-linux',$defaults.DockerLocalContext)) { throw 'Invalid or reserved remote context name' }
        if ($names.ContainsKey($remote.Name)) { throw 'Duplicate remote context name' }
        $names[$remote.Name]=$true
        if ($remote.Host -notmatch '^ssh://(?:[a-zA-Z0-9_][a-zA-Z0-9_.-]*@)?[a-zA-Z0-9][a-zA-Z0-9.-]*(?::[0-9]{1,5})?$') { throw 'Remote Host must be ssh://[user@]host[:port], without credentials or options' }
        $uri=[uri]$remote.Host
        if ($uri.Port -gt 65535 -or $uri.Port -eq 0) { throw 'Invalid SSH port' }
        foreach ($field in $remote.Keys) { if ($field -notin @('Name','Host','Required')) { throw 'Unknown remote context field' } }
        if ($remote.ContainsKey('Required') -and $remote.Required -isnot [bool]) { throw 'Required must be a Boolean' }
    }
    if ($defaults.DockerRemoteContexts.Count -gt 0 -and $defaults.DockerMode -notin @('RemoteCLI','Both')) { throw 'Remote contexts require RemoteCLI or Both' }
    foreach ($section in @('OracleDeveloper','OpenRouter')) {
        if ($defaults[$section].Enabled -isnot [bool]) { throw "$section.Enabled must be a Boolean" }
    }
    if ($defaults.OpenRouter.BaseUrl -ne 'https://openrouter.ai/api/v1' -or $defaults.OpenRouter.ApiKeyEnvironmentVariable -notmatch '^[A-Z_][A-Z0-9_]*$') { throw 'Invalid OpenRouter endpoint or environment variable name' }
    if ($defaults.OracleDeveloper.VSCodeExtension -notmatch '^[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$') { throw 'Invalid Oracle extension ID' }
    $defaults.SchemaVersion=2
    return $defaults
}
function Get-CurrentUserSid { return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
function Get-BootstrapUserDirectory { return Join-Path $env:LOCALAPPDATA 'Workstation-Agents-Bootstrap' }
function Test-BackendConfirmation {
    $path=Join-Path (Get-BootstrapUserDirectory) 'backend-confirmation.psd1'
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $state=Import-PowerShellDataFile -LiteralPath $path
        return ($state.Confirmed -eq $true -and $state.UserSID -eq (Get-CurrentUserSid))
    } catch { return $false }
}
