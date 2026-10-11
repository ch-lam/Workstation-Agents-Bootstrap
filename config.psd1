@{
    MinimumFreeGB = 30
    MinimumSystemFreeGB = 10 # Windows, installer TEMP, profiles and existing binaries.
    AdditionalStoragePaths = @() # Actual Docker/WSL data roots or other installation volumes.
    WindowsUpdateTimeoutSeconds = 180
    MinimumRAMGB = 8
    RecommendedRAMGB = 16
    SchemaVersion = 2
    DockerMode = 'LocalDesktop' # None, LocalDesktop, RemoteCLI, Both; legacy EnableDocker is still accepted.
    DockerLocalContext = 'desktop-linux'
    DockerRemoteContexts = @() # @{ Name='remote-dev'; Host='ssh://user@host'; Required=$true }
    OracleDeveloper = @{
        Enabled = $false
        SqlclHome = '' # Official distribution installed during the administrator block; docs/ORACLE.md.
        JavaHome = ''
        VSCodeExtension = 'Oracle.oracledevtools'
    }
    OpenRouter = @{ Enabled = $false; BaseUrl = 'https://openrouter.ai/api/v1'; ApiKeyEnvironmentVariable = 'OPENROUTER_API_KEY' }
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
    BackendLoginConfirmed = $false # Legacy only; confirmation is now stored separately per Windows SID.
}
