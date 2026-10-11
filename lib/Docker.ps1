function Test-LocalDockerEnabled { return $script:Config.DockerMode -in @('LocalDesktop','Both') }
function Test-RemoteDockerEnabled { return $script:Config.DockerMode -in @('RemoteCLI','Both') }
function Get-DockerContextEndpoint {
    param([string]$Name)
    $result=Invoke-Native docker.exe @('context','inspect',$Name,'--format','{{.Endpoints.docker.Host}}') -Quiet
    return $result.Output.Trim()
}
function Ensure-DockerContexts {
    if (-not (Test-RemoteDockerEnabled)) { return }
    if (-not (Test-Tool docker.exe)) { return }
    if (-not (Test-Tool ssh.exe @('-V'))) { return }
    $names=((Invoke-Native docker.exe @('context','ls','--format','{{.Name}}') -Quiet).Output -split '\r?\n')
    foreach ($remote in $script:Config.DockerRemoteContexts) {
        if ($names -contains $remote.Name) {
            if ((Get-DockerContextEndpoint $remote.Name) -cne $remote.Host) { throw "Docker context $($remote.Name) has a different endpoint; preserved. Resolve explicitly." }
            Add-Result "Docker context $($remote.Name)" PASS 'Existing SSH endpoint matches'
        } else {
            Invoke-Change "Create Docker context $($remote.Name)" {
                $null=Invoke-Native docker.exe @('context','create',$remote.Name,'--docker',('host='+$remote.Host))
            }
        }
    }
    Add-Result 'Docker selection' INFO 'Active context preserved. Use docker context ls, docker context use NAME, or docker --context NAME ps.'
    Add-Result 'SSH setup' MANUAL 'Configure host keys and protected credentials in this account outside bootstrap. No key is generated. Remote bind mounts refer to the Docker host filesystem.'
}
function Invoke-DockerEngineProbe {
    param([string]$Context)
    # Bound SSH/network stalls, without showing prompts or persisting subprocess output.
    $docker=(Get-Command docker.exe -CommandType Application -ErrorAction Stop).Source
    $job=Start-Job -ArgumentList $docker,$Context -ScriptBlock {
        param($Executable,$Name)
        $text=@(& $Executable --context $Name info --format '{{.OSType}}' 2>$null)
        [pscustomobject]@{Code=$LASTEXITCODE;Output=($text -join "`n")}
    }
    try {
        if (-not (Wait-Job $job -Timeout 30)) { throw 'Docker engine probe timed out; check engine readiness or SSH configuration manually.' }
        $result=@(Receive-Job $job -ErrorAction Stop)
        if ($result.Count -ne 1 -or $result[0].Code -ne 0) { throw 'Docker engine unavailable; diagnose manually outside bootstrap logs.' }
        return $result[0].Output.Trim()
    } finally {
        if ($job.State -in @('Running','NotStarted')) { Stop-Job $job }
        Remove-Job $job -Force
    }
}
function Test-DockerEngines {
    if ($script:Config.DockerMode -eq 'None') { return }
    if (-not (Test-Tool docker.exe)) { return }
    if ($env:DOCKER_HOST -or $env:DOCKER_CONTEXT) { Add-Result 'Docker environment' WARN 'Docker override variable present; probes explicitly name each context. Values are not logged.' }
    $names=((Invoke-Native docker.exe @('context','ls','--format','{{.Name}}') -Quiet).Output -split '\r?\n')
    if (Test-LocalDockerEnabled) {
        $null=Test-Tool docker.exe @('compose','version')
        try {
            $name=$script:Config.DockerLocalContext
            if ($names -notcontains $name) { throw 'Local Docker context absent; complete Desktop first launch in this account.' }
            $endpoint=Get-DockerContextEndpoint $name
            if ($endpoint -notmatch '^npipe:/{2,}\./pipe/[a-zA-Z0-9_.-]+$') { throw 'Local context must target a Windows named pipe; remote endpoint cannot validate Desktop.' }
            if ((Invoke-DockerEngineProbe $name) -ne 'linux') { throw 'Local Docker engine must run Linux containers' }
            Add-Result 'Docker local engine' PASS 'Explicit local context returned a running Linux engine'
        } catch { Add-Result 'Docker local engine' FAIL $_.Exception.Message }
    }
    if (Test-RemoteDockerEnabled) {
        $null=Test-Tool ssh.exe @('-V')
        foreach ($remote in $script:Config.DockerRemoteContexts) {
            $required=-not $remote.ContainsKey('Required') -or $remote.Required
            try {
                if ($names -notcontains $remote.Name) { throw 'Declared remote context absent; run phase 60' }
                if ((Get-DockerContextEndpoint $remote.Name) -cne $remote.Host) { throw 'Declared SSH endpoint does not match the existing context' }
                $type=Invoke-DockerEngineProbe $remote.Name
                if ($type -notin @('linux','windows')) { throw 'Unexpected remote engine response' }
                Add-Result "Docker remote $($remote.Name)" PASS 'Explicit SSH context reached its engine'
            } catch {
                $status=if ($required) {'FAIL'} else {'WARN'}
                Add-Result "Docker remote $($remote.Name)" $status $_.Exception.Message
            }
        }
        if ($script:Config.DockerRemoteContexts.Count -eq 0) { Add-Result 'Docker remote engines' MANUAL 'No remote parameters supplied; CLI only validated, no remote engine certified.' }
    }
}
