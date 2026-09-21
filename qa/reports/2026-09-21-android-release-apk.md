# Android release APK — 2026-09-21

## Build and verification

- Bumped Flutter version from `1.0.25+37` to `1.0.26+38`.
- `flutter analyze --no-pub`: passed, no issues.
- `LD_LIBRARY_PATH=/opt/lampp/lib flutter test --no-pub`: **799 passed, 1 skipped, 0 failed**. The library path is needed by Drift tests on this host. Three migration contract tests were updated to use the reconciled filenames.
- Built serially with `scripts/build-android-supabase.sh apk --env-file env.supabase.json`. The script reported the configured production Supabase project and Firebase project. Build completed successfully.
- `unzip -tq`: passed. `apksigner verify`: APK Signature Scheme v2 valid. `zipalign -c -P 16 -v 4`: passed. Manifest package/version: `com.techmigos.schooldesk1`, `1.0.26`, code `38`.
- Obfuscation symbol maps were generated for Android ARM, ARM64, and x64 under `build/debug-info/android/apk/`.

## Artifact

- Path: `build/app/outputs/flutter-apk/app-release.apk`
- Size: `143,887,130` bytes
- SHA-256: `5ca01baff3a03f9ed4d6b32583d9c8365be55e155a112e8b0ad0300d1be68edb`
- Signing certificate SHA-256: `80141fa2855069e649008f4f8b7cfc1c31bf66bb4a0a97a7e094765b43c6cb08`

## Limits

This is a production-configured release artifact; it was not installed on the phone, so the existing local-backend QA app remains available for the user's role walkthrough. No authenticated production workflow was run. The build emitted forward-looking Android Gradle Plugin/Kotlin compatibility warnings and native ELF DWARF-symbol warnings; neither stopped packaging. The app build does not complete the outstanding FCM, reconnect, document lifecycle, browser, or iOS release checks.
