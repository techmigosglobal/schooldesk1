# SchoolDesk Complete QA Questionnaire

This is the execution guide for `test_cases.csv`. The CSV is the source of
execution status; this document defines the test conditions, evidence rules,
and release gates that apply to every row. It currently contains 196 executable
cases, including explicit coverage for all 115 unique routes in the Flutter
screen registry.

## 1. Product and role contract

SchoolDesk is a Supabase-backed, multi-branch school ERP with a complete
mobile experience and a leadership-only web portal. Backend data and
server-side authorization are authoritative. A UI-hidden action is not
considered restricted until its direct API, database policy, storage path, and
deep link are also denied.

| Role | Required scope | Core restrictions |
| --- | --- | --- |
| Principal | Entire school; one selected active branch at a time | Must not operate without a valid branch context |
| Coordinator | Exactly one assigned branch | No Finance/Fees navigation, API response, report, approval, or storage access |
| Class Teacher | Assigned classes/subjects | No school-wide or unrelated class access; correction/reopen rules apply |
| Co-Teacher | Shared assigned classes/subjects | No inherited Principal/Coordinator access; limited ownership capabilities |
| Parent | Explicitly linked child or children | No unlinked child, school-wide, or other-parent data |
| Super Admin | Platform/system scope | No implicit school operational access |
| Kiosk User | Validated QR attendance flow | No directory, Finance, reporting, communications, or administration |

The product-facing role is **Coordinator**. Existing references to Admin are
legacy terminology and must not create a separate role. The product-facing
academic term is **Diary**, not Dairy.

## 2. How to execute each case

For every case in the CSV:

1. Record the build/version, backend revision, database migration revision,
   browser/device, account, school, branch, child/class identifiers, locale,
   network profile, and tester.
2. Start from the stated precondition and use isolated QA records. Never use
   real production students, parents, payments, credentials, or documents.
3. Execute the positive flow, then execute the listed negative/boundary
   condition. Do not mark a case passed because the button is hidden.
4. Verify the UI, HTTP response, database state, storage object/policy, audit
   event, notification, and downstream role view whenever the case requires
   them.
5. Attach evidence and record the exact defect ID for every failure. A case is
   `Passed` only when its required evidence type is present.

### CSV execution fields

The tracker separates design information from execution evidence:

- `Evidence Required` describes what must be collected; `Evidence
  Link/Attachment` records the actual screenshot, trace, report, video, log,
  or artifact location.
- `Priority` controls execution order. `Severity` records impact if the case
  fails. They are intentionally separate and must not be used interchangeably.
  Existing priority values were preserved for continuity; the initial severity
  values are conservative starting classifications and must be confirmed when
  a defect is actually observed.
- `Test Type` is a controlled primary category. `Execution Method` is a
  semicolon-separated controlled set such as `Manual;API`, `Automated;RLS`, or
  `Browser;Artifact`.
- `Execution Date`, `Tester`, `Build/Commit`, `Backend/Migration`,
  `School/Branch/Fixture`, `Account/Device/Browser`, and `Network/Locale` must
  be filled for every executed case.
- `Actual Result` records what happened. `Status` is one of `Not Run`,
  `Passed`, `Failed`, `Blocked`, or `Not Applicable`. A `Passed` row must have
  an evidence link, actual result, tester, date, and build/commit.
- `Granularity` identifies `Atomic` versus `Composite - split before
  execution`. Composite rows include `Atomic Subcases`; create child rows or
  execute each listed subcase separately before marking the parent passed.

Run the structural and route checks with:

```bash
python3 tool/verify_test_questionnaire.py
```

### Reusable conditions for every list and detail screen

- Loading skeleton appears before data arrives.
- Successful zero-row response displays an Empty state, not an Error state.
- 403 displays Permission Denied, not Empty.
- 404 displays Not Found or the documented safe fallback.
- Network/5xx failure displays an actionable Error with Retry.
- 409 displays Conflict and preserves the user’s unsaved intent where safe.
- 422 displays field-level validation errors.
- 429 follows the rate-limit message and retry policy.
- Pagination, search, sorting, filters, refresh, and concurrent updates do not
  duplicate, omit, or cross-scope rows.
- Data shown after refresh matches the backend record, not a stale fixture.

### Reusable conditions for every form and mutation

- Required, length, format, date, numeric, currency, attachment, and
  relationship validations are tested at minimum, maximum, empty, malformed,
  Unicode, and whitespace-only values.
