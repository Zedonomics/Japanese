# Implementation verification — 2026-10-16

## Android artifact

- File: `build/app/outputs/flutter-apk/app-release.apk`
- Application: **Kana Path**, `dev.kanapath.kana_path`, version `1.0.0` (build 1)
- Size: 74,620,319 bytes (71.2 MiB)
- SHA-256: `07D07047E3B7B1A97D35542C697D64A3F4E0562703ED81E6A184AD25BB629EC8`
- Minimum Android API: 24. Compile and target API: 36.
- Architectures: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- `apksigner verify`: passed, APK Signature Scheme v2, Android development certificate. This is a personal sideload build.

Transfer the APK to your Android phone and open it to install. Follow [setup and installation](SETUP.md), including preserving the signing key for future updates. The APK is a generated local artifact; it is not committed to Git.

## Completed checks

- Flutter 3.47.7 / Dart 3.13.5: `flutter analyze` — **no issues**.
- `flutter test` — **48 tests passed**. The 16 optional screenshot scenarios are skipped in the normal suite.
- Domain tests cover normalization, correct-script grading, contextual readings, drawing uncertainty, separate skill scheduling, delayed retries, permanent kanji unlocking, and lesson selection.
- SQLite/controller tests cover transaction rollback, reopening a database, duplicate-answer protection, exact feedback recovery, malformed-backup rejection, backup restore, model failures, and keyboard lessons while a model download is pending.
- Curriculum tests cover all 311 items, exact top-100 frequency ranks, dictionary evidence, ambiguity cues, source notices, and 251 constituent-character stroke SVGs.
- Widget tests cover Japanese IME composition, timestamped drawing input, undo/clear, neutral redraw, and numbered stroke-guide labels.
- Optional preview run: **16 rendering scenarios passed**, producing 32 PNGs under `build/screenshots/` (normal and enlarged text, light/dark themes, four screens, including scrolled views). These are widget renderings with real fonts and deterministic sample progress, not captures from a physical phone.
- `flutter build apk --release` — **passed** after all application changes. Manifest and signature inspected using Android build tools.

Recheck the artifact using:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/verify_android.ps1
```

## Pending checks

No Android phone was connected to ADB. Physical Japanese keyboard conversion, model download/recovery, offline native recognition accuracy, and install/update behavior have **not** been verified on hardware.

The iOS project, CocoaPods integration, native integration smoke test, and macOS CI workflow are provided. iOS compilation and simulator execution have **not** run in this Windows workspace or remotely. iPhone signing and installation remain deferred.

The exact remaining scenarios are recorded in the [device checklist](DEVICE_CHECKS.md). No store publication, paid service, remote CI run, or account setup was performed.
