# Flutter frontend role matrix — 2026-09-25

Estimated frontend rewrite completion: **97%**. This is an engineering
progress estimate, not a release gate; supported-target and remaining
migration gates still decide completion.

## Verified locally

### Final frontend contracts in this pass

- The complete route inventory is now owned by `TypedAppRouteRegistry`; the
  legacy named-navigation API appears only in the compatibility adapter's
  isolated fallback. Typed route contract tests cover path parity, role entry
  points, shared role arguments, and the no-bypass scan.
- The remaining parent/principal fee deep-link aliases are explicitly bound to
  typed route contracts and no longer rely on a generic compatibility screen
  factory. Every no-argument route is also registered in the explicit typed
  screen inventory, which fails fast if a path is omitted. A role workflow
  matrix test covers Principal, Coordinator, Teacher,
  Parent, Kiosk, and Super Admin required surfaces; it also asserts that
  Coordinator cannot enter finance routes and that Kiosk cannot enter other
  role surfaces.
- Shared Parent and Teacher navigation now preserves the API-provided tenant
  school identity; the previous fixed school-name overwrite was removed and is
  covered by the real-runtime-data contract suite.
- Teacher dashboard title now reads repository-provided `schoolName` from the
  current-school API response; its fixed branded runtime title was removed and
  covered by the same contract suite.
- Shared Help and School Gallery screens now use injected repositories and
  `RepositoryState<T>` rendering. Their direct widget-level API calls are gone;
  cached, stale, error, empty, loading, and retry states use the shared view.
- Principal Analytics now uses a dedicated capability repository for paged
  invoice, notification, and staff reads; its screen no longer depends on the
  legacy `BackendDataService`.
- Academic Information, Academic Management, Admin Dashboard, ID Card
  Generation, and Reports Analytics now use typed capability repositories; the
  remaining `BackendDataService` references are confined to repository adapters
  and are not reachable from feature widgets.
- Coordinator back navigation and home fallback now resolve to the dedicated
  Coordinator dashboard; the startup/back contract suite covers this route.
- The same role-aware back target is enforced for leadership screens whose
  registry metadata is Principal-owned but accessible to Coordinator.
- Back-target resolution now uses the active authenticated role before portal
  metadata, covering Super Admin access to school-owned management screens as
  well.
- Notification fallback resolution is revalidated after payload
  classification. Super Admin approval notifications fall back to the shared
  notification center, while generic Kiosk notifications fall back to the
  isolated QR attendance route; neither can target a Principal-only or shared
  route outside its role boundary.
- Every active route manifest declares cached reads plus the complete typed
  repository state contract: loading, stale, offline, error, empty, and retry.
  Online-only mutations are surfaced by the route frame without hiding cached
  reads. All 82 feature screen files now declare a typed repository-state
  contract; 78 use the shared state renderer directly and four dashboards keep
  specialized repository-state shells. This includes
  Principal Attendance, Principal Subjects, Principal Event Approval, Teacher
  Classes, Teacher Attendance History, Teacher Leave, Fee Payment Config,
  Parent Health, Parent Lesson Planner, Parent Timetable, Teacher Complaints,
  Parent Complaints, Principal Payment Config, Teacher Documents, Parent
  Documents, Teacher Timetable, Academic Info, Principal Lesson Planner, and
  ID Card Generation, Parent Attendance, Parent Receipt, Parent Payment
  History, Parent Leave, Parent Homework, Parent Calendar, Teacher My
  Attendance, Parent Homework Submission, Principal Fee Dashboard, and Admin
  Attendance, Admin Documents, Admin Students, Admin Teachers, Approval Center,
  Admin User Access, and Teacher Attendance. The final declaration scan finds
  zero feature, role, or module files with the retired local loading/error flag
  pattern.
- Principal and Parent dashboard surfaces now expose repository stale/offline
  state while retaining cached content and retry actions across responsive
  layouts.
- Drift schema version 5 and the sync engine now cover account-scoped
  idempotency uniqueness, ordered replay, retry/backoff, permanent failures,
  conflicts, upload dependencies, and restart recovery. Focused offline tests:
  **19 passed, 0 failed**.
