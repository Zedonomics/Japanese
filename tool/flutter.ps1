# Do not declare advanced parameters: PowerShell would consume Flutter's --debug.
$taskFlutterArguments = $args
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
& flutter @taskFlutterArguments
exit $LASTEXITCODE
