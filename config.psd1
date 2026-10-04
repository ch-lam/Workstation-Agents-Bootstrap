@{
    MinimumFreeGB = 30
    MinimumSystemFreeGB = 10 # Windows, installer TEMP, profiles and existing binaries.
    AdditionalStoragePaths = @() # Actual Docker/WSL data roots or other installation volumes.
    WindowsUpdateTimeoutSeconds = 180
    MinimumRAMGB = 8
    RecommendedRAMGB = 16
    EnableDocker = $true
    NoSleepOnAC = $true
    # Observe Windows/domain time policy; never replace the configured peers.
    ResyncTime = $false
    NtpProbeHost = 'time.windows.com'
    MaximumTimeOffsetSeconds = 5
    PythonPackage = 'Python.Python.3.14'
    GitUserName = '' # Fill in your actual identity; empty preserves existing config.
    GitUserEmail = ''
    GitDefaultBranch = 'main'
    Extensions = @(
        'eamodio.gitlens'
        'ms-azuretools.vscode-containers'
        'ms-vscode.PowerShell'
        'ms-python.python'
        'dbaeumer.vscode-eslint'
        'esbenp.prettier-vscode'
        'redhat.vscode-yaml'
    )
    # Optional exact npm versions; empty installs latest ONLY when absent.
    CodexVersion = ''
    GrokVersion = ''
    BackendLoginConfirmed = $false # Set true only after a real Claude/Codex session.
}
