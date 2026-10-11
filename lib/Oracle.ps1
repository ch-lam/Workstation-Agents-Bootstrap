function Get-OraclePaths {
    $oracle=$script:Config.OracleDeveloper
    foreach ($key in @('SqlclHome','JavaHome')) {
        if ([string]::IsNullOrWhiteSpace($oracle[$key]) -or $oracle[$key] -notmatch '^[A-Za-z]:\\') { throw 'Oracle requires absolute SqlclHome and JavaHome. Follow docs/ORACLE.md during the administrator block.' }
        $full=[IO.Path]::GetFullPath($oracle[$key])
        if (-not $full.StartsWith(($env:ProgramFiles.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Oracle binaries must be installed under Program Files, with standard users read/execute only.' }
    }
    $sql=Join-Path $oracle.SqlclHome 'bin\sql.exe'
    if (-not (Test-Path -LiteralPath $sql -PathType Leaf)) { $sql=Join-Path $oracle.SqlclHome 'bin\sql.bat' }
    $java=Join-Path $oracle.JavaHome 'bin\java.exe'
    if (-not (Test-Path -LiteralPath $sql -PathType Leaf) -or -not (Test-Path -LiteralPath $java -PathType Leaf)) { throw 'Official SQLcl/JDK missing. Complete docs/ORACLE.md before leaving the administrator account.' }
    return @{Sql=$sql;Java=$java;Bin=(Join-Path $oracle.SqlclHome 'bin')}
}
function Test-OracleDeveloper {
    param([switch]$EffectiveEnvironment)
    if (-not $script:Config.OracleDeveloper.Enabled) { return }
    $paths=Get-OraclePaths
    if ($EffectiveEnvironment) {
        if (-not $env:JAVA_HOME -or $env:JAVA_HOME.TrimEnd('\') -ine $script:Config.OracleDeveloper.JavaHome.TrimEnd('\')) { throw 'Effective JAVA_HOME does not match the configured JDK; reopen the session or correct a personal override.' }
        $launcher=Get-Command ([IO.Path]::GetFileName($paths.Sql)) -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $launcher -or $launcher.Source -ine $paths.Sql) { throw 'SQLcl is absent from PATH or shadowed by another installation.' }
    }
    $null=Invoke-Native $paths.Java @('-version') -Quiet
    $previousJava=$env:JAVA_HOME
    try {
        $env:JAVA_HOME=$script:Config.OracleDeveloper.JavaHome
        $null=Invoke-Native $paths.Sql @('-version') -Quiet
    } finally { $env:JAVA_HOME=$previousJava }
    Add-Result 'Oracle SQLcl / Java' PASS 'Configured SQLcl launches with the configured Java; no database connection or credentials used'
}
function Ensure-OracleDeveloper {
    if (-not $script:Config.OracleDeveloper.Enabled) { return }
    # Oracle distribution and Java licence/version are an explicit manual prerequisite.
    Test-OracleDeveloper
    $paths=Get-OraclePaths
    $existing=[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')
    if ($existing -and $existing.TrimEnd('\') -ine $script:Config.OracleDeveloper.JavaHome.TrimEnd('\')) { throw 'Existing machine JAVA_HOME differs; review Java compatibility explicitly before continuing.' }
    Ensure-PathEntry $paths.Bin Machine
    if (-not $existing) {
        Invoke-Change 'Set machine JAVA_HOME for SQLcl' { [Environment]::SetEnvironmentVariable('JAVA_HOME',$script:Config.OracleDeveloper.JavaHome,'Machine') }
    }
}
