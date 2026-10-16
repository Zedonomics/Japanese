param(
    [string]$Serial,
    [ValidateRange(1, 60)][int]$ObservationSeconds = 10
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'env.ps1')
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskAdb = Join-Path $taskRoot '.tools/android-sdk/platform-tools/adb.exe'
if (-not (Test-Path -LiteralPath $taskAdb)) {
    throw 'Local adb is missing. See docs/SETUP.md for Android platform-tools setup.'
}

function Invoke-TaskAdb {
    param([string[]]$AdbArguments, [switch]$AllowFailure)
    # adb can print daemon-start messages on stderr even when it succeeds.
    $ErrorActionPreference = 'Continue'
    $taskLines = @(& $taskAdb @AdbArguments 2>&1 | ForEach-Object { "$_" })
    $taskExit = $LASTEXITCODE
    if ($taskExit -ne 0 -and -not $AllowFailure) {
        throw "adb failed ($taskExit): $($taskLines -join [Environment]::NewLine)"
    }
    [pscustomobject]@{ ExitCode = $taskExit; Text = ($taskLines -join "`n") }
}

$taskInventory = Invoke-TaskAdb -AdbArguments @('devices', '-l')
Write-Host $taskInventory.Text
$taskDevices = @($taskInventory.Text -split "`r?`n" | ForEach-Object {
    if ($_ -match '^(\S+)\s+(device|unauthorized|offline)\b') {
        [pscustomobject]@{ Serial = $Matches[1]; State = $Matches[2] }
    }
})
$taskReady = @($taskDevices | Where-Object { $_.State -eq 'device' })
if ($Serial) {
    if (-not @($taskReady | Where-Object { $_.Serial -ceq $Serial }).Count) {
        throw 'The requested device is not connected and authorized. Unlock it, enable USB debugging, and accept its computer authorization prompt.'
    }
} elseif ($taskReady.Count -eq 1) {
    $Serial = $taskReady[0].Serial
} elseif ($taskReady.Count -gt 1) {
    throw 'Multiple authorized devices are connected. Run again with -Serial DEVICE_SERIAL from the list above.'
} else {
    throw 'No authorized Android device. Connect and unlock the phone, enable USB debugging, and accept its computer authorization prompt. No app data was changed.'
}

$taskDeviceArguments = @('-s', $Serial)
$taskPackage = 'dev.kanapath.kana_path'
$taskPackagePattern = [regex]::Escape($taskPackage)
$taskInstalled = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'pm', 'path', $taskPackage))
if ($taskInstalled.Text -notmatch '(?m)^package:') {
    throw 'Kana Path is not installed on the selected device. This tool does not install or uninstall apps.'
}
$taskFolder = Join-Path $taskRoot ('build/device-logs/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $taskFolder -Force | Out-Null
$taskProperties = [ordered]@{}
foreach ($taskProperty in @('ro.product.manufacturer', 'ro.product.model', 'ro.build.version.release', 'ro.build.version.sdk', 'ro.product.cpu.abilist')) {
    $taskProperties[$taskProperty] = (Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'getprop', $taskProperty))).Text.Trim()
}
$taskPackageDump = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'dumpsys', 'package', $taskPackage))
$taskVersion = @($taskPackageDump.Text -split "`r?`n" | Where-Object { $_ -match '^\s*(versionCode=|versionName=|firstInstallTime=|lastUpdateTime=)' } | ForEach-Object { $_.Trim() })
[ordered]@{
    capturedAt = (Get-Date).ToUniversalTime().ToString('o')
    package = $taskPackage
    device = $taskProperties
    installedVersion = $taskVersion
    observationSeconds = $ObservationSeconds
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskFolder 'device.json') -Encoding UTF8

# Use the phone's clock, so old log entries and host/phone clock differences do not contaminate this attempt.
$taskPhoneTime = (Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'date', '+%m-%dT%H:%M:%S'))).Text.Trim()
if ($taskPhoneTime -notmatch '^\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$') { throw 'Could not read the device clock for a bounded log capture.' }
$taskSince = $taskPhoneTime.Replace('T', ' ') + '.000'
$null = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'am', 'force-stop', $taskPackage))
$taskLaunch = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'am', 'start', '-n', "$taskPackage/.MainActivity")) -AllowFailure
$taskLaunch.Text | Set-Content -LiteralPath (Join-Path $taskFolder 'launch.txt') -Encoding UTF8
Write-Host "Kana Path launched. Reproduce the problem now; observing for $ObservationSeconds seconds."
$taskAppPids = New-Object 'System.Collections.Generic.HashSet[string]'
for ($taskSecond = 0; $taskSecond -lt $ObservationSeconds; $taskSecond++) {
    $taskPidResult = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @('shell', 'pidof', $taskPackage)) -AllowFailure
    foreach ($taskPid in ($taskPidResult.Text -split '\s+')) {
        if ($taskPid -match '^\d+$') { $null = $taskAppPids.Add($taskPid) }
    }
    Start-Sleep -Seconds 1
}

