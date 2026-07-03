# SchoolDesk Technical Specification

## Architecture

SchoolDesk currently uses:

- Flutter client under `lib/`
- Supabase Edge Function API gateway under `supabase/functions/api`
- Supabase migrations under `supabase/migrations`
- Dio-based `BackendApiClient` facade under `lib/core/network`
- Feature-first Flutter modules under `lib/features`

```text
Flutter UI -> BackendApiClient -> Supabase Edge Function -> Supabase Postgres
```

## Backend Contract

The Flutter API base URL is pinned to Supabase Edge:

```text
https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api
```

`EnvConfig.v1BaseUrlFrom` accepts:

- exact Supabase Edge function API URLs
- bare Supabase project URLs, converted to `/functions/v1/api`

Non-Supabase backend URLs fall back to the default Supabase Edge URL to avoid accidentally attaching APKs or local runs to retired backends.

## Supabase Functions

Entry point:

```text
supabase/functions/api/index.ts
```

Important handlers:

- `handlers/fees.ts`
- `handlers/timetable.ts`
- `handlers/health.ts`
- `handlers/communications.ts`
- `handlers/students.ts`
- `handlers/principal.ts`

Type check:

```bash
/home/vinay/.deno/bin/deno check supabase/functions/api/index.ts
```

## Supabase Schema Alignment

Current timetable alignment migration:

```text
supabase/migrations/0014_timetable_slot_type_alignment.sql
```

It adds `timetable_slots.slot_type` with allowed values:

- `regular`
- `teaching`
- `break`
- `free`

Break/free slots may send `subject_id: null` from Flutter.

## Fees Embed Fix

Supabase has more than one relationship between `fee_structures` and `fee_categories`. Therefore `fees.ts` must not use ambiguous PostgREST embeds like:

```text
category:fee_categories(*)
```

The handler loads fee categories separately and hydrates fee structure rows with both:

- `category`
- `fee_category`

This preserves the Flutter contract while avoiding the runtime `Could not embed because more than one relationship was found` error.

## Principal Timetable Implementation

Main file:

```text
lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart
```

Rules:

- Class is the primary object.
- Class teacher is locked.
- Manual editor updates subject, start time, end time, room, and slot type.
- Publish path previews changes first.
- Copy Day replaces target-day rows, then creates copied rows from the source day.
- Export center remains available from the class workflow.

Flutter timetable API:

```text
lib/core/network/api_modules/timetable_api.dart
```

`createTimetableSlot` and `updateTimetableSlot` send `slot_type`; empty subject IDs are sent as `null`.

## Ownership Policy Asset

The Flutter ownership matrix lives at:

```text
assets/policy/admin_principal_ownership_matrix.json
```

It is loaded by:

```text
lib/core/services/operation_ownership_policy.dart
```

## Verification

RAM-friendly verification order:

```bash
flutter analyze
/home/vinay/.deno/bin/deno check supabase/functions/api/index.ts
flutter test --no-pub --concurrency=1 test/unit/backend_target_switching_test.dart
flutter test --no-pub --concurrency=1 test/unit/timetable_management_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/timetable_csv_import_contract_test.dart
flutter test --no-pub --concurrency=1 test/unit/admin_run2_backend_contract_test.dart
```

Avoid parallel Flutter tests/builds on low-memory machines.