- The final package ledger was rerun after upgrading all compatible direct
  packages. The remaining newer versions are SDK-incompatible or intentionally
  overridden; Freezed 4.0.2 is the only requested generator version blocked by
  the current Flutter test/analyzer pins.

- Local Supabase was prepared from the checked-in migrations and synthetic seed.
- The local reset replayed all checked-in migrations, and the Edge Function
  contract suite passed **26/26** before the authenticated HTTP probes ran.
- The repeatable role smoke is `scripts/local_role_api_smoke.sh`.
- The read-only feature smoke is `scripts/local_role_feature_smoke.sh`; it
  covers real school, people, attendance, homework, leave, finance,
  documents, calendar, chat, notifications, reports, monitoring, and kiosk
  API surfaces.
- Principal, Admin, Coordinator, Teacher, Parent, Kiosk, and Super Admin login
  with the generated local credentials.
- All seven roles return HTTP 200 from `/auth/profile`.
- Principal, Admin, Coordinator, Teacher, Parent, and Super Admin return HTTP
  200 from their role dashboard endpoint.
- Kiosk returns HTTP 200 from its actual frontend endpoints: QR token,
  attendance log, and QR log export. `/dashboard/kiosk` is intentionally not a
  kiosk surface and returns HTTP 403.
- The feature matrix passed with expected restrictions: coordinator, teacher,
  parent, and kiosk finance or cross-role probes returned HTTP 403; all
  permitted read surfaces returned HTTP 200.
- The repeatable `scripts/local_mutation_smoke.sh` passed for authorized profile
  `GET`/`PATCH` and notification-preferences `GET`/`PUT`; the security and
  storage smokes passed private document `POST` upload and guarded Storage
  `DELETE` behavior. The API rejects `PATCH /auth/profile` with
  `{"language":"en"}` as HTTP 400 because the local `users` schema does not
  contain a `language` column; name/phone profile PATCHes pass, and the current
  Flutter profile screen does not send `language`. Track this as a backend
  contract defect, not as a device/emulator failure.
- The role smoke scripts now assign isolated synthetic loopback client IPs for
  fixture logins, preventing repeated API-only validation runs from exhausting
  the shared login rate-limit bucket. The dedicated security smoke retains a
  fixed synthetic IP for its intentional HTTP 429 assertion.
- The final API-only pass also completed **25/25** authorization/security
  checks and **21/21** private-Storage checks. Docker-local services were
  stopped after validation; no emulator or physical device was used.
- Route and capability contracts pass. Coordinator has a separate shell and no
  finance access. Kiosk is restricted to QR attendance.
- Registered-route completeness now passes: every compatibility route has
  screen metadata and an explicit public, shared, or role ownership boundary.
- Kiosk UI now states that live QR tokens require an online connection and
  exposes an accessible retry action; its offline-required widget test passes.
- Full Flutter host suite: **839 passed, 1 skipped, 0 failed** on the final rerun
  with a temporary user-owned `libsqlite3.so` compatibility link for Drift.
  The unwrapped host command had five SQLite loader failures caused by the
  missing soname, not Dart test failures.
- `RepositoryState.copyWith` now preserves omitted nullable fields while
  allowing explicit null clearing for cached data, errors, and timestamps;
  focused contract coverage passes.
- Teacher Attendance now uses a typed repository for staff QR attendance,
  class roster/enrollment reads, session history, draft/final writes, and
  correction requests; focused contracts and analyzer checks pass.
- Teacher Homework list/review counts, reminder actions, deletion, uploads,
  assignment creation, edit form, diary write, and submission review now use
  the typed repository; offline draft behavior remains in the API adapter.
- Teacher Communication now uses a typed repository for profile, conversation
  and contact reads, incremental messages, read receipts, conversation creation,
  and offline-capable message send.
- Parent Homework now uses a child-scoped repository for linked students,
  homework, submissions, attachments, and submission writes.
- Teacher Documents now uses a typed repository for student documents, personal
  documents, private upload, deletion, and document creation.
- Parent Documents now uses a child-scoped repository for child documents,
  school/profile context, private upload, deletion, and document creation.
