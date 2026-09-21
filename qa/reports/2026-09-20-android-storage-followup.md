# Android logout and local storage follow-up — 2026-09-20

## Environment

- Workspace: `HEAD 7d38ab5` plus uncommitted QA working-tree changes.
- Android: Moto G85 5G, Android 16/API 36, wireless ADB.
- Backend: Docker-local Supabase project `schooldesk-local`; synthetic two-school fixtures; API from the working tree.
- Network: Android ADB reverse to local `127.0.0.1:54321`; reverse mapping removed after the device test. Local API health returned HTTP 200.
- No Supabase cloud endpoint, real student data, payments, or real documents were used.

## Android session evidence

- Command: `flutter test integration_test/android_logout_relogin_smoke_test.dart -d adb-ZA2235WH4K-c1n0iS._adb-tls-connect._tcp --dart-define-from-file=env.local.json --no-pub`
- Result: **1 passed, 0 failed**.
- A synthetic Teacher opened the portal drawer, confirmed Sign Out, and returned to the signed-out landing screen. The access token, refresh token, cached role, and authenticated API state were empty. The same Teacher then signed in again and reached the Teacher dashboard.
- This verifies one role's logout/relogin flow. Principal, Coordinator, Admin, Parent, Co-Teacher, Super Admin, and Kiosk logout flows remain unverified; `AUTH-001` remains Blocked as a composite case.
- Two earlier harness attempts did not reach the logout action: one looked for a Settings row before it was available, and another attempted to scroll before the route had a scrollable. They produced no logout evidence and did not modify fixture records.
- A later start attempt found the wireless ADB device offline and stopped before launching Flutter. After the phone reconnected, the final on-device test passed.
- A Settings route attempt also exposed Flutter's `ListTile`/decorated-background warning. Settings section contents now have a transparent rounded `Material` surface; targeted analysis passed and the warning did not recur in the follow-up route attempt. The Settings content flow itself is not marked passed.

## Local private storage evidence

- Command: `scripts/local_storage_security_smoke.sh`.
- The loopback-only script created a uniquely named synthetic CSV in `school-private-files`, authenticated only with local School A and School B QA accounts, then removed the synthetic blob and row. A post-run database query confirmed **zero remaining smoke objects**.
- **Passed:** same-school Teacher upload and read; anonymous direct access denied; private bucket public URL denied; School B Principal direct read and signed-URL creation denied; authorized School A signed URL could be fetched anonymously; expired signed URL denied; disallowed SVG MIME type rejected.
- **Failed — `QA-SEC-002`:** the synthetic School A Parent could read the School A Teacher's private object directly (HTTP 200) and list it (the object appeared in the list response). The current `school_private_files_authenticated_read` policy in `supabase/migrations/20260810132041_media_egress_and_private_files.sql` scopes only by school ID, not by document owner, role, student link, or API-issued signed URL.
- **Failed — `QA-SEC-003`:** deleting the Teacher's allowed synthetic object through the Storage API returned HTTP 400 with `new row violates row-level security policy`, despite the checked-in same-school DELETE policy. The local QA cleanup removed the exact synthetic blob and metadata directly from the disposable Docker storage volume/database; the test confirmed no fixture object remained.
- This is a local Storage API/RLS failure. No migration was edited or pushed, and nothing was deployed to Supabase.

## Gate

- Keep `API-011`, `RISK-002`, and `SHARED-013` **Failed** until their respective access and delete behavior is fixed and retested. Their evidence is also linked in `test_cases.csv`.
- Production promotion remains **BLOCKED**. Do not promote the storage migration or proceed with hosted smoke checks while same-school private-file access and deletion are failing.
- Overall case counts after this follow-up: **163 Blocked, 30 Not Run, 3 Failed, 0 Passed**. A questionnaire case is not passed by partial subchecks.

## Final regression after the Settings surface change

- `LD_LIBRARY_PATH=/opt/lampp/lib flutter test --no-pub`: **799 passed, 1 skipped, 0 failed**.
- `flutter analyze --no-pub`: no issues.
- Questionnaire verifier: **196 cases / 115 routes**; required execution metadata is valid.
- `git diff --check`: passed.
- Docker-local API health: HTTP 200; no synthetic storage smoke objects remain; no ADB reverse mappings remain. The Moto G85 remains connected over wireless ADB.

## Later private Storage policy remediation — 2026-09-20

The findings above are the original pre-fix run. Local migration `20260920153106_restrict_private_files_to_service_api.sql` subsequently removed all authenticated direct-access policies for `school-private-files`. The revised focused smoke passed 21 checks, including Principal and linked Parent signed-URL API flows, same-school direct read/write/delete denial, cross-school API denial, and cleanup verification. The former direct Storage DELETE 400 is now understood as the expected result of API-only access; physical-object deletion/retention remains unverified. Production still has the original broad policies. See [local private Storage remediation](2026-09-20-local-private-storage-remediation.md).