# Read only crash/runtime and process-start tags from this launch window. Keep this intermediate text in memory.
# Native tombstones are emitted by a different process, so --pid alone would lose important crashes.
$taskLogResult = Invoke-TaskAdb -AdbArguments ($taskDeviceArguments + @(
    'logcat', '-b', 'main', '-b', 'system', '-b', 'crash', '-d', '-v', 'threadtime', '-T', $taskSince,
    'AndroidRuntime:V', 'flutter:V', 'Flutter:V', 'DEBUG:V', 'libc:V', 'tombstoned:V', 'debuggerd:V',
    'crash_dump64:V', 'crash_dump32:V', 'ActivityManager:I', 'ActivityTaskManager:I', '*:S'
))
$taskRecords = @($taskLogResult.Text -split "`r?`n" | ForEach-Object {
    if ($_ -match '^\s*\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+\s+(\d+)\s+(\d+)\s+([VDIWEF])\s+(.+?)\s*:\s?(.*)$') {
        [pscustomobject]@{ Line = $_; Pid = $Matches[1]; Tid = $Matches[2]; Tag = $Matches[4].Trim(); Message = $Matches[5] }
    }
})
$taskNativeEmitters = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($taskRecord in $taskRecords) {
    if ($taskRecord.Message -match "Start proc (\d+):$taskPackagePattern(?:/|\s)") { $null = $taskAppPids.Add($Matches[1]) }
    if ($taskRecord.Tag -eq 'AndroidRuntime' -and $taskRecord.Message -match "Process: $taskPackagePattern, PID:\s*(\d+)") { $null = $taskAppPids.Add($Matches[1]) }
    if ($taskRecord.Tag -in @('DEBUG', 'crash_dump32', 'crash_dump64') -and
        $taskRecord.Message -match "(?:>>>\s*$taskPackagePattern\s*<<<|Cmdline:\s*$taskPackagePattern(?:\s|$))") {
        $null = $taskNativeEmitters.Add("$($taskRecord.Pid):$($taskRecord.Tid)")
    }
}
foreach ($taskRecord in $taskRecords) {
    if ($taskNativeEmitters.Contains("$($taskRecord.Pid):$($taskRecord.Tid)") -and $taskRecord.Message -match '\bpid:\s*(\d+),') {
        $null = $taskAppPids.Add($Matches[1])
    }
}
$taskSavedLines = @($taskRecords | Where-Object {
    $taskKeep = $taskAppPids.Contains($_.Pid) -or
        (($_.Tag -in @('DEBUG', 'crash_dump32', 'crash_dump64')) -and $taskNativeEmitters.Contains("$($_.Pid):$($_.Tid)")) -or
        ($_.Message -match "(?<![\w.])$taskPackagePattern(?![\w.])")
    if (-not $taskKeep -and $_.Tag -in @('debuggerd', 'tombstoned', 'crash_dump32', 'crash_dump64')) {
        foreach ($taskPid in $taskAppPids) {
            if ($_.Message -match "\b(?:pid|process)\s*[=:]?\s*$taskPid\b") { $taskKeep = $true; break }
        }
    }
    $taskKeep
} | ForEach-Object { $_.Line })
if ($taskSavedLines.Count) {
    $taskSavedLines | Set-Content -LiteralPath (Join-Path $taskFolder 'kana-path-logcat.txt') -Encoding UTF8
} else {
    'No matching Kana Path runtime/crash lines were found. This does not prove the app is healthy; capture again with a longer observation window.' |
        Set-Content -LiteralPath (Join-Path $taskFolder 'kana-path-logcat.txt') -Encoding UTF8
}
Write-Host "Saved $($taskSavedLines.Count) targeted log lines and device/version details to: $taskFolder"
Write-Host 'Review these files before sharing; crash messages can contain app data. App storage and existing device logs were preserved.'
if ($taskLaunch.ExitCode -ne 0 -or $taskLaunch.Text -match '(?m)^Error:') { throw "Launch failed; inspect launch.txt in $taskFolder" }
