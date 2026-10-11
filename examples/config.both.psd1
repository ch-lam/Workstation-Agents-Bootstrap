@{
    SchemaVersion = 2
    DockerMode = 'Both'
    DockerLocalContext = 'desktop-linux'
    # Leave empty until actual SSH parameters are provided.
    DockerRemoteContexts = @()
    # Example only: @{Name='remote-dev';Host='ssh://developer@docker-host';Required=$true}
    OracleDeveloper = @{
        Enabled = $false # Enable after completing docs/ORACLE.md in the administrator account.
        SqlclHome = ''
        JavaHome = ''
        VSCodeExtension = 'Oracle.oracledevtools'
    }
    OpenRouter = @{
        Enabled = $true
        BaseUrl = 'https://openrouter.ai/api/v1'
        ApiKeyEnvironmentVariable = 'OPENROUTER_API_KEY'
    }
    NoSleepOnAC = $true
    ResyncTime = $false
    GitUserName = ''
    GitUserEmail = ''
}
