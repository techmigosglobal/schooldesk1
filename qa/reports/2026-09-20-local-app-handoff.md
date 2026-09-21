# Local Android app handoff — 2026-09-20

## Local backend

- Target: Docker-local Supabase project `schooldesk-local`, using synthetic two-school fixtures.
- The Edge Runtime container was recreated with cached `public.ecr.aws/supabase/edge-runtime:v1.74.3` because the prior v1.70.0 runtime rejected the function lockfile. Postgres, Storage, and fixture volumes were left in place.
- `http://127.0.0.1:54321/functions/v1/api/health` returned HTTP 200 after the runtime update (`version: 2.0.0-supabase-r2`).
- The local app config in `env.local.json` points to `http://127.0.0.1:54321/functions/v1/api`. No cloud deployment or cloud request was made.

## App artifact

- Build command: `flutter build apk --debug --no-pub --dart-define-from-file=env.local.json` — succeeded.
- APK: `build/app/outputs/flutter-apk/app-debug.apk` (262,484,059 bytes).
- Android package/version: `com.techmigos.schooldesk1`, `1.0.25` (`versionCode 37`).
- SHA-256: `ec7509d190e33922299a1c9347cee577762cdc920db080606f5c10654184b52f`.

## Device/install status

- Device: Moto G85 5G, Android 16/API 36, wireless ADB (`adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp`).
- `adb reverse tcp:54321 tcp:54321` is active (`host-8 tcp:54321 tcp:54321`).
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk` returned **Success**. The app was launched; Android's notification permission prompt is currently foregrounded for the user's choice.
- Host local API health remains HTTP 200. The existing role logins are in local `env.local.json`; use only these synthetic QA accounts.
- Role login/dashboard outcomes are still **Not Run** in this handoff. The user will test the roles manually; record each outcome and any defect in the device checklist afterward.

## Manual role checklist

Use the corresponding synthetic account from `env.local.json`. Check sign-in, role home screen, displayed school/tenant, and any unexpected error. Keep each row Pending until the user reports the result.

| School/scope | Role | Username | Status |
|---|---|---|---|
| School A | Principal | `principal` | Pending |
| School A | Admin | `admin` | Pending |
| School A | Coordinator | `coordinator` | Pending |
| School A | Teacher | `teacher` | Pending |
| School A | Parent | `parent` | Pending |
| School A | Student | `student` | Pending |
| School A | Kiosk | `kiosk` | Pending |
| School B | Principal | `second-principal` | Pending |
| School B | Admin | `second-admin` | Pending |
| School B | Coordinator | `second-coordinator` | Pending |
| School B | Teacher | `second-teacher` | Pending |
| School B | Parent | `second-parent` | Pending |
| School B | Kiosk | `second-kiosk` | Pending |
| Organization | Super Admin | `superadmin` | Pending |
