# SchoolDesk Product Requirements

## Product Summary

SchoolDesk is a Supabase-backed school ERP for Principal, Admin, Teacher, and Parent roles. The app must show backend-backed data only, enforce role-specific access, and keep operational screens compact and usable on Android phones, tablets, and web builds.

The project is not a demo shell. Screens must avoid mock rows, local-only mutations, hidden fallback workflows, and hardcoded credentials. Empty states are allowed only when they honestly represent an empty backend response.

## Runtime Direction

- Supabase Edge Functions are the active backend.
- Supabase migrations are the active schema source.
- Alternate backend deployment files and external device-flow suites are retired from this checkout.
- Codemagic APK builds must attach to Supabase using `API_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY`.

## Roles

| Role | Responsibilities |
| --- | --- |
| Principal | Governance, approvals, timetable supervision, class/staff/student oversight, fee monitoring, reports, communications |
| Admin | Students, staff operations, attendance operations, fee operations, timetable setup, documents, account access |
| Teacher | Assigned classes, attendance, homework, communication, diary, leave, class workflow |
| Parent | Linked child dashboard, attendance, homework, notices, fees, leave, calendar, documents |

## Principal Timetable Requirements

The timetable workflow is class-first because one class teacher teaches all subjects in a class.

- Timetable home focuses on class selection.
- Class teacher is shown once and locked for the selected class.
- Period-level teacher dropdowns are removed from the primary workflow.
- Manual edit changes subject, time, room, and slot type.
- Slot types are Teaching, Break, and Free.
- Break/free slots do not require subject.
- Preview is required before publishing manual changes.
- Copy Day duplicates the selected day pattern to selected target days after confirmation.
- Teacher and room timetable views remain secondary review tools.
- Export is available from the class workspace.

## Fees Requirements

- Supabase fee structure queries must not use ambiguous PostgREST embeds between `fee_structures` and `fee_categories`.
- Fee structures must return category data in a Flutter-compatible shape.
- Supabase invoice/payment paths are the active runtime target.
- Parent payment and fee screens must fail visibly and recoverably when backend data is unavailable.

## Communications Requirement

Principal-facing "Message Oversight" is renamed to "Communications" in navigation, dashboard tiles, registry, tests, and manual checks.

## UX Requirements

- First screen after login is the role dashboard.
- Navigation is role-scoped.
- Loading, empty, error, and success states are explicit.
- Backend failures are visible and recoverable.
- Text and action controls must fit small Android screens.
- Complex workflows use full-screen or clearly scoped modal surfaces.

## Acceptance Criteria

- `flutter analyze` passes.
- `deno check supabase/functions/api/index.ts` passes.
- Flutter tests run serially by file on low-memory machines.
- No retired backend, external device-flow suite, or obsolete Markdown documentation remains in the checkout.
- Only `README.md`, `PRD.md`, and `SPECS.md` remain as Markdown documentation.