- Parent Teacher Chat now uses a child-scoped repository for profile, children,
  contacts, conversations, messages, read receipts, and offline-capable sends.
- Parent and Teacher Complaints now use a shared scoped repository for cached
  reads, create/update writes, and super-admin error reports.
- Teacher Timetable and Lesson Planner now use typed repositories for scoped
  schedule reads, class metadata, uploads, and lesson-plan writes.
- Parent Timetable and Health Updates now use child-scoped repositories for
  timetable reads, reminder history, and reminder mutations.
- Principal Reports now use a typed repository for school context, staff
  attendance, approved leave, and report-export recording.
- Parent Lesson Planner and Parent Calendar now use child-scoped repository
  boundaries; the active shared Events Calendar screen also uses a typed
  calendar repository for reads and event mutations.
- Admin Reports now use a typed repository and render an explicit unavailable
  state when the API does not provide compliance data; fabricated compliance
  rows and deadline values were removed.
- Admin Students now use a typed people repository for directory reads,
  parent linking, approval requests, and student mutations. Missing dates no
  longer become invented 2010/2026 values; the student form requires a valid
  date of birth.
- Admin Teachers now use a typed staff-directory repository for staff paging,
  leave decisions, and teacher create/edit actions.
- Guardian Directory now uses a typed repository for parent/student directory
  reads, parent account changes, avatar uploads, links, and guardian-row CRUD.
- Principal Timetable, Principal Subjects, and Complaint Management now use
  injected capability repositories; the unused timetable form and parent fee
  remote data-source duplicates were removed after reference scans.
- Academic-year management, audit logs, system monitoring, global search,
  landing posts, settings password changes, authentication, and notification
  diagnostics now use explicit capability repositories.
- Parent Fee Hub, Payment History, Receipt, Principal Fee Dashboard, Payment
  Requests, Fee Structures, and Fee Collection now use fee repository
  boundaries with pagination and decision filters preserved.
- `flutter analyze --no-fatal-infos`: passed.
- `dart run dependency_validator`: passed.
- Runtime boundary contract: **8 passed, 0 failed** after the
  Parent/Teacher/Teacher-dashboard branding fixes and shared-screen repository
  migration plus Principal Analytics repository migration.
- Route, manifest, modular architecture, typed-router, and repository-boundary
  focused suite: **28 passed, 0 failed**.
- Generated-code build: passed.
- Debug APK build: passed at `build/app/outputs/flutter-apk/app-debug.apk`.
- Latest post-dependency-migration debug APK rebuild passed. Current debug APK
  SHA-256: `db93e474f84b0157d9ee53ba981f7a1e224f5f6c7aafccd1c77f0e532c4e3fd8`.
  Current release APK SHA-256:
  `6e94790ecab64ed174b9869c2d8dfc8b6c9955b1463060c2bfe5367a5c97cd36`;
  APK ZIP integrity and v2 signature verification passed. Current release AAB
  SHA-256: `9bde70db3222e4a000ec62e0a9db22717110df840781cd849de13e2807774582`;
  ZIP integrity and JAR verification passed. No production signing material
  was used.
- The resolved graph uses exact-version local compatibility copies for
  `firebase_core` 4.15.0, `firebase_crashlytics` 5.4.0, and
  `workmanager_android` 0.10.9. Their only native change is replacing the
  legacy Kotlin plugin application expression with the equivalent plugin
  manager call. Verbose debug and release builds completed without Flutter's
  KGP compatibility warning.
- iOS configuration-only validation: `Info.plist`, entitlements,
  `AppFrameworkInfo.plist`, Xcode project, and workspace are structurally
  present; `Info.plist` is XML-valid. This Linux host has no Xcode or CocoaPods, and the
  installed Flutter CLI has no iOS build subcommand (`flutter build ios` is not
  available here), so no iOS binary claim is made.
