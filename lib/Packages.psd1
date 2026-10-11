@{
    Machine = @(
        @{ Id='Microsoft.PowerShell'; Extra=@('--installer-type','wix'); Commands=@('pwsh.exe') }
        @{ Id='Git.Git'; Extra=@(); Commands=@('git.exe') }
        @{ Id='Microsoft.VisualStudioCode'; Extra=@(); Commands=@('code.cmd') }
        @{ Id='OpenJS.NodeJS.LTS'; Extra=@(); Commands=@('node.exe','npm.cmd') }
        @{ Id='GitHub.cli'; Extra=@(); Commands=@('gh.exe') }
        @{ Id='GLab.GLab'; Extra=@(); Commands=@('glab.exe') }
        @{ Id='Microsoft.Sysinternals.Suite'; Extra=@(); Commands=@('procexp.exe') }
        @{ Id='astral-sh.uv'; Extra=@(); Commands=@('uv.exe','uvx.exe') }
    )
    # Python's ID is configurable and appended by Get-MachinePackagePlan.
    # Terminal MSIX and agent CLIs are handled in user phases; see README exceptions.
}
