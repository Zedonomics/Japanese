param(
    [string]$Serial,
    [ValidateRange(3, 60)][int]$ObservationSeconds = 15,
    [ValidateRange(0, 2147483647)][int]$ExpectedVersionCode = 0
)

# Run against an already installed release APK on an unlocked device. This
# cold-starts the app without clearing its data or the device's existing logs.
# It detects native startup failures; it does not replace lesson/input testing.
$ErrorActionPreference = 'Stop'

# Reuse the bounded, package-scoped crash collector. Dot-sourcing intentionally
# shares its selected device, installed package, collected records, and folder.
. (Join-Path $PSScriptRoot 'capture_android_crash.ps1') -Serial $Serial -ObservationSeconds $ObservationSeconds

$taskSmokeFailures = New-Object 'System.Collections.Generic.List[string]'
$taskDebuggable = $taskPackageDump.Text -match '(?m)^\s*(?:pkgFlags|flags)=\[[^\]\r\n]*\bDEBUGGABLE\b'
if ($taskDebuggable) {
    $taskSmokeFailures.Add('The installed package is debuggable. Install the release APK before running this release gate.')
}
$taskInstalledCode = $null
if ($taskPackageDump.Text -match '(?m)^\s*versionCode=(\d+)\b') {
    $taskInstalledCode = [int]$Matches[1]
} else {
    $taskSmokeFailures.Add('Could not establish the installed version code.')
}
if ($ExpectedVersionCode -gt 0 -and $taskInstalledCode -ne $ExpectedVersionCode) {
    $taskSmokeFailures.Add("Installed version code $taskInstalledCode does not match expected $ExpectedVersionCode.")
}

$taskFinalPidResult = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'pidof', $taskPackage)) -AllowFailure
$taskFinalPids = @($taskFinalPidResult.Text -split '\s+' | Where-Object { $_ -match '^\d+$' })
if (-not $taskFinalPids.Count) {
    $taskSmokeFailures.Add('Kana Path has no running process after the startup observation window.')
}
if ($taskAppPids.Count -gt 1) {
    $taskSmokeFailures.Add('The app process changed during startup; inspect the captured log for a crash/restart.')
}

# Retain only the resumed/top activity lines, not the full activity dump.
$taskActivityDump = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'dumpsys', 'activity', 'activities'))
$taskResumedLines = @($taskActivityDump.Text -split "`r?`n" | Where-Object {
    $_ -match '\b(?:mResumedActivity|topResumedActivity|ResumedActivity)\s*[:=]'
})
$taskForeground = @($taskResumedLines | Where-Object {
    $_ -match "(?<![\w.])$taskPackagePattern/"
}).Count -gt 0
if (-not $taskForeground) {
    $taskSmokeFailures.Add('Kana Path is not a resumed foreground activity. Unlock the phone, dismiss system prompts, and retry if appropriate.')
}

$taskCrashMarkers = @($taskSavedLines | Where-Object {
    $_ -match '\b(?:FATAL EXCEPTION|Fatal signal\s+\d+|Abort message:|Unhandled Exception:)'
})
if ($taskCrashMarkers.Count) {
    $taskSmokeFailures.Add('The launch produced a fatal native/runtime or unhandled Dart exception; inspect kana-path-logcat.txt.')
}

$taskSmokeSummary = [ordered]@{
    checkedAt = (Get-Date).ToUniversalTime().ToString('o')
    package = $taskPackage
    installedVersionCode = $taskInstalledCode
    installedVersion = $taskVersion
    debuggable = $taskDebuggable
    observationSeconds = $ObservationSeconds
    processRunning = $taskFinalPids.Count -gt 0
    foregroundActivity = $taskForeground
    fatalMarkerCount = $taskCrashMarkers.Count
    appDataPreserved = $true
    result = $(if ($taskSmokeFailures.Count) { 'FAIL' } else { 'PASS' })
    failures = @($taskSmokeFailures)
    scope = 'Release native cold-start only; lesson, keyboard, handwriting, and offline checks remain separate.'
}
$taskSmokeSummary | ConvertTo-Json -Depth 5 |
    Set-Content -LiteralPath (Join-Path $taskFolder 'release-startup-smoke.json') -Encoding UTF8
if ($taskSmokeFailures.Count) {
    throw "Release startup smoke failed: $($taskSmokeFailures -join ' ') Evidence: $taskFolder"
}
Write-Host "PASS: Installed release version $taskInstalledCode remained running and foreground for the startup observation. Evidence: $taskFolder"
