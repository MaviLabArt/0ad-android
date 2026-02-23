# Android Port (Experimental)

This repository includes an experimental Android app project at:

`build/android/sdl-project`

It packages the engine as an SDL-based APK using modern Gradle + NDK tooling.

## What this provides

- Android app packaging (`.apk`) with Gradle.
- Native wrapper (`libmain.so`) that loads `pyrogenesis_main`.
- Runtime root path wiring through `PYROGENESIS_ROOT`.
- Helper scripts to copy `.so` libraries and game data.

## Prerequisites

- Android SDK + NDK installed.
- Java 17 (required by modern Android Gradle Plugin).
- `gradle` command available (or import project in Android Studio).
- SDL source tree checkout (set `SDL2_SOURCE_DIR`).
- Android-built native libraries (at least `libpyrogenesis.so` or `libpyrogenesis_dbg.so`, plus its dependent `.so` files).

## Quick start

1. Build the engine for Android (experimental):

   ```sh
   export ANDROID_NDK_ROOT=/absolute/path/to/android-ndk
   ./build/android/build-engine.sh
   ```

2. Copy native libraries into the APK project:

   ```sh
   cd build/android/sdl-project
   ./copy-native-libs.sh /path/to/android/binaries/system
   ```

3. Build debug APK:

   ```sh
   ./build-apk.sh /absolute/path/to/SDL
   ```

   Output:

   `build/android/sdl-project/app/build/outputs/apk/debug/app-debug.apk`

4. Install APK:

   ```sh
   adb install -r app/build/outputs/apk/debug/app-debug.apk
   ```

5. Push game data:

   ```sh
   ./sync-data.sh /path/to/0ad/data
   ```

## Runtime data location

The launcher configures `PYROGENESIS_ROOT` to:

`/data/user/0/com.wildfiregames.zeroad/files/0ad`

`sync-data.sh` writes to this internal path via `run-as` when available. If `run-as` is unavailable, it falls back to:

`/sdcard/Android/data/com.wildfiregames.zeroad/files/0ad`

Expected layout:

- `.../0ad/data` (read-only game data)
- `.../0ad/appdata/data`
- `.../0ad/appdata/config`
- `.../0ad/appdata/cache`
- `.../0ad/appdata/logs`

## Notes

- This is a bootstrap port, not a production-ready mobile release.
- Current Gradle ABI filter defaults to `arm64-v8a`.
- `build-apk.sh` applies an SDL2 Android.mk compatibility patch for recent NDKs (removes `cpufeatures` import-module usage).
- Full engine cross-build still depends on Android-ready third-party libs (notably SpiderMonkey/fmt and related dependencies).
- Old scripts in `build/android/setup-libs.sh` target obsolete Android toolchains and are retained only for historical reference.
