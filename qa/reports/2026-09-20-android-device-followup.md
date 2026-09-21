# Android device follow-up — 2026-09-20

## Environment

- Device: Moto G85 5G, Android 16/API 36, wireless ADB.
- Backend: Docker-local `schooldesk-local`, synthetic two-school fixtures only.
- API: `http://127.0.0.1:54321/functions/v1/api/health` returned HTTP 200 during and after the role run.
- ADB reverse `tcp:54321` routed only to the local API during testing and was removed afterward. The temporary debug app was uninstalled after testing. No Supabase cloud migration, function deployment, or production request was made.
- Build: debug integration APK from the current uncommitted working tree; package `com.techmigos.schooldesk1`.

## Completed device evidence

- `flutter test integration_test/local_role_login_smoke_test.dart -d adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp --dart-define-from-file=env.local.json --no-pub` completed **5 passed, 0 failed**.
- The test entered only local fixture credentials and asserted both the backend-resolved role and the concrete dashboard widget for Principal, Coordinator, legacy Admin, Teacher, and Parent. Legacy Admin routes to the Principal dashboard by the current route guard.
- This verifies Android app launch, sign-in input/submission, and role landing for those five fixtures. It does not cover Co-Teacher, Super Admin, Kiosk, logout/relogin, recording, or audit-log evidence required by the broader `AUTH-001` case.
- Android 16 displayed the notification permission prompt at app startup. `Allow` was selected on the QA device. No FCM message was sent or received, and no notification tap/deep link was verified.
- The camera permission prompt appeared; `While using the app` was selected. The Moto camera activity opened and was immediately canceled with Back; no image was captured. The Android gallery picker opened and was canceled without selecting a photo.
- The Android document picker returned the synthetic `SchoolDesk-QA.pdf` fixture to Flutter, and the filename assertion passed. The Android share chooser was foregrounded and dismissed with Back without choosing a target.
- A generated one-page synthetic PDF opened Android Print Spooler/`PrintActivity`; Android logcat recorded the PDF renderer activity. The preview was exited without printing or saving a file.

## Failed or incomplete checks

- The first unassisted native file-picker integration attempt reported `did not complete` / `No tests were found` while Android's permission/picker UI was active. A rerun with permission pregranted and live device interaction completed the callback, chooser, and print-preview checks.
- The first camera/gallery run passed both cancellation assertions but emitted a Flutter test warning because app startup changed `ErrorWidget.builder`. The test helper now restores `ErrorWidget.builder` and `FlutterError.onError`; targeted analysis passed, while that camera/gallery run was not repeated after the cleanup-only adjustment.
- Permission denial/permanently denied recovery, camera capture, app-form uploads/downloads, logout/relogin, FCM delivery/tap, background/resume, offline queue/reconnect, saved PDF output, and rendered production reports were not tested.
- During multi-role integration runs, nonfatal 401 logs appeared for background requests as the harness reset sessions between test cases. The final five role/dashboard assertions passed. Recheck those requests in a normal single-session logout/relogin flow before calling notification or dashboard side effects clean.
- The PDF smoke emitted the library warning `Helvetica has no Unicode support`; its synthetic page uses only ASCII. Validate non-ASCII names and script rendering in the full report workflow.
- A synthetic test PDF may remain in the device Downloads folder. No existing user file was opened, selected, changed, or deleted.

## Code/test harness adjustment

- `integration_test/local_role_login_smoke_test.dart` now checks the authenticated role and dashboard widget type. It includes Coordinator and accounts for the legacy Admin route mapping.
- `integration_test/android_native_file_share_smoke_test.dart` verifies Flutter file-picker callback, Android share chooser, and Android print-preview handoff with a synthetic PDF. `integration_test/android_native_media_picker_smoke_test.dart` verifies camera/gallery launch and cancel callbacks without selecting/capturing media.
- `lib/main.dart` retains the semantics handle across repeat test app starts and exposes test-only cleanup. The integration test disposes the handle before each widget test completes.
- Targeted Flutter analysis passed with no issues. Final device runs passed 5 role/dashboard cases, 1 camera/gallery case, and 2 document/share/print cases.
- Full Flutter regression after QA harness changes: **799 passed, 1 skipped, 0 failed**. Full `flutter analyze --no-pub`, questionnaire structural verification (196 cases / 115 routes), and `git diff --check` passed.

## Gate result

Android role login, camera/gallery cancel paths, Flutter file-picker callback, Android share chooser launch, and print-preview handoff are **PASS for the synthetic local smoke checks**. Full permission recovery, app-form upload/download, FCM delivery/tap, logout/relogin, offline reconnect, persisted PDF output, and iOS remain **BLOCKED / NOT VERIFIED**. Overall release readiness remains **BLOCKED**. Cloud migration-history divergence is unchanged; do not promote to Supabase.
