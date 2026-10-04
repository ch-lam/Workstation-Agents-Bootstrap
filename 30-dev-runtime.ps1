[CmdletBinding()]
param([switch]$CheckOnly,[switch]$WindowsUpdateMandatory,[string]$ConfigPath)
if (-not $ConfigPath) {
    $ConfigPath=Join-Path $PSScriptRoot 'config.local.psd1'
    if (-not (Test-Path -LiteralPath $ConfigPath)) { $ConfigPath=Join-Path $PSScriptRoot 'config.psd1' }
}
. (Join-Path $PSScriptRoot 'lib\Common.ps1')
Invoke-Phase '30-dev-runtime' {
    Require-User
    $null = Test-NodeMinimum
    $null = Test-Tool npm.cmd
    Ensure-WinGet $script:Config.PythonPackage @('--scope','user')
    Ensure-WinGet 'astral-sh.uv'
    if (-not $script:Check) {
        $null = Test-Tool python.exe
        $null = Test-Tool uv.exe
        $null = Test-Tool uvx.exe
    }
    Add-Result 'Native build tools' MANUAL 'Only for source builds lacking prebuilt modules: install Visual Studio C++ Build Tools (Desktop development with C++) and compatible Python; optional for the common workstation base.'
} $ConfigPath -CheckOnly:$CheckOnly -WindowsUpdateMandatory:$WindowsUpdateMandatory
