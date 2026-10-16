# Implementation verification — 2026-10-16

## Android artifact

- File: `build/app/outputs/flutter-apk/app-release.apk`
- Application: **Kana Path**, `dev.kanapath.kana_path`, version `1.0.2` (build 3)
- Size: 74,653,091 bytes (71.2 MiB)
- SHA-256: `479CF278D6510134F4E5FA5FF8CA85780B2E118B61964045BC470A8E017751CC`
- Minimum Android API: 24. Compile and target API: 36.
- Architectures: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- `apksigner verify`: passed, APK Signature Scheme v2, Android development certificate. This is a personal sideload build.

Transfer the APK to your Android phone and open it to install. Follow [setup and installation](SETUP.md), including preserving the signing key for future updates. The APK is a generated local artifact; it is not committed to Git.

## Completed checks

- Flutter 3.47.7 / Dart 3.13.5: `flutter analyze` — **no issues**.
- `flutter test` — **59 tests passed**. The 16 optional screenshot scenarios are skipped in the normal suite.
- Domain tests cover normalization, correct-script grading, contextual readings, drawing uncertainty, separate skill scheduling, delayed retries, permanent kanji unlocking, and lesson selection.
- SQLite/controller tests cover transaction rollback, reopening a database, duplicate-answer protection, exact feedback recovery, malformed-backup rejection, backup restore, model failures, and keyboard lessons while a model download is pending.
- Curriculum tests cover all 311 items, exact top-100 frequency ranks, dictionary evidence, ambiguity cues, source notices, and 251 constituent-character stroke SVGs.
- Widget tests cover Japanese IME composition, timestamped drawing input, undo/clear, neutral redraw, and numbered stroke-guide labels.
- Ten canvas regressions cover fine vertical/horizontal/diagonal strokes within a scrolling page, all initial samples, dot taps, scrolling outside the cell, disabled drawing, extra fingers, and canceled strokes. The original vertical test scrolled from 120 to 190 pixels; the corrected test preserves the 120-pixel page position and every ink point.
- A never-completing native handwriting readiness probe times out after five seconds. The regression verifies that reading lessons, saved answers, and model retry remain available.
- Optional preview run: **16 rendering scenarios passed**, producing 32 PNGs under `build/screenshots/` (normal and enlarged text, light/dark themes, four screens, including scrolled views). These are widget renderings with real fonts and deterministic sample progress, not captures from a physical phone.
- `flutter build apk --release` — **passed** after all application changes. Manifest and signature inspected using Android build tools.

Recheck the artifact using:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/verify_android.ps1
```

## Physical-device findings and remaining checks

A Google Pixel 9 Pro running Android 17 (API 37) reproduced the version 1.0.0 startup crash. Android's startup provider failed to construct WorkManager's Room database because R8 had removed its reflective constructor. The release keep rules now explicitly preserve constructors for Room implementations, WorkManager input mergers, and ML Kit component registrars. Other release optimization remains enabled. This follows the [AGP 9 strict keep-rule behavior](https://developer.android.com/build/releases/agp-9-0-0-release-notes).

Version 1.0.1 was installed over 1.0.0 with the same signing certificate using `adb install -r`; the original installation timestamp was retained. The non-debuggable release passed a 15-second physical-device cold-start check: its process stayed running, its activity was resumed, and scoped startup logs contained no fatal exceptions. The user then unlocked the Pixel, opened Kana Path, and confirmed that the Learn screen appeared. Evidence is saved locally under ignored `build/device-logs/20261016-151751-590/`; it contains device details and is not published. Lesson and real input checks remain separate from startup verification.

The user confirmed lesson input, feedback, and continuation in version 1.0.1, plus successful model download and basic native recognition. Vertical-first drawing exposed a gesture conflict with lesson scrolling. Version 1.0.2 claims gestures only inside the writing cells, captures their raw samples from touch-down, and leaves scrolling outside the cells available. Its same-signature update passed a ten-second native startup check on the same Pixel, with five data-free startup stages confirming curriculum, storage, model readiness, and lessons completed. Physical drawing confirmation is pending.

Physical Japanese keyboard composition details, interrupted model-download recovery, offline native recognition, and saved-answer restart recovery still require verification. See [Android debugging](ANDROID_DEBUGGING.md) for the repeatable crash-capture and release-startup commands.

The first [mobile CI run](https://github.com/Zedonomics/Japanese/actions/runs/38962697642) built the optimized Android APK and the unsigned iOS simulator app. Android's release startup gate found a fresh-emulator loading stall; the guarded model query and startup stage logs are included in 1.0.2, with the rerun pending. iOS's native lesson test reached answer entry but exposed missing test-frame synchronization before tapping its newly enabled button; that test now waits for the enabled button and actual feedback. The original run failed these checks; it is not recorded as a passing mobile run. Physical iPhone signing and installation remain deferred.

The exact remaining scenarios are recorded in the [device checklist](DEVICE_CHECKS.md). No store publication, paid service, or account setup was performed.
