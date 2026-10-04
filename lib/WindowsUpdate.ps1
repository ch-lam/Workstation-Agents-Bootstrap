function Get-WindowsUpdateInventory {
    $timeout=180
    if ($script:Config.ContainsKey('WindowsUpdateTimeoutSeconds')) { $timeout=[int]$script:Config.WindowsUpdateTimeoutSeconds }
    if ($timeout -lt 15) { throw 'WindowsUpdateTimeoutSeconds must be >=15' }
    Add-Result 'Windows Update search' INFO "Searching the configured Windows Update/WSUS source; timeout $timeout seconds. No update download or installation requested."
    $job=Start-Job -ScriptBlock {
        $ErrorActionPreference='Stop'
        $session=New-Object -ComObject Microsoft.Update.Session
        $session.ClientApplicationID='AgentWorkstationBootstrap'
        $searcher=$session.CreateUpdateSearcher()
        $searcher.Online=$true
        $searcher.CanAutomaticallyUpgradeService=$false
        # Respect the existing ServerSelection/policy. Include software and drivers.
        $result=$searcher.Search('IsInstalled=0 and IsHidden=0')
        $updates=@(for ($i=0; $i -lt $result.Updates.Count; $i++) {
            $update=$result.Updates.Item($i)
            [pscustomobject]@{Title=$update.Title;Optional=[bool]$update.BrowseOnly;Downloaded=[bool]$update.IsDownloaded}
        })
        $system=New-Object -ComObject Microsoft.Update.SystemInfo
        [pscustomobject]@{ResultCode=[int]$result.ResultCode;Updates=$updates;RebootRequired=[bool]$system.RebootRequired}
    }
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $nextNotice=15
    try {
        while ($job.State -in @('NotStarted','Running')) {
            $null=Wait-Job -Job $job -Timeout 1
            if ($watch.Elapsed.TotalSeconds -ge $timeout) { throw "Windows Update search timed out after $timeout seconds; status is unknown, not up to date." }
            if ($watch.Elapsed.TotalSeconds -ge $nextNotice -and $job.State -eq 'Running') {
                Add-Result 'Windows Update search' INFO ("Still searching ({0} seconds)..." -f [int]$watch.Elapsed.TotalSeconds)
                $nextNotice+=15
            }
        }
        if ($job.State -ne 'Completed') {
            $failure=$job.ChildJobs[0].JobStateInfo.Reason
            throw "Windows Update search failed: $failure"
        }
        $inventory=@(Receive-Job -Job $job -ErrorAction Stop)
        if ($inventory.Count -ne 1) { throw 'Windows Update search returned an invalid result' }
        return $inventory[0]
    } finally {
        if ($job.State -in @('NotStarted','Running')) { Stop-Job -Job $job }
        Remove-Job -Job $job -Force
    }
}
function Test-WindowsUpdates {
    $mandatory=Get-Variable -Name WindowsUpdateMandatory -Scope Script -ErrorAction SilentlyContinue
    $isMandatory=($mandatory -and [bool]$mandatory.Value)
    $problemStatus=if ($isMandatory) {'FAIL'} else {'INFO'}
    $cleanStatus=if ($isMandatory) {'PASS'} else {'INFO'}
    Add-Result 'Windows Update policy' INFO ($(if ($isMandatory) {'Mandatory: pending updates, restart and unknown results block this phase.'} else {'Informational: Windows Update results do not block this phase.'}))
    try {
        $inventory=Get-WindowsUpdateInventory
        # Only orcSucceeded (2) certifies a complete search; partial/error != clean.
        if ($inventory.ResultCode -ne 2) { throw "Incomplete Windows Update search (result $($inventory.ResultCode)); pending update status is unknown." }
        $updates=@($inventory.Updates)
        $required=@($updates | Where-Object { -not $_.Optional })
        $optional=@($updates | Where-Object Optional)
        if ($required.Count -gt 0) {
            Add-Result 'Windows Update' $problemStatus "$($required.Count) non-optional update(s) pending according to the configured update source."
            foreach ($update in $required) { Add-Result 'Pending update' INFO $update.Title }
        } else { Add-Result 'Windows Update' $cleanStatus 'Search succeeded: no non-optional, non-hidden updates pending.' }
        if ($optional.Count -gt 0) {
            Add-Result 'Optional updates' INFO "$($optional.Count) optional update(s) available; not blocking this bootstrap."
            foreach ($update in $optional) { Add-Result 'Optional update' INFO $update.Title }
        }
        if ($inventory.RebootRequired) { Add-Result 'Windows Update restart' $problemStatus 'Windows Update Agent reports a restart required to complete an installation.' }
        if ($required.Count -gt 0 -or $inventory.RebootRequired) {
            Add-Result 'Windows Update action' INFO "Open Windows Update, install the listed updates/restart as needed, then rerun this phase:`nStart-Process 'ms-settings:windowsupdate'"
        }
    } catch {
        Add-Result 'Windows Update' $problemStatus $_.Exception.Message
        Add-Result 'Windows Update diagnosis' INFO "Status could not be verified. Check connectivity, update services and any organization policy; rerun elevated if access is denied. Open Settings with:`nStart-Process 'ms-settings:windowsupdate'"
    }
}
