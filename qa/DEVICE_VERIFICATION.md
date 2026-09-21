# Physical Device Verification

**Build/Commit:** `HEAD 7d38ab5` plus uncommitted working-tree changes.

**Date:** 2026-09-20

## Must Test — Android

- [x] Install the debug QA build and verify cold start, login, and role landing for Principal, Coordinator, Teacher, Parent, and legacy Admin.
  - Why physical verification is required: installation, startup, keyboard, touch, and Android lifecycle behavior run on the Android OS.
  - Evidence: Moto G85 5G / Android 16/API 36; five role/dashboard assertions passed against Docker-local synthetic fixtures. See [Android device follow-up](reports/2026-09-20-android-device-followup.md).
  - Logout/relogin and screenshot/video evidence are not included in this pass.
- [ ] Verify logout clears session and cached role data, then relogin for each role.
  - Partial pass: Teacher signed out through the portal drawer; access, refresh, and role values cleared; the same Teacher logged back in and reached the dashboard. Other role logout flows remain unverified. See [Android logout and storage follow-up](reports/2026-09-20-android-storage-followup.md).
- [x] Camera and gallery intents open and cancel on Android.
  - Why physical verification is required: Android permission prompts, URI grants, camera intents, and filesystem access are OS-controlled.
  - Evidence: camera permission was allowed while the app is in use; the Moto camera activity opened and was canceled without capture. The Android gallery picker opened and was canceled without selecting a photo.
- [x] Android file picker callback returns the synthetic PDF; Android share chooser and print-preview intents open.
  - Evidence: `SchoolDesk-QA.pdf` was selected from Downloads and returned to Flutter; the Android share chooser was dismissed with Back without choosing a target; Print Spooler `PrintActivity` opened for a generated synthetic one-page PDF.
- [ ] Exercise denied/permanently denied recovery and app-form upload/download; save/open a generated report PDF and verify its rendered values, fonts, and scope.
  - The device smoke covered plugin handoff only. The generated PDF used ASCII text and emitted a Helvetica Unicode-support warning; non-ASCII rendering remains unverified.
- [ ] Push receipt, notification tap, and killed-app deep link.
  - Why physical verification is required: actual FCM delivery and Android notification routing require a registered device token and OS notification service.
  - Partial observation: Android 16 displayed the runtime notification permission prompt during app startup; `Allow` was selected. No FCM message was delivered or tapped.
  - Steps: register an isolated QA device, trigger a synthetic event, receive the notification in foreground/background/killed states, tap it, verify the destination and recipient.
  - Expected result: one notification reaches the correct role and opens the correct approval/detail route without exposing another tenant.
- [x] Resume after Android camera and gallery activity handoff.
  - Evidence: app-side picker calls returned after the Moto camera and Android photo picker were canceled with Back.
- [ ] Process background/restart and offline-to-reconnect behavior.
  - Why physical verification is required: Android process lifecycle, connectivity changes, WorkManager scheduling, and durable local storage vary by OS/device.
  - Steps: queue an approved offline-capable write, background/force-stop as applicable, restore network, resume, and compare local/server state and idempotency.
  - Expected result: one server mutation, no lost draft, no duplicate replay, and correct refreshed scope.
- [ ] Download/open a generated PDF file in an external viewer and verify its content and Android share behavior.
  - Why physical verification is required: external viewer handoff, download destination, font rendering, and share intents are native behavior.
  - Partial observation: Android share chooser and print preview opened for a generated synthetic PDF. No target was selected and no file was saved/opened in an external viewer.
  - Steps: export a synthetic report, open it in a viewer, inspect page layout and values, and check scope.
  - Expected result: readable pages and correct values; no private URL or other-school content.

## Emulator evidence

- The Pixel 2 AVD is configured, but it is not a physical device. Startup failed: the AVD points to `android-30/default/x86_64`, which is absent under the configured Android SDK. No Android integration test ran.

## Moto G85 initial wireless attempt — 2026-09-20

- A Moto G85 5G running Android 16/API 36 appeared in `adb devices -l` over wireless ADB.
- The local API health endpoint returned HTTP 200. ADB reverse was configured for device `localhost:54321` to reach the Docker-local API.
- Flutter built `build/app/outputs/flutter-apk/app-debug.apk` (173 MiB). Installing it stalled for 333 seconds and ended with `ADB exited with exit code -2`; Flutter then reported **No tests ran**.
- The host saw 75% packet loss in a four-packet ping to the device (one reply at 442 ms). Device shell calls also timed out, so login, permissions, files, notifications, background/reconnect, and PDF handoff were not exercised.
- The attempt to remove the ADB reverse mapping timed out with the same transport problem. It may remain on the device until its ADB connection is reset; when the link is stable, run `adb reverse --remove tcp:54321` to clear it.
- This initial attempt was a test setup failure, not a product defect. The wireless link later recovered; see the completed and incomplete checks below.

