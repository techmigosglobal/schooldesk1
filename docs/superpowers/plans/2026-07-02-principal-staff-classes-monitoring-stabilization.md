# Principal Staff, Classes, Monitoring, and Stops Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the principal-role workflows that are currently failing in the Supabase API migration branch: monitoring error reporting, staff directory visibility after create, classes hub load/create stability, and the stop-directory failure path.

**Architecture:** Fix the breakages at the API contract boundary first, then add the missing resource routes the Flutter principal screens already depend on, then verify the principal workflows end to end. Treat transport/stops separately because the source shows transport is intentionally retired in one backend and partially present in testing, which makes it a scope decision rather than a pure bugfix.

**Tech Stack:** Flutter, Dio, Supabase Edge Functions (`Deno`), existing `school-backend` Go routes as behavior reference, Flutter contract tests.

---

## Scope Summary

### Confirmed from source

- Staff list parsing is broken by a response-envelope mismatch:
  `lib/core/network/api_modules/staff_api.dart`
  expects `data`, `total`, `page`, and `page_size` at the top level, while
  `supabase/functions/api/handlers/staff.ts` returns them nested inside `ok(...)`.
- The Classes Hub error is broader than class creation itself:
  `lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart`
  loads `/principal/classes`, `/academic-years`, `/staff`, `/subjects`, `/grade-subjects`, and `/staff-subjects` in one `Future.wait`, so any one failure becomes the generic “Unable to load Classes Hub from backend” error.
- `/staff-subjects` is currently not dispatched by the Supabase API gateway even though the principal classes and staff screens use it.
- Monitoring exists in the Go backend (`school-backend/internal/routes/routes.go`) but is not dispatched in the Supabase API gateway (`supabase/functions/api/index.ts`), which matches the testing note for `/monitoring/error-events`.
- Transport/stops are intentionally not exposed in the Go backend right now, so a failing “All Stop Directory” screen likely means the UI or testing build is still pointing at an unsupported module.

### Recommended execution order

1. Monitoring route parity.
2. Staff directory contract fix.
3. Missing `staff-subjects` CRUD and classes-hub dependency repair.
4. Principal workflow verification for create staff and create class.
5. Transport/stops decision and either guard or restore.

---

### Task 1: Restore Monitoring API Handler Wiring

**Files:**
- Modify: `supabase/functions/api/index.ts`
- Create: `supabase/functions/api/handlers/monitoring.ts`
- Test: `test/unit/monitoring_error_reporting_contract_test.dart`

- [ ] **Step 1: Add a failing source-level contract check for Supabase routing**

Update the monitoring contract test so it asserts both:
- `index.ts` dispatches `path.startsWith("/monitoring")`
- `handlers/monitoring.ts` exists and exposes the error-event methods

Run:
```bash
flutter test test/unit/monitoring_error_reporting_contract_test.dart
```

Expected:
```text
FAIL because Supabase index.ts does not route /monitoring yet
```

- [ ] **Step 2: Implement the Supabase monitoring handler**

Build `supabase/functions/api/handlers/monitoring.ts` with:
- `POST /monitoring/error-events`
- `GET /monitoring/error-events`
- `GET /monitoring/error-events/:id`
- `PATCH /monitoring/error-events/:id/resolve`

Use the existing Flutter contract as the API shape source and the Go backend behavior as the role/route reference.

- [ ] **Step 3: Register the handler in the API gateway**

Patch `supabase/functions/api/index.ts` to:
- import `handleMonitoring`
- dispatch `path.startsWith("/monitoring")`

- [ ] **Step 4: Re-run the focused contract**

Run:
```bash
flutter test test/unit/monitoring_error_reporting_contract_test.dart
```

Expected:
```text
PASS
```

---

### Task 2: Fix Staff Directory Visibility After Staff Creation

**Files:**
- Modify: `supabase/functions/api/handlers/staff.ts`
- Modify: `lib/core/network/api_modules/staff_api.dart` only if needed for compatibility hardening
- Test: `test/unit/supabase_people_contract_test.dart`
- Test: `test/unit/staff_management_backend_wiring_test.dart`

- [ ] **Step 1: Lock the expected pagination contract in tests**

Add a focused test for `staff.ts` requiring the response shape that Flutter consumes:
- top-level `success`
- top-level `data` list
- top-level `total`
- top-level `page`
- top-level `page_size`

