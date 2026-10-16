# Kana Path

A personal Flutter app for learning hiragana, katakana, and the first 100 kanji in KANJIDIC frequency order. Choose a script or mixed practice, then answer ten short questions by reading, Japanese keyboard input, or handwriting.

- Both kana scripts include 46 basic forms, 25 voiced forms, and 33 contracted combinations, plus contextual small-tsu and long-vowel lessons.
- Kana reading accepts common romaji aliases. Kanji reading uses hiragana; kanji production requires the Japanese character. Meanings and example words distinguish the taught reading.
- Reading, typing, and drawing have separate progress. Three scheduled successes on separate days establish mastery. Kana reading and typing unlock kanji permanently; handwriting has its own progress.
- Lessons introduce at most three new items and prioritize due reviews and errors. Choose all skills or focus on reading, typing, or drawing.
- Progress, answer history, and the current lesson are stored in SQLite. Settings exports and restores portable JSON backups.

The app targets Android 7.0/API 24 and newer and iOS 15.5 and newer. Drawing uses Google ML Kit on the device after a one-time Japanese model download. An uncertain recognition result can be redrawn without a progress penalty. Drawing checks recognizable shapes; it does not grade stroke order or calligraphy.

## Run and build

The project uses **Flutter 3.47.7**, Dart 3.12 or newer, and Java 21 for the Android build. See [setup instructions](docs/SETUP.md) for SDK installation, Android sideloading, and the deferred iPhone signing steps.

From PowerShell at the repository root, when the local `.tools` SDKs are present:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 pub get
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 analyze
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. A personal optimized build uses `build apk --release` and produces `app-release.apk`; the current Android release configuration also uses the development signing key. Preserve that key for future in-place updates, and export a backup before replacing or uninstalling the app.

## Verification and remaining device work

The implementation produced a verified personal Android release APK at `build/app/outputs/flutter-apk/app-release.apk`. Static analysis is clean and all 48 automated tests pass. See the [build report](docs/BUILD_REPORT.md) for the artifact hash and the distinction between completed checks and pending device work.

Unit, widget, repository, and controller tests live in `test/`. The [mobile workflow](.github/workflows/mobile.yml) defines Android checks/builds and an unsigned iOS simulator build with a native startup smoke test. The workflow has not been run remotely as part of this implementation. It does not configure App Store or Play Store publication.

The integration smoke test starts the real app with native SQLite, exercises a keyboard answer, and checks drawing input without downloading a recognition model. Run it on a dedicated simulator or test device:

```sh
flutter test integration_test/app_smoke_test.dart -d DEVICE_ID
```

Physical keyboard behavior, model downloads, actual handwriting recognition, and iPhone installation remain subject to the [pending device checklist](docs/DEVICE_CHECKS.md).

## Content and privacy

KANJIDIC2 and JMdict supply kanji metadata and checked vocabulary examples; KanjiVG supplies stroke guides. Read the [curriculum documentation](docs/CURRICULUM.md), [source notices](docs/SOURCES.md), and bundled notices in `assets/licenses/`. Settings also exposes the source notices and licenses.

There are no app accounts or cloud progress synchronization. The recognition model needs a network connection to download; lessons and recognition then run locally. Google ML Kit has its own diagnostics and privacy terms. Backups contain learning history and must be saved somewhere outside the app to survive uninstalling it.

Foreign katakana extensions such as ティ, ファ, and ヴ, additional kanji readings, larger vocabulary lessons, audio, and store distribution are outside this first version.
