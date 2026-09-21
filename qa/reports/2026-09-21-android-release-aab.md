# Android release AAB — 2026-09-21

## Build and verification

- Built serially with `scripts/build-android-supabase.sh aab --env-file env.supabase.json`; Gradle completed `bundleRelease` successfully in 688.2 seconds.
- Uses the same Flutter release version as the APK: `1.0.26+38`. The bundle manifest contains package `com.techmigos.schooldesk1` and version name `1.0.26`; the merged release manifest reports version code `38`.
- The selected define file points the app at the configured production Supabase API and Firebase project. This only configures the artifact; this build did not deploy migrations, Edge Functions, or other changes to Supabase.
- `unzip -tq`: passed. `jarsigner -verify -verbose -certs`: JAR signature verified; signer is the configured self-signed SchoolDesk release certificate. The certificate chain is not trusted by the host JVM, which is expected for this locally managed signing certificate. The signature has no timestamp.
- The AAB contains `BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map` (60,753,127 bytes). Native debug-symbol archive integrity passed; Flutter split-debug-info output is retained under `build/debug-info/android/aab/`.

## Artifact

- Path: `build/app/outputs/bundle/release/app-release.aab`
- Size: `130,067,849` bytes
- SHA-256: `5b815c718c850c9e3c7e0eecca3e4897bddc7498defc193cbc7006dccd5356a6`
- Signing certificate SHA-256: `80141fa2855069e649008f4f8b7cfc1c31bf66bb4a0a97a7e094765b43c6cb08`
- Obfuscation map path: `build/app/outputs/bundle/release/app-release.aab` (embedded metadata entry listed above)
- Native debug symbols: `build/app/outputs/native-debug-symbols/release/native-debug-symbols.zip`

## Limits

The AAB has not been uploaded to Google Play or installed on a device. It is configured for the production backend, but production functional checks and the outstanding device/browser/iOS QA remain separate gates. Build warnings noted upcoming Flutter support drops for AGP 8.13.0 and Kotlin 2.2.20, plus native ELF DWARF debug information; they did not fail the build.