Run:
```bash
flutter test test/unit/supabase_people_contract_test.dart
```

Expected:
```text
FAIL until staff list response shape matches Flutter
```

- [ ] **Step 2: Flatten the staff list response**

Change `supabase/functions/api/handlers/staff.ts` list handling so the response shape matches what `getStaff()` already parses in `lib/core/network/api_modules/staff_api.dart`.

Important:
- do not change single-item `GET /staff/:id`
- do not break create/update/delete responses
- keep count and paging deterministic

- [ ] **Step 3: Add client-side defensive parsing**

If we want this migration branch to be more resilient, update `getStaff()` to accept both:
- current expected top-level pagination fields
- nested legacy fields inside `data`

This is optional but recommended during migration because it prevents one response-shape drift from blanking the staff directory again.

- [ ] **Step 4: Verify the staff screen flow**

Run:
```bash
flutter test test/unit/supabase_people_contract_test.dart
flutter test test/unit/staff_management_backend_wiring_test.dart
```

Expected:
```text
PASS
```

---

### Task 3: Implement Missing `staff-subjects` Resource Support

**Files:**
- Modify: `supabase/functions/api/index.ts`
- Modify: `supabase/functions/api/handlers/academics.ts` or create `supabase/functions/api/handlers/staff_subjects.ts`
- Test: `test/unit/supabase_people_contract_test.dart`
- Test: add `test/unit/principal_classes_supabase_contract_test.dart`

- [ ] **Step 1: Add a failing contract for `staff-subjects`**

Write a focused source-level contract asserting:
- API gateway dispatches `/staff-subjects`
- list/create/delete support exists
- query filters at minimum support `staff_id`, `grade_id`, and `section_id`

Run:
```bash
flutter test test/unit/supabase_people_contract_test.dart
```

Expected:
```text
FAIL because /staff-subjects is not routed today
```

- [ ] **Step 2: Implement `staff-subjects` list/create/update/delete**

The implementation must satisfy both callers:
- `lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart`
- `lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart`

Required behaviors:
- school-scoped reads/writes
- list by `staff_id`
- optional `grade_id`
- optional `section_id`
- safe delete by row id

- [ ] **Step 3: Wire the route into `index.ts`**

Dispatch `/staff-subjects` to the handler so raw CRUD calls stop falling through to `notFound`.

- [ ] **Step 4: Verify save paths that depend on it**

The following existing code paths must be re-verified:
- staff assignment sync in `staff_management_screen.dart`
- class subject-teacher assignment load in `principal_classes_screen.dart`

Run:
```bash
flutter test test/unit/supabase_people_contract_test.dart
flutter test test/unit/staff_management_backend_wiring_test.dart
```

Expected:
```text
PASS
```

---

### Task 4: Stabilize Principal Classes Hub Load and Create Workflow

**Files:**
- Modify: `supabase/functions/api/handlers/principal.ts`
- Modify: `supabase/functions/api/handlers/academics.ts`
- Modify: `lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart` only for error clarity or defensive handling
- Test: create `test/unit/principal_classes_supabase_contract_test.dart`
- Optional verify script: `cmd/local-api-verify` equivalent for Supabase branch if available

- [ ] **Step 1: Add a targeted contract for the load dependencies**

The test should assert the Classes Hub still depends on:
- `/principal/classes`
- `/academic-years`
- `/staff`
- `/subjects`
- `/grade-subjects`
- `/staff-subjects`

It should also assert that one dependency failure currently surfaces as the generic “Unable to load Classes Hub from backend” message so we preserve awareness of the coupling.

- [ ] **Step 2: Validate principal class payloads against Supabase schema**

Audit `supabase/functions/api/handlers/principal.ts` and confirm that:
- `academic_year_id`
- `grade_id`
- `section_name`
- `class_teacher_id`
- `co_teacher_id`
- fee item fields
- subject mapping ids

all match the actual table column types and nullable behavior.

This is the place to investigate the tester-reported `400 invalid input syntax` error. The likely failure is not the section row itself but one of the dependent mapping writes.

- [ ] **Step 3: Add guardrails around UUID-like foreign keys**

Before writes in class create/update flows:
- trim empty strings to `null`
- do not pass placeholder labels into `*_id` columns
- validate arrays such as `deleted_*_ids` and subject-mapping ids before `.eq()` or `.in()`

