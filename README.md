# SchoolDesk Flutter

SchoolDesk is a Flutter school management app for Principal, Admin, Teacher, and Parent roles.

The current runtime target is Supabase:

- API base URL: `https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api`
- Supabase project URL: `https://ouvwogguttybmpgfgctc.supabase.co`
- Backend implementation: Supabase Edge Functions under `supabase/functions/api`
- Schema changes: Supabase migrations under `supabase/migrations`

The retired backend and mobile-flow automation folders have been removed from this checkout. Do not add alternate backend deployment files or external device-flow suites back into this project unless the runtime target changes intentionally.

## Setup

```bash
flutter pub get
python3 tool/generate_dart_defines.py
```

Run the app:

```bash
flutter run
```

Plain `flutter run` attaches to the Supabase Edge backend after generating the
local iOS define file. For Xcode Debug, Release, or Archive builds, run
`python3 tool/generate_dart_defines.py` after changing `env.supabase.json` and
before building. Both Runner configurations load that generated file, so an
installed iPhone build receives the same backend configuration as a run from
Xcode. Release/debug CI builds should pass the same values through
`--dart-define` or Codemagic variables.

## iOS Archive and App Store Distribution

The iOS release is `com.techmigos.arishville`. Build numbers must increase for
every App Store Connect upload; update the `+<build>` suffix in `pubspec.yaml`
before starting an archive (the current release is `1.0.21+32`). Do not commit
`env.supabase.json`, signing certificates, or provisioning profiles.

1. Make sure `env.supabase.json` contains the required production API,
   Supabase, and Firebase values.
2. Prepare the Release configuration. This regenerates Flutter's iOS package
   graph and aligns its generated Swift Package deployment target with the app
   target.

   ```bash
   scripts/prepare-ios-release.sh env.supabase.json
   ```

3. Create the Xcode archive from the workspace—not the `.xcodeproj` file:

   ```bash
   xcodebuild \
     -workspace ios/Runner.xcworkspace \
     -scheme Runner \
     -configuration Release \
     -destination 'generic/platform=iOS' \
     -archivePath "$PWD/build/ios/archive/Runner.xcarchive" \
     -allowProvisioningUpdates \
     archive
   ```

   The archive is written to `build/ios/archive/Runner.xcarchive`. Open it in
   Xcode with `open build/ios/archive/Runner.xcarchive`, then use Organizer to
   **Validate App** followed by **Distribute App → App Store Connect**.

4. App Store Connect distribution requires an **Apple Distribution**
   certificate and matching distribution provisioning profile for the bundle
   identifier. A development-signed archive is useful for local validation but
   cannot be uploaded as an App Store build. Select the distribution signing
   identity in Xcode/Organizer before exporting or uploading.

5. Before upload, verify the archive identity and version:

   ```bash
   /usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' \
     build/ios/archive/Runner.xcarchive/Info.plist
   /usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleVersion' \
     build/ios/archive/Runner.xcarchive/Info.plist
   codesign -dv --verbose=2 \
     build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app
   ```

### iOS privacy release checklist

- The binary does not use Core Location and does not declare a location usage
  string. Do not add `NSLocationWhenInUseUsageDescription` unless a future
  feature actually accesses location.
- `NSCameraUsageDescription` is for QR attendance; photo-library access is for
  user-selected school media and payment proofs. Keep these descriptions in
  sync with actual app behavior.
- Confirm the App Store Connect privacy questionnaire and privacy policy match
  the final app and bundled SDKs before distribution.

## Codemagic APK

`codemagic.yaml` builds Android debug APKs with:

- `API_BASE_URL=https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api`
- `SUPABASE_URL=https://ouvwogguttybmpgfgctc.supabase.co`
- `SUPABASE_ANON_KEY`
- `APP_ENV=production`
- `ENABLE_LOGGING=false`

## Project Structure

```text
android/                  Android project
ios/                      iOS project
lib/                      Flutter app source
assets/                   Bundled images, fonts, branding, policy assets
supabase/functions/api/   Supabase Edge Function API gateway and handlers
supabase/migrations/      Supabase database migrations
test/                     Flutter source and contract tests
```

## Verification

Use RAM-friendly serial checks:

```bash
flutter analyze
/home/vinay/.deno/bin/deno check supabase/functions/api/index.ts
flutter test --no-pub --concurrency=1 <test-file>
```

Do not run multiple Flutter test/build commands in parallel on low-memory machines.

## Documentation

Core project documentation is kept in the repository and includes:

- `PRD.md` and `SPECS.md` for product scope and acceptance rules.
- `LOCAL_SETUP.md`, `TESTING.md`, and `TEST_STRATEGY.md` for local development
  and verification.
- `docs/APP_STORE_RELEASE.md` and `docs/ARCHITECTURE_DECISIONS.md` for release
  and architecture decisions.
- The root-level audit documents and `INDEX.md` for the August 13, 2026 audit
  charter and its open remediation work.
