function Test-UsersReadExecute {
    param([string]$Path)
    $required=[Security.AccessControl.FileSystemRights]::ReadAndExecute
    $allowed=[Security.AccessControl.FileSystemRights]0
    $acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
    foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        # Never override an explicit denial through an automatic repair.
        if ($rule.AccessControlType -eq 'Deny' -and ($rule.FileSystemRights -band $required)) {
            throw 'Portable package has a deny rule affecting read/execute; review its ACL manually.'
        }
        if ($rule.IdentityReference.Value -eq 'S-1-5-32-545' -and $rule.AccessControlType -eq 'Allow' -and
            -not ($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly)) {
            $allowed=$allowed -bor $rule.FileSystemRights
        }
    }
    return (($allowed -band $required) -eq $required)
}
function Ensure-UvMachineAccess {
    Require-Admin
    $programFilesRoot=[IO.Path]::GetFullPath([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles)).TrimEnd('\')
    $wingetRoot=Join-Path $programFilesRoot 'WinGet'
    $packagesRoot=Join-Path $wingetRoot 'Packages'
    $packageRoot=Join-Path $packagesRoot 'astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe'
    if (-not (Test-Path -LiteralPath $packageRoot -PathType Container)) {
        if ($script:Check) { Add-Result 'uv machine permissions' PLAN 'After installation, verify package paths and grant Users read/execute on this package only'; return }
        throw 'Expected machine uv package directory missing; custom portable roots require manual review.'
    }
    # The recursive ACL operation must not cross any junction or symbolic link.
    foreach ($path in @($programFilesRoot,$wingetRoot,$packagesRoot,$packageRoot)) {
        $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'uv package ancestor is a reparse point; no automatic ACL change.' }
    }
    $children=@(Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -ErrorAction Stop)
    foreach ($item in $children) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'uv package contains a reparse point; no automatic ACL change.' }
        $full=[IO.Path]::GetFullPath($item.FullName)
        if (-not $full.StartsWith(($packageRoot+'\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'uv package item outside the verified directory.' }
    }
    foreach ($command in @('uv.exe','uvx.exe')) {
        $linkPath=Join-Path (Join-Path $wingetRoot 'Links') $command
        $link=Get-Item -LiteralPath $linkPath -Force -ErrorAction Stop
        if ($link.LinkType -ne 'SymbolicLink' -or @($link.Target).Count -ne 1) { throw 'uv command must be a WinGet symbolic link to the verified package.' }
        $target=[string]@($link.Target)[0]
        if (-not [IO.Path]::IsPathRooted($target)) { $target=Join-Path (Split-Path $linkPath -Parent) $target }
        $target=[IO.Path]::GetFullPath($target)
        if (-not $target.StartsWith(($packageRoot+'\'),[StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($target) -ne $command -or -not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw 'uv command target is missing or outside the verified machine package; no automatic ACL change.'
        }
    }
    $paths=@($packageRoot)+@($children | ForEach-Object {$_.FullName})
    $missing=@($paths | Where-Object {-not (Test-UsersReadExecute $_)})
    if ($missing.Count -eq 0) { Add-Result 'uv machine permissions' PASS 'Users have read/execute on the package; no permission change needed'; return }
    Invoke-Change 'uv machine permissions: Users read/execute' {
        # Built-in Users SID works on every Windows language. Add RX, never M/F.
        $null=Invoke-Native 'icacls.exe' @($packageRoot,'/grant','*S-1-5-32-545:(OI)(CI)(RX)','/T') -Quiet
        foreach ($path in $paths) {
            if (-not (Test-UsersReadExecute $path)) { throw 'uv package read/execute permissions remain incomplete after repair.' }
        }
    }
}
