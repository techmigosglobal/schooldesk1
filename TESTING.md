# Testing

## Folder Structure

- `test/unit`: pure Dart unit and contract tests.
- `test/widget`: Flutter widget and responsive UI tests.
- `test/goldens`: golden tests for stable shared UI.
- `test/support`: reusable test helpers.
- `integration_test`: Flutter integration tests against local Supabase.
- `patrol`: Patrol E2E journey tests.

## Required Local Backend

Most integration and Patrol tests expect local Supabase:

```sh
scripts/local_supabase.sh prepare
```

Implementation verification is intentionally local-only. Use
`env.local.json`, local Supabase, and local Edge Functions for API/integration
checks. GitHub/Codemagic/release builds must keep using the production
Supabase Edge backend from `env.supabase.json` or configured CI variables.

## Commands

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test --dart-define-from-file=env.local.json
patrol test --dart-define-from-file=env.local.json
scripts/verify_production_backend_config.sh
```

Use `scripts/qa_verify.sh` to run the standard local gate.

## Adding Tests

- Put pure logic tests in `test/unit`.
- Put visual/component tests in `test/widget`.
- Put device/app flow tests in `integration_test`.
- Put native-aware full journeys in `patrol`.
- Reuse helpers from `test/support` and keep test data in `supabase/seed.sql`.

## Test Data

Do not create ad hoc random test data in tests unless the test deletes it. Prefer deterministic records from `supabase/seed.sql`, or create data with stable prefixes and clean it up through APIs.

## Current Gaps

- Full screen-by-screen CRUD coverage is not complete yet.
- Student role has seed data but no Flutter student dashboard route.
- Golden tests need baseline image generation on the target CI platform.
- API tests should be expanded into a generated route matrix from Edge Function handlers.
