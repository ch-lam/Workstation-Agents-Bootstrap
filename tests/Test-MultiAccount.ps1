$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib\Common.ps1')
$scratch=Join-Path $PSScriptRoot ('scratch-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $scratch
$savedLocal=$env:LOCALAPPDATA
$env:LOCALAPPDATA=$scratch
$passed=0
function Assert-Case([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }; $script:passed++
}
function Assert-Rejected([scriptblock]$Action,[string]$Message) {
    $failed=$false; try { & $Action } catch { $failed=$true }; Assert-Case $failed $Message
}
try {
    $script:Log=Join-Path $scratch 'test.log'
    $path=Join-Path $scratch 'configuration.psd1'
    foreach ($entry in @(@('$true','LocalDesktop'),@('$false','None'))) {
        Set-Content -LiteralPath $path -Value ('@{EnableDocker='+$entry[0]+'}')
        Assert-Case ((Read-BootstrapConfig $path).DockerMode -eq $entry[1]) 'Legacy mode migration'
    }
    foreach ($mode in @('None','LocalDesktop','RemoteCLI','Both')) {
        Set-Content -LiteralPath $path -Value ("@{DockerMode='$mode'}")
        $script:Config=Read-BootstrapConfig $path
        Assert-Case ($script:Config.DockerMode -eq $mode) "Accept $mode"
        Assert-Case ((Test-LocalDockerEnabled) -eq ($mode -in @('LocalDesktop','Both'))) 'Local feature gate'
        Assert-Case ((Test-RemoteDockerEnabled) -eq ($mode -in @('RemoteCLI','Both'))) 'Remote feature gate'
    }
    foreach ($invalid in @("@{DockerMode='invalid'}",'@{DockerMode=''Both'';EnableDocker=$true}',"@{DockerMode='Both';DockerRemoteContexts=@(@{Name='default';Host='ssh://host'})}","@{DockerMode='Both';DockerRemoteContexts=@(@{Name='r';Host='tcp://host:2375'})}","@{DockerMode='Both';DockerRemoteContexts=@(@{Name='r';Host='ssh://user:password@host'})}")) {
        Set-Content -LiteralPath $path $invalid
        Assert-Rejected { $null=Read-BootstrapConfig $path } 'Unsafe configuration rejected before mutations'
    }
    Set-Content -LiteralPath $path "@{DockerMode='Both';OracleDeveloper=@{Enabled=`$true};DockerRemoteContexts=@(@{Name='remote-dev';Host='ssh://user@host:2222'})}"
    $config=Read-BootstrapConfig $path
    Assert-Case ($config.OracleDeveloper.ContainsKey('JavaHome')) 'Nested defaults merged'
    $null=New-Item -ItemType Directory -Path (Get-BootstrapUserDirectory)
    $confirmation=Join-Path (Get-BootstrapUserDirectory) 'backend-confirmation.psd1'
    Set-Content $confirmation "@{Confirmed=`$true;UserSID='another-account'}"
    Assert-Case (-not (Test-BackendConfirmation)) 'Other account cannot confirm this session'
    Set-Content $confirmation (ConvertTo-DataLiteral @{Confirmed=$true;UserSID=(Get-CurrentUserSid)})
    Assert-Case (Test-BackendConfirmation) 'Current SID confirmation accepted'
    $script:Rows.Clear()
    Add-Result 'fixture' INFO 'token=FAKE_SECRET Authorization: Bearer FAKE_BEARER https://user:FAKE_PASSWORD@example.invalid sk-FAKE_API_KEY'
    $log=Get-Content $script:Log -Raw
    Assert-Case ($log -notmatch 'FAKE_SECRET|FAKE_BEARER|FAKE_PASSWORD|FAKE_API_KEY') 'Known credential shapes redacted'
    function Add-Result { param($Name,$Status,$Detail); $script:Rows.Add(@{Name=$Name;Status=$Status;Detail=$Detail}) }
    # No WinGet or installation process is launched by these mocks.
    $script:calls=New-Object 'System.Collections.Generic.List[object]'
    function Get-Command { param($Name,$ErrorAction); return @{Source='fixture'} }
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        $script:calls.Add(@($Arguments))
        if ($Arguments[0] -eq 'list') { return [pscustomobject]@{Code=-1978335212;Output=''} }
        throw 'Mutation unexpectedly reached'
    }
    $script:Check=$true
    Ensure-WinGet 'Fixture.Package' -Scope machine
    Assert-Case (@($script:calls | Where-Object {$_[0] -eq 'install'}).Count -eq 0) 'CheckOnly never invokes install'
    Assert-Case (@($script:calls | Where-Object {$_ -contains '--scope' -and $_ -contains 'machine'}).Count -eq 1) 'Installed inventory uses required scope'
    $script:calls.Clear()
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        if ($Arguments -contains '--scope') { return [pscustomobject]@{Code=-1978335212;Output=''} }
        return [pscustomobject]@{Code=0;Output='user installation'}
    }
    Assert-Rejected { Ensure-WinGet 'Fixture.Package' -Scope machine } 'Wrong scope prevents duplicate install'
    $script:installed=$false;$script:calls.Clear();$script:Check=$false
    function Refresh-Path {}
    function Invoke-Native {
        param($Command,$Arguments,$Allowed,[switch]$Quiet)
        $script:calls.Add(@($Arguments))
        if ($Arguments[0] -eq 'list') {
            $code=if($script:installed){0}else{-1978335212}
            return @{Code=$code;Output=''}
        }
        if ($Arguments[0] -eq 'install') {$script:installed=$true}
        return @{Code=0;Output=''}
    }
    Ensure-WinGet 'Fixture.Package' -Scope machine
    Ensure-WinGet 'Fixture.Package' -Scope machine
    $installs=@($script:calls | Where-Object {$_[0] -eq 'install'})
    Assert-Case ($installs.Count -eq 1 -and $installs[0] -contains '--scope' -and $installs[0] -contains 'machine') 'Apply installs machine scope exactly once'
    Remove-Item Function:\Get-Command
    Write-Host "$passed multi-account/configuration/scope checks passed; no host installations."
} finally {
    $env:LOCALAPPDATA=$savedLocal
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($PSScriptRoot)+[IO.Path]::DirectorySeparatorChar)) { throw 'Invalid scratch cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