## Moto G85 resumed device checks — 2026-09-20

- The wireless ADB transport became responsive. The local API health endpoint returned HTTP 200 at `/functions/v1/api/health`, and `adb reverse tcp:54321 tcp:54321` routed only to Docker-local Supabase during testing.
- The role integration runner installed and ran the debug app. Principal, Coordinator, legacy Admin, Teacher, and Parent each authenticated and reached the expected dashboard widget: **5 passed, 0 failed**.
- Camera permission prompt appeared; `While using the app` was selected. Camera and gallery pickers were opened and canceled without capturing or selecting media.
- Android DocumentsUI returned the synthetic PDF to Flutter; the Android share chooser opened and was dismissed without sharing externally. Print Spooler `PrintActivity` opened for a generated synthetic PDF and was exited without printing/saving.
- Notification permission prompt appeared and was allowed. FCM receipt/tap, killed-app routing, logout/relogin, offline reconnect, and app-form upload/download remain unverified. No existing device file was opened or selected.
- The debug app was uninstalled and the ADB reverse mapping was removed after testing. A synthetic PDF fixture may remain in Downloads.
- See [Android device follow-up](reports/2026-09-20-android-device-followup.md) for the command and limits.

## iOS

- [ ] iOS build, installation, permissions, notifications, background behavior, and file handling remain **Blocked**. This Linux environment has no Xcode/iOS runtime. iOS is outside the accepted Android-only device matrix for this cycle, but overall mobile release readiness remains blocked until the required iOS evidence is recorded.

## Not Required

- Source, unit/widget, Docker API/RLS, and web build checks are recorded in the local QA report; they do not substitute for the physical checks above.

## Result

**Partial / BLOCKED** — five role login/dashboard checks, one Teacher logout/relogin flow, camera/gallery cancel paths, PDF picker callback, share chooser launch, print-preview launch, and fresh APK cold start passed. Other role logout/relogin, denied-permission recovery, app upload/download, FCM delivery/tap, background/reconnect, saved/viewed PDF evidence, and remaining release gates are incomplete. The focused local private Storage authorization smoke passes, and the reviewed migration was promoted; see [storage remediation](reports/2026-09-20-local-private-storage-remediation.md) and [production promotion](reports/2026-09-20-production-promotion.md). Overall mobile release remains blocked.

## Fresh regular debug APK — 2026-09-20

- Built `build/app/outputs/flutter-apk/app-debug.apk` with `flutter build apk --debug --no-pub --dart-define-from-file=env.local.json`. SHA-256: `82a2f5727675bb2067f6651dbc09f2f257019ce930c5f0e92cc171d91b70d779`.
- Installed successfully on Moto G85 5G / Android 16/API 36 over wireless ADB, configured reverse port `tcp:54321` to the Docker-local API, and launched `com.techmigos.schooldesk1/.MainActivity`.
- Device screenshot showed the updated landing carousel artwork after the Android notification permission was allowed. There was no app fatal exception in the startup log. Evidence: [Moto G85 startup screenshot](reports/evidence/2026-09-20-moto-g85-local-startup.png), SHA-256 `2b30a46ee959d835d791c0efa61ef1c6866369e761ea334fdaf7d3a6e299a3f5`.
- Tapped **Sign in** and reached the role selector/login form showing Principal, Teacher, and Parent entry options. It is left at that screen for the user's manual local-role walkthrough. Evidence: [role selection screenshot](reports/evidence/2026-09-20-moto-g85-local-role-login.png), SHA-256 `74c18d21c12c74f0a90746f9acc51e768cc1fe6750899fabc88ea5f09d284239`.
- All six landing slide assets are `941 × 1672` pixels (approximately 9:16). They load on the device. This confirms artwork rendering, startup, and navigation to role selection only; no role was signed in during this handoff, so the user's manual role walkthrough and Approval Center UI verification remain open.
- Docker-local API health was HTTP 200 before and after install and reported `storage=legacy-compatible`; production health reported `storage=r2-configured`. ADB reverse routes this build to Docker; it does not point the app at Supabase production. The local device pass does not verify the production R2 object path.
- Backend promotion of four reviewed migrations and the `api` function is complete. Live authenticated production workflows, FCM receipt/tap, background/reconnect, full document upload/download, saved PDF rendering, and iOS are still blocked or unverified.