- Double taps, retries after timeout, back navigation, app kill, and duplicate
  submissions are tested.
- A successful mutation is checked in the database and in every authorized
  downstream role view.
- Unauthorized role, branch, class, child, user, invoice, document, and
  conversation identifiers are tested directly against the API.
- Sensitive mutations create a complete immutable audit event.

## 3. Test environment and data

Use a connected, production-like QA environment with:

- One QA school with at least two branches.
- Principal with both branches; Coordinator with one branch only.
- Class Teacher and Co-Teacher assigned to the same class, plus an unrelated
  class and subject.
- Parent linked to two children, another parent with different children, and
  similar student/guardian names to detect name-based matching.
- Super Admin and isolated Kiosk accounts.
- Academic years, terms, classes, subjects, timetables, planners, attendance
  sessions, staff attendance, leave, Diary, submissions, complaints, events,
  gallery media, documents, admissions, notifications, and chat fixtures.
- Finance fixtures covering unpaid, partially paid, fully paid, overdue,
  concession, pending proof, rejected proof, receipt, and reversal states.
- Valid and invalid file fixtures: image, PDF, unsupported executable, empty
  file, oversized file, double extension, unsafe filename, and path traversal.

Tests must be repeatable. Reset or namespace QA records between runs and keep a
before/after database snapshot for destructive-looking workflows. Financial
history, audit logs, identity records, and documents must never be physically
deleted as part of cleanup; use an approved isolated fixture reset.

## 4. Evidence classification

| Evidence | Proves | Does not prove |
| --- | --- | --- |
| Automated | Repeatable code, contract, unit, widget, or static behavior | Real login, live RLS, device interaction, FCM, or rendered PDF |
| API/database/RLS | Server response, authorization, persistence, transaction, and policy | Usable UI, accessibility, device camera, or print layout |
| Browser | Web navigation, responsive layout, authenticated interaction, and public rendering | Mobile behavior or physical FCM delivery |
| Mobile device | Startup, touch, camera, back, permissions, uploads, and real device behavior | Server policy unless paired with API/database evidence |
| PDF/export | Actual downloaded/rendered content, layout, fonts, values, and scope | Source code generation alone |
| FCM/live session | Correct push recipient, token lifecycle, realtime, and downstream handoff | Static notification service contracts |
| Release/artifact | Build, install, signature, configuration, checksum, and package integrity | Successful authenticated production workflow |

## 5. Cross-role acceptance chains

These chains must be executed with separate authenticated sessions and
verified at every handoff:

1. Teacher leave → Principal/Coordinator approval → Teacher status and
   notification.
2. Parent child leave → assigned approver → Parent status, remark, and
   notification.
3. Teacher Diary → Parent submission → Teacher feedback → Parent visibility.
4. Teacher event post → leadership approval/rejection → school feed/public
   website.
5. Parent payment proof → Principal decision → immutable ledger and receipt.
6. Teacher attendance → Parent visibility → correction request → approved
   history.
7. Principal branch switch → cache invalidation → new branch data in dashboard,
   lists, reports, and notifications.
8. Any producer event → exactly one durable notification → correct in-app and
   FCM recipient.

## 6. Security and data-integrity gates

The following are release blockers:

- Forged role, branch, class, subject, child, user, invoice, document, or
  conversation identifiers are accepted.
- Coordinator receives any Finance field, route, report, approval, storage
  object, or cached response.
- Parent receives another child’s data or a private document through a direct
  URL.
- Teacher or Co-Teacher accesses an unrelated class or changes ownership by
  client-provided flags.
- Kiosk can enumerate students or access operational routes.
- A payment, receipt, audit row, or financial snapshot is physically deleted.
- A retry creates duplicate payment, attendance, approval, upload, message, or
  notification records.
- A 403, backend failure, or stale cache is presented as an empty successful
  list.
- Private files are publicly listable or downloadable without a valid signed
  URL.
- Logs, errors, exports, or artifacts contain passwords, tokens, private URLs,
  payment proofs, or unnecessary personal data.

### Known risks tracked by the questionnaire

The following risks have dedicated `RISK-*` cases in the CSV and must be
reported independently of general regression coverage:

- Payment deletion must be removed or replaced by an audited atomic reversal.
- Student/staff private records must not remain publicly listable or
  downloadable through mixed storage buckets.
- Dashboard requests must reject lower-privileged users requesting higher-role
  paths or fields.
- Backend failures and permission denials must never be rendered as successful
  empty lists.
- Failed branch switches must show an actionable error and must not mislabel
  stale data as the newly selected branch.
