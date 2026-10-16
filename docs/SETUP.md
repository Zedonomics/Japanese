# Local setup and personal installation

Run commands from the repository root. Initial SDK, dependency, Gradle, CocoaPods, and handwriting-model downloads need internet access. The application itself does not require a server.

## Toolchain

| Component | Project setting |
| --- | --- |
| Flutter | 3.47.7 stable |
| Dart | At least 3.12, bundled with Flutter |
| Android build JDK | Java 21; source/bytecode target is Java 17 |
| Android SDK | Compile and target API 36; minimum API 24 |
| Android NDK | 28.2.13676358, selected by this Flutter SDK |
| Android Gradle wrapper | 9.3.1 |
| iOS minimum | 15.5 |
| iOS native dependencies | CocoaPods, including Google ML Kit |

The [Flutter SDK archive](https://docs.flutter.dev/install/archive) provides the pinned Flutter release. Android Studio can install the Android SDK and command-line tools; the [Android command-line documentation](https://developer.android.com/tools/sdkmanager) explains `sdkmanager`.

## Windows with the local SDK cache

This workspace uses ignored `.tools` folders. They are machine-local downloads and are not bundled with a fresh Git checkout. To use the existing scripts on a new machine, unpack/install these tools at the following locations, or install them normally and put their executables on `PATH`:

```text
.tools/flutter/bin/flutter.bat
.tools/jdk-21.../bin/java.exe
.tools/android-sdk/cmdline-tools/latest/bin/sdkmanager.bat
.tools/android-sdk/platform-tools/adb.exe
```

`tool/env.ps1` selects a `.tools/jdk-*` folder, Flutter, and the Android SDK when present. It keeps Pub, Gradle, Android-user, and tool settings caches under `.tools`. `tool/flutter.ps1` loads that environment and forwards Flutter arguments. It does not install missing SDKs. Use this wrapper consistently so the same Android development keystore and dependency caches are used.

After installing the command-line tools, accept the Android SDK licenses and install the build components. If using the local layout:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. ./tool/env.ps1
& "$env:ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager.bat" --licenses
$taskPackages = @('platform-tools', 'platforms;android-36', 'build-tools;36.0.0', 'ndk;28.2.13676358')
$taskAndroidCli = Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin/android.exe'
if (Test-Path -LiteralPath $taskAndroidCli) {
    foreach ($taskPackage in $taskPackages) {
        & $taskAndroidCli --no-metrics sdk install $taskPackage
    }
} else {
    & "$env:ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager.bat" @taskPackages
}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 doctor -v
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 pub get
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 analyze
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 test
```

The execution-policy setting above affects only the current PowerShell session. The newer Android command-line tools include `android.exe`; calling it directly avoids a Windows wrapper issue that splits semicolon-separated package IDs. CI pins command-line tools build 13114758, whose legacy `sdkmanager` supports those IDs. The JDK must be a complete JDK. A first Android build can also download missing native build tools. Keep `pubspec.lock` with the app source so Pub uses the checked dependency versions. Do not copy `.tools` binaries or a Windows `android/local.properties` file to a Mac.

## Android phone

For a development run, enable Developer options and USB debugging on an Android phone, connect it, and accept the phone's authorization prompt:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 devices
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 run -d DEVICE_ID
```

For an APK you can install later:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/flutter.ps1 build apk --debug
```

The output is `build/app/outputs/flutter-apk/app-debug.apk`. Transfer it to the phone and open it, allowing installation from the chosen file/browser app when Android asks. Alternatively, with a connected and authorized phone:

```powershell
. ./tool/env.ps1
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`build apk --release` produces the smaller optimized `app-release.apk`. This repository currently signs both build types with the Android development key for personal use. That is not a store signing setup. Do not distribute its private keystore or commit signing credentials.

An Android update must retain the application ID (`dev.kanapath.kana_path`) and the same signing certificate. Keep a secure copy of the keystore used for the first installation; using a different machine, clearing tool caches, or installing a CI-built APK can produce a different development key. Locate the actual key using the Gradle `signingReport` task rather than assuming its location:

```powershell
. ./tool/env.ps1
Push-Location android
./gradlew.bat signingReport
Pop-Location
```

Export progress in **Settings → Export backup**, copy the JSON, and save it outside the app before updating. An incompatible signature normally requires uninstalling the previous app; uninstalling removes its local database. **Settings → Restore backup** validates a saved JSON backup and replaces local progress. Restoring is not a merge.

## macOS and the iOS simulator

iOS builds require a Mac with Xcode, its iOS simulator runtime, and CocoaPods. Follow [Flutter's iOS setup](https://docs.flutter.dev/platform-integration/ios/setup), finish Xcode's first-launch setup, and install Flutter 3.47.7. The committed `ios/Podfile` and Xcode deployment target are 15.5. This app uses CocoaPods for the ML Kit plugins:

```sh
flutter config --no-enable-swift-package-manager
flutter precache --ios
flutter pub get
cd ios
pod install
cd ..
flutter doctor -v
flutter build ios --simulator --debug --no-codesign
```

Start an iPhone simulator in Xcode, then find its identifier and run:

```sh
flutter devices
flutter run -d SIMULATOR_ID
flutter test integration_test/app_smoke_test.dart -d SIMULATOR_ID
```

Use a dedicated simulator or test installation: the integration test writes real local progress and may replace an unfinished test lesson. It does not download the Japanese recognition model or verify handwriting accuracy. If a model is already available it can exercise the lesson canvas; a separate canvas check also works without a model.

The smoke test and iOS build have not been executed on this Windows workspace. The CI workflow defines the corresponding simulator checks; a committed workflow is not evidence that they passed.

## Installing on your iPhone later

Signing and personal iPhone installation are deferred. On the Mac, open `ios/Runner.xcworkspace`, choose an Apple development team in Signing & Capabilities, and use a bundle identifier registered to that team. Connect the iPhone, enable any Developer Mode/trust settings required by Xcode, and select it as the destination. Run through Xcode or `flutter run -d DEVICE_ID` after signing is configured.

Apple account, provisioning, certificate, and renewal requirements depend on the chosen signing method. No Apple team, certificates, provisioning profiles, TestFlight upload, or App Store publication is configured here. An unsigned simulator app cannot be installed on a physical iPhone. Preserve progress with a JSON export before replacing an installation.

## Handwriting model and offline use

On Android or iPhone, open Settings and choose **Download model** while online. Keep the app open until it reports ready. A failed download can be retried; reading and keyboard lessons remain available. After the model is present, verify airplane-mode recognition using the device checklist. The app does not impose a particular Japanese keyboard layout: enable the phone's Japanese keyboard and commit kana or kanji conversion before checking an answer.

## CI

`.github/workflows/mobile.yml` defines two jobs: Ubuntu analyzes, runs local tests, builds the optimized release Android APK, and cold-starts that exact APK on an API 36 emulator; macOS 15 builds an unsigned iOS simulator app and runs the native integration smoke test on an available iPhone simulator. The Android gate checks release flags, a stable process, a resumed activity, loaded home-screen text, and fatal startup logs. CI uploads build artifacts and startup evidence for inspection. CI APKs use an ephemeral development key and should not be assumed compatible with an existing personal install. No store publication or device signing secrets are required.

Native package and SDK downloads can make a clean CI run slower than a cached local run. A remote CI run and the physical-device checks remain pending until actually performed and recorded.
