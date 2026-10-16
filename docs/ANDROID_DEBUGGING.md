# Diagnose an Android crash

Connecting the phone with a USB **data** cable is the easiest way to collect the crash reason. The phone must be unlocked, Developer options and **USB debugging** enabled, and the computer authorized in the phone's prompt. Menu names vary by manufacturer. Keep the installed app and its progress; uninstalling is unnecessary for diagnosis.

From this repository on Windows, with the local Android tools described in [SETUP.md](SETUP.md):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/capture_android_crash.ps1
```

The tool lists connected devices. It uses the only authorized device, or requires an explicit selection if there are several:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/capture_android_crash.ps1 -Serial DEVICE_SERIAL -ObservationSeconds 30
```

It records the phone model, Android version, CPU architecture, and installed Kana Path version. It force-stops and opens **only Kana Path**, then observes for ten seconds by default (one to sixty seconds allowed). Reproduce the crash during that interval. Force-stopping interrupts the current screen but preserves the app's stored progress.

Results go into an ignored `build/device-logs/<timestamp>/` folder: `device.json`, `launch.txt`, and `kana-path-logcat.txt`. Log capture uses the phone's clock and selected runtime/crash tags, then retains lines associated with Kana Path and its native crash-reporting process. Native crashes can be reported under `DEBUG`, `debuggerd`, or `tombstoned`, so filtering only by the app PID would miss evidence. The tool does not clear logs, uninstall, clear app storage, or create a broad Android bug report.

Review the files before sharing: app errors and native stack traces can contain app data or file paths. A log with no matching entries is inconclusive; retry with a longer observation window and describe what appeared on screen. Report the phone make/model, Android version, whether the crash occurs immediately or after an action, and any visible message. The capture tool passed syntax and disconnected-device checks and captured the version 1.0.0 crash on a Pixel 9 Pro running Android 17. The release-startup tool passed on version 1.0.1 on that same phone; the user also confirmed the Learn screen appeared.

Once startup is fixed, use [DEVICE_CHECKS.md](DEVICE_CHECKS.md) to record real keyboard composition, handwriting-model download, offline lessons, restart recovery, and update behavior. Automated tests alone do not establish that these features work on a phone.

To gate an installed **release** build rather than merely collect logs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/android_release_smoke.ps1 -ExpectedVersionCode 3
```

Keep the phone unlocked. This reuses the crash collector and checks the non-debuggable version, stable running process, resumed activity, and fatal startup markers. It writes `release-startup-smoke.json` alongside the evidence and fails the command if any check fails. A resumed activity can remain behind the lock screen; visually confirm the Learn screen as well.

Android references: [enable USB debugging](https://developer.android.com/studio/debug/dev-options#Enable-debugging), [ADB device authorization](https://developer.android.com/tools/adb#Enabling), and [Logcat command-line options](https://developer.android.com/tools/logcat).