This is the highest-probability fix for “invalid input syntax” failures during class create/update on a Supabase-backed path.

- [ ] **Step 4: Improve the top-level error clarity**

If the UI stays as one `Future.wait`, change the catch path so the message tells us which dependency failed, for example:
- classes
- staff directory
- subject mappings
- teacher assignments

That keeps future debugging cheap and prevents every dependency issue from looking like a class-create bug.

- [ ] **Step 5: Re-run focused verification**

Run:
```bash
flutter test test/unit/principal_classes_supabase_contract_test.dart
flutter test test/unit/principal_screen_ui_regression_test.dart
```

Expected:
```text
PASS
```

---

### Task 5: Resolve the Stop Directory Failure Properly

**Files:**
- Investigate current Flutter route/screen if still exposed
- Modify relevant Supabase handler(s) if transport is in scope
- Modify route registry / navigation if transport is out of scope
- Test: add `test/unit/transport_scope_contract_test.dart`

- [ ] **Step 1: Confirm product scope from source before coding**

The current source says transport is intentionally not exposed:
- `school-backend/internal/routes/routes.go`

So first confirm whether the business decision is:
- restore transport/stops in the current release, or
- remove/guard any remaining stop-directory UI in the current release

- [ ] **Step 2: If transport is out of scope, close the bug by removing the entry path**

Implementation target:
- no principal-accessible stop-directory route
- no failing API call for stops
- a contract test proving transport is retired in this release

- [ ] **Step 3: If transport is in scope, treat it as a restoration task**

Minimum implementation:
- route dispatch for stops
- list/create/update/delete stop records
- serialization that always returns `Map<String, dynamic>` rows, not mixed list/string payloads
- Flutter parsing hardened with `_asMap`/`_asListMap` style helpers before cast

Note:
- the tester-reported `type 'String' is not a subtype of type 'Map<String, dynamic>' or 'List<dynamic>'` strongly suggests inconsistent response shape, not only missing data

- [ ] **Step 4: Add a focused transport contract test**

Run one of:
```bash
flutter test test/unit/transport_scope_contract_test.dart
```

Expected:
```text
PASS for either "retired and guarded" or "restored and typed" behavior
```

---

### Task 6: End-to-End Principal Verification

**Files:**
- No new product files required
- Tests: focused Flutter contracts
- Optional runtime verification on local Supabase stack if available

- [ ] **Step 1: Verify principal academic year flow still works**

Run:
```bash
flutter test test/unit/principal_screen_ui_regression_test.dart
```

Expected:
```text
PASS with no academic-year regression
```

- [ ] **Step 2: Verify staff creation then staff-directory visibility**

Manual or scripted acceptance:
- create staff as principal
- confirm success response
- reopen or refresh All Staff Directory
- confirm created staff row is listed

- [ ] **Step 3: Verify class creation then classes-hub visibility**

Manual or scripted acceptance:
- create class with valid academic year
- confirm class row, subject setup, and teacher setup load without generic hub failure

- [ ] **Step 4: Verify monitoring path**

Acceptance:
- submit an error event
- list as principal
- resolve it

- [ ] **Step 5: Record remaining gaps honestly**

If transport/stops remains intentionally retired, document that as product scope, not as an unfixed silent defect.

---

## Risks To Watch

- Staff fixes can appear complete while staff-subject assignment still fails because `/staff-subjects` is a separate missing route.
- Classes Hub can keep throwing the same generic message even after class creation is fixed if any one dependency in its `Future.wait` still breaks.
- Transport/stops should not be “half-restored.” Either guard the UI cleanly or restore the backend contract fully.
- Do not change unrelated existing dirty files in this checkout unless they are directly needed for these fixes.

## Suggested Verification Commands

```bash
flutter test test/unit/monitoring_error_reporting_contract_test.dart
flutter test test/unit/supabase_people_contract_test.dart
flutter test test/unit/staff_management_backend_wiring_test.dart
flutter test test/unit/principal_screen_ui_regression_test.dart
flutter test test/unit/principal_classes_supabase_contract_test.dart
flutter test test/unit/transport_scope_contract_test.dart
```

## Recommended First Execution Slice

1. Monitoring route wiring
2. Staff pagination contract
3. `staff-subjects` route support
4. Classes Hub verification

That sequence should remove the highest-confidence principal failures first and will likely also explain most of the tester-reported class issues.
