# Dot-source this script before local Flutter commands. All caches stay in .tools.
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskTools = Join-Path $taskProjectRoot '.tools'
foreach ($taskCache in @('pub-cache', 'gradle', 'android-user', 'appdata', 'localappdata')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $taskTools $taskCache) | Out-Null
}
$env:PUB_CACHE = Join-Path $taskTools 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $taskTools 'gradle'
$env:ANDROID_USER_HOME = Join-Path $taskTools 'android-user'
$env:APPDATA = Join-Path $taskTools 'appdata'
$env:LOCALAPPDATA = Join-Path $taskTools 'localappdata'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$taskJava = Get-ChildItem -LiteralPath $taskTools -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($taskJava) { $env:JAVA_HOME = $taskJava.FullName; $env:PATH = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:PATH }
if (Test-Path -LiteralPath (Join-Path $taskTools 'android-sdk')) {
    $env:ANDROID_HOME = Join-Path $taskTools 'android-sdk'
    $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
    $env:PATH = (Join-Path $env:ANDROID_HOME 'platform-tools') + ';' + $env:PATH
}
if (Test-Path -LiteralPath (Join-Path $taskTools 'flutter\bin')) {
    $env:PATH = (Join-Path $taskTools 'flutter\bin') + ';' + $env:PATH
}
