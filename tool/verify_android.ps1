param([string]$ApkPath = 'build/app/outputs/flutter-apk/app-release.apk')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$taskApk = (Resolve-Path -LiteralPath $ApkPath).Path
$taskBuildTools = Join-Path $env:ANDROID_HOME 'build-tools/36.0.0'
& (Join-Path $taskBuildTools 'apksigner.bat') verify --verbose --print-certs $taskApk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
& (Join-Path $taskBuildTools 'aapt2.exe') dump badging $taskApk |
    Select-String -Pattern '^package:', '^sdkVersion:', '^minSdkVersion:', '^targetSdkVersion:', '^application-label:'
if ($LASTEXITCODE -ne 0) { throw 'APK manifest inspection failed.' }
Get-FileHash -LiteralPath $taskApk -Algorithm SHA256 | Format-List Algorithm, Hash, Path
