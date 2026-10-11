function Get-StorageTargets {
    param([hashtable]$Config)
    $systemMinimum=if ($Config.ContainsKey('MinimumSystemFreeGB')) {$Config.MinimumSystemFreeGB} else {10}
    $items=New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in @($env:SystemRoot,$env:TEMP,$env:LOCALAPPDATA,$env:APPDATA,$env:ProgramFiles,$env:USERPROFILE)) {
        if ($path) { $items.Add([pscustomobject]@{Role='Windows / installers / user data';Path=$path;MinimumGB=$systemMinimum}) }
    }
    $items.Add([pscustomobject]@{Role='Bootstrap logs';Path=$env:LOCALAPPDATA;MinimumGB=$systemMinimum})
    foreach ($command in @('pwsh.exe','git.exe','code.cmd','node.exe','npm.cmd','python.exe','uv.exe','gh.exe','docker.exe','codex.cmd','claude.exe','grok.cmd')) {
        $tool=Get-Command $command -ErrorAction SilentlyContinue
        if ($tool -and $tool.Source -and [IO.Path]::IsPathRooted($tool.Source)) {
            $items.Add([pscustomobject]@{Role="Resolved executable $command";Path=$tool.Source;MinimumGB=$systemMinimum})
        }
    }
    if ($Config.ContainsKey('AdditionalStoragePaths')) {
        foreach ($path in $Config.AdditionalStoragePaths) {
            if ($path) { $items.Add([pscustomobject]@{Role='Additional data / Docker / WSL';Path=$path;MinimumGB=$Config.MinimumFreeGB}) }
        }
    }
    return $items.ToArray()
}
function Test-StorageVolumes {
    param([object[]]$Targets=(Get-StorageTargets $script:Config))
    # Names include drive roots and directory mount points. Longest prefix wins.
    $volumes=@(Get-CimInstance Win32_Volume | Where-Object { $_.Name } | Sort-Object @{Expression={$_.Name.Length};Descending=$true})
    $groups=@{}
    foreach ($target in $Targets) {
        if ($target.Path -notmatch '^[a-zA-Z]:[\\/]') {
            Add-Result "Storage $($target.Role)" FAIL "Unsupported/non-local path: $($target.Path). This profile requires local absolute Windows paths."
            continue
        }
        $path=[IO.Path]::GetFullPath($target.Path)
        $volume=@($volumes | Where-Object { ($path.TrimEnd('\')+'\').StartsWith($_.Name.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
        if ($volume.Count -eq 0) { Add-Result "Storage $($target.Role)" FAIL "Volume missing or inaccessible: $path"; continue }
        $v=$volume[0]
        $id=$v.DeviceID
        if (-not $groups.ContainsKey($id)) {
            $groups[$id]=[pscustomobject]@{Volume=$v;MinimumGB=[double]$target.MinimumGB;Uses=(New-Object 'System.Collections.Generic.List[string]')}
        }
        $groups[$id].MinimumGB=[Math]::Max($groups[$id].MinimumGB,[double]$target.MinimumGB)
        $groups[$id].Uses.Add("$($target.Role)=$path")
    }
    foreach ($entry in @($groups.Values | Sort-Object {$_.Volume.Name})) {
        $v=$entry.Volume
        if ($null -eq $v.FreeSpace -or $null -eq $v.Capacity -or $v.Capacity -eq 0) {
            Add-Result "Disk $($v.Name)" FAIL 'Volume unavailable or free space cannot be read'; continue
        }
        # Compare bytes, not a rounded GB value at the threshold.
        $free=[Math]::Round($v.FreeSpace/1GB,1)
        $status=if ($v.FreeSpace -ge $entry.MinimumGB*1GB) {'PASS'} else {'FAIL'}
        Add-Result "Disk $($v.Name)" $status "$free GB free; required $($entry.MinimumGB) GB; $($entry.Uses -join '; ')" -ConsoleDetail "$free GB free; required $($entry.MinimumGB) GB"
    }
}
