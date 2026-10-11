$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\Common.ps1')
$passed=0
function Assert-Portable([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw "TEST FAILED: $Message" }; $script:passed++
}
function Assert-PortableRejected([scriptblock]$Action,[string]$Message) {
    $failed=$false; try { & $Action } catch {$failed=$true}
    Assert-Portable $failed $Message
}
function Add-Result { param($Name,$Status,$Detail) }
function Require-Admin {}
$script:root=Join-Path $env:ProgramFiles 'WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe'
$script:hasPackage=$true; $script:hasAccess=$false; $script:hasDeny=$false
$script:hasReparse=$false; $script:badTarget=$false; $script:repairWorks=$true
$script:grants=0; $script:Check=$true
function Test-Path { param($LiteralPath,$PathType); return $script:hasPackage }
function Get-Item {
    param($LiteralPath,[switch]$Force,$ErrorAction)
    if ($LiteralPath -like '*\Links\*') {
        $target=Join-Path $script:root (Split-Path $LiteralPath -Leaf)
        if ($script:badTarget) { $target=Join-Path $env:USERPROFILE 'uv.exe' }
        return [pscustomobject]@{LinkType='SymbolicLink';Target=$target;Attributes=[IO.FileAttributes]::ReparsePoint}
    }
    return [pscustomobject]@{FullName=$LiteralPath;Attributes=[IO.FileAttributes]::Directory}
}
function Get-ChildItem {
    param($LiteralPath,[switch]$Recurse,[switch]$Force,$ErrorAction)
    foreach ($name in @('uv.exe','uvx.exe')) {
        $attributes=if($script:hasReparse){[IO.FileAttributes]::ReparsePoint}else{[IO.FileAttributes]::Normal}
        [pscustomobject]@{FullName=(Join-Path $script:root $name);Attributes=$attributes}
    }
}
function Get-Acl {
    param($LiteralPath,$ErrorAction)
    $acl=New-Object PSObject
    $acl | Add-Member ScriptMethod GetAccessRules {
        param($Explicit,$Inherited,$Type)
        if ($script:hasDeny) {
            [pscustomobject]@{IdentityReference=@{Value='S-1-5-32-545'};AccessControlType='Deny';FileSystemRights=[Security.AccessControl.FileSystemRights]::ReadAndExecute;PropagationFlags=[Security.AccessControl.PropagationFlags]::None}
        }
        if ($script:hasAccess) {
            [pscustomobject]@{IdentityReference=@{Value='S-1-5-32-545'};AccessControlType='Allow';FileSystemRights=[Security.AccessControl.FileSystemRights]::ReadAndExecute;PropagationFlags=[Security.AccessControl.PropagationFlags]::None}
        }
    }
    return $acl
}
function Invoke-Native {
    param($Command,$Arguments,$Allowed,[switch]$Quiet)
    if ($Command -ne 'icacls.exe') {throw 'Unexpected native command'}
    Assert-Portable ($Arguments[0] -eq $script:root) 'ACL mutation restricted to verified uv package'
    Assert-Portable ($Arguments[2] -eq '*S-1-5-32-545:(OI)(CI)(RX)') 'Only read/execute granted to built-in Users'
    $script:grants++
    if ($script:repairWorks) {$script:hasAccess=$true}
    return @{Code=0;Output='fixture'}
}
Ensure-UvMachineAccess
Assert-Portable ($script:grants -eq 0) 'CheckOnly never modifies permissions'
$script:Check=$false
Ensure-UvMachineAccess
Assert-Portable ($script:grants -eq 1) 'Missing package permissions repaired'
Ensure-UvMachineAccess
Assert-Portable ($script:grants -eq 1) 'Already repaired package unchanged on resume'
$script:hasReparse=$true
Assert-PortableRejected {Ensure-UvMachineAccess} 'Reparse point in package rejected before recursive ACL operation'
$script:hasReparse=$false; $script:badTarget=$true
Assert-PortableRejected {Ensure-UvMachineAccess} 'Link to user-owned executable rejected'
$script:badTarget=$false; $script:hasDeny=$true
Assert-PortableRejected {Ensure-UvMachineAccess} 'Deny rules require manual review'
$script:hasDeny=$false; $script:hasPackage=$false
Assert-PortableRejected {Ensure-UvMachineAccess} 'Missing package or custom root rejected in apply mode'
$script:Check=$true
Ensure-UvMachineAccess
Assert-Portable ($script:grants -eq 1) 'Absent package in CheckOnly produces plan without ACL mutation'
$script:Check=$false; $script:hasPackage=$true; $script:hasAccess=$false; $script:repairWorks=$false
Assert-PortableRejected {Ensure-UvMachineAccess} 'Incomplete repair cannot be reported successful'
$script:repairWorks=$true
function Get-MachinePackagePlan { @{Id='astral-sh.uv';Extra=@()} }
function Ensure-WinGet { param($Id,$Extra,$Scope) }
function Ensure-OracleDeveloper {}
function Test-MachineTools {}
$tokens=$null; $errors=$null
$phaseAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Split-Path $PSScriptRoot -Parent) '20-winget-packages.ps1'),[ref]$tokens,[ref]$errors)
$phaseCall=$phaseAst.Find({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Invoke-Phase'},$true)
$body=$phaseCall.CommandElements | Where-Object {$_ -is [Management.Automation.Language.ScriptBlockExpressionAst]} | Select-Object -First 1
$script:Reboot=$false
& $body.ScriptBlock.GetScriptBlock()
Assert-Portable ($script:grants -eq 3) 'Phase 20 repairs ACLs even when WinGet reports package already installed'
Write-Host "$passed portable permission checks passed; no real ACL or software changes."