- `flutter pub outdated --show-all`: reviewed after `flutter pub upgrade`.
  `cached_network_image` is now on 4.0.2, `package_info_plus` is on 10.2.1,
  `share_plus` on 13.3.0, and maintained
  federated `file_picker` is on 13.1.0; file-selection flows now use
  `PlatformFile.readAsBytes()`. The compatible locked `archive` and `cli_util`
  packages were refreshed. Very Good Analysis is now 11.0.0. Freezed 4.0.2
  and newer analyzer/test pins remain blocked by the current Flutter SDK
  compatibility set. Freezed 4.0.1 remains the newest resolvable generator.
  is resolvable but is outside this runtime rewrite; the local printing
  override remains intentional.
  The local `printing` override remains intentionally isolated.
- Responsive/accessibility layout sweep: passed for compact phone, large text,
  tablet, landscape, light mode, and dark mode.
- The typed router now listens to session, role, and branch changes so login,
  logout, and role-scope changes refresh redirects immediately. The shared
  status panel also has a non-color stale-data state with an accessible refresh
  action, covered by widget tests.
- Every active route now has a feature manifest. Offline mutation routes expose
  an accessible online-required banner while cached reads remain visible.
- Push and in-app notification taps now use a GoRouter-aware navigation adapter
  and preserve route extras, with legacy Navigator fallback for isolated hosts.
- Questionnaire verifier: 196 cases and 114 registered routes validated.

## Completion view

| Gate | Result |
| --- | --- |
| Role contracts and route permissions | 7/7 verified |
| Local API entry surfaces | 7/7 verified |
| Role feature API matrix | 7/7 roles, expected 200/403 boundaries |
| Host unit/widget/regression suite | 839 passed, 1 skipped, 0 failed |
| Mobile device role walkthroughs on this revision | 0/7 — no device or emulator connected |
| Browser walkthrough | Not run — no supported web target in this project |
| iOS artifact/configuration gate | Configuration passed; no binary — Linux host |
| Typed router replacing legacy runtime registry | Complete; only isolated adapter fallback remains |
| Flutter KGP warning | Closed for the resolved graph; local compatibility copies are documented and builds are warning-free |

## Open gates

The current frontend-only validation pass is green for the host-side gates. The
typed GoRouter runtime is active at the composition root and feature code has no
direct legacy named-route calls. Device walkthroughs, notification taps,
reconnect behavior, media/file handoff, and live visual verification are
intentionally outside this pass.

Static scan now finds zero legacy `BackendApiClient.instance` references in
feature Dart files. Kiosk QR data, all six role dashboard entry points,
Teacher and Parent Leave, Parent Attendance, Teacher Attendance, complete
Teacher Homework, Teacher Communication, Teacher and Parent Documents, Parent
Homework, Parent Teacher Chat, Parent/Teacher Complaints, Teacher Timetable,
Teacher Lesson Planner, Parent Timetable, Parent Health Updates, Principal
Reports, Principal Attendance, Admin Attendance, Principal Event Approval, Principal Chat Communications, School Posts, Profile Management, Admin Students, Admin Teachers, Guardian Directory, Parent Calendar,
Parent Lesson Planner, Principal Academic Years, Principal Timetable, Principal Subjects, Finance Operations, Fee Forms, Fee Ledger, Fee Home, Parent Fee Hub, active Events Calendar, Issue Management, Admission
Inquiries, Principal Classes Hub, Student Oversight, Approval Center, Admin
Documents, Principal Lesson Planner, Payment Configuration, Parent Fee Payment,
Staff Management, User Access, and Payment Requests now use repository
boundaries. The final frontend source scan reports zero legacy local
loading/error flag declarations. Route contracts, offline repository
contracts, and host-side regression gates are complete. Supported-target live
walkthroughs remain intentionally excluded from this goal.

The Android debug, release APK, and release AAB builds succeed with AGP 9.0.1
and KGP 2.3.20 using the typed Kotlin compiler options DSL and
`android.builtInKotlin=true`. The app module no longer applies
`org.jetbrains.kotlin.android`. Flutter's static detector is also satisfied by
the exact-version local compatibility copies for Firebase Core, Crashlytics,
and Workmanager Android; no Flutter KGP compatibility warning was emitted.

Code generation succeeds. The current Flutter/Dart toolchain still reports
the non-fatal analyzer-language mismatch (`SDK language version 3.13.0` versus
the installed analyzer language version `3.11.0`); this is recorded separately
from generated-code correctness.