- User-facing `Dairy` labels must be corrected to `Diary` while any backend
  compatibility alias remains documented.

## 7. Non-functional and release gates

Before release, attach evidence for:

- Flutter analyzer, unit/widget/integration tests, and web type/test/build
  checks.
- API contract tests, migration lint, RLS matrix, storage policy checks, and
  health/readiness responses.
- Mobile Android/iOS device smoke tests for login, back behavior, attendance,
  upload, notification, PDF, and offline recovery.
- Browser smoke tests for Principal and Coordinator, all supported web routes,
  branch behavior, Finance denial, responsive widths, keyboard navigation, and
  accessibility.
- Rendered PDF/CSV inspection against expected values and layout.
- Real FCM delivery and in-app notification evidence using isolated QA
  devices.
- Startup, list scrolling, API latency/load, memory, and supported-device
  measurements.
- Secret scan, artifact inspection, signing/install verification, deployment
  migration status, rollback readiness, and final defect disposition.

No release is complete while a Blocker/Critical case is open or while a live,
device, browser, PDF, FCM, or deployment gate is represented only by static
source or automated test evidence.

### Numeric performance and quality thresholds

The NFR rows use measurable acceptance values instead of qualitative terms:

| Case | Minimum acceptance threshold |
| --- | --- |
| NFR-001 startup | First usable content ≤2s, warm start ≤1.5s, login-to-dashboard ≤3s on baseline device/browser |
| NFR-002 scrolling | ≥55 FPS for 95% of sampled frames, no normal-scroll frame >100ms, post-test memory ≤110% of baseline |
| NFR-003 service load | Read P95 ≤1s, mutation P95 ≤2s, P99 ≤5s, error rate <1%, 30-minute endurance, recovery ≤5 minutes |
| NFR-004 compatibility | 100% core smoke pass on supported device/OS matrix and zero crashes/blockers |
| NFR-005 accessibility | Zero critical/serious automated violations, keyboard/screen-reader core flow completion, ≥44dp/px targets, 200% text support |
| NFR-006 localization | Zero missing keys, zero clipping/overlap, correct locale values, readable PDF fonts |
| NFR-007 artifacts | Zero secrets, tokens, private URLs, debug endpoints, or private-record public downloads |
| NFR-008 release | 100% intended builds/install/auth smoke pass with valid package, version, signature, alignment, and backend config |
| NFR-009 deployment | Successful migrations, HTTP 200 health/readiness, 100% smoke pass, and rehearsed rollback |
| NFR-010 go/no-go | Zero open Blocker/Critical cases, 100% required evidence, and 100% route-verifier success |

## 8. Status and severity values

Use these CSV values consistently:

- `Not Run` — no execution evidence attached.
- `Passed` — expected result and required evidence verified.
- `Failed` — expected result not met; defect ID required.
- `Blocked` — environment or dependency prevented execution; blocker recorded.
- `Not Applicable` — only with a linked scope decision, never for a supported
  route that was simply inconvenient to test.

Severity:

- **Blocker:** authorization bypass, data leak, financial corruption, unusable
  release, or inability to authenticate/core workflow.
- **Critical:** major role workflow failure, duplicate/partial mutation,
  missing audit, broken deployment, or incorrect cross-role handoff.
- **High:** important workflow, validation, accessibility, performance, or
  recovery defect without immediate data/security compromise.
- **Medium/Low:** cosmetic, copy, minor usability, or non-critical edge case.

## 9. Traceability sources

- Product contract: `PRD.md`
- Route inventory: `lib/routes/schooldesk_screen_registry.dart` and
  `lib/routes/app_routes.dart`
- Client API boundaries: `lib/core/network/`
- Flutter features: `lib/features/`
- Supabase entry point and handlers:
  `supabase/functions/api/index.ts` and `supabase/functions/api/handlers/`
- Schema and RLS: `supabase/migrations/`
- Existing automated coverage: `test/`, `integration_test/`, and
  `schooldesk-web/tests/`
- Canonical executable tracker: `test_cases.csv`
- Route verification tool: `tool/verify_test_questionnaire.py`

The route and handler references in the CSV are intentionally explicit so a
tester can trace every question from screen to API/database behavior and then
attach the correct evidence type. The verifier reads the current registry,
extracts its route literals, and fails if any route is absent from the
questionnaire; it also validates the metadata schema, controlled taxonomy,
status rules, composite-case guidance, role coverage, and numeric NFR checks.
