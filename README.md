# SchoolDesk Flutter

SchoolDesk is a Flutter school management app for Principal, Admin, Teacher, and Parent roles.

The current runtime target is Supabase:

- API base URL: `https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api`
- Supabase project URL: `https://ouvwogguttybmpgfgctc.supabase.co`
- Backend implementation: Supabase Edge Functions under `supabase/functions/api`
- Schema changes: Supabase migrations under `supabase/migrations`

The retired backend and mobile-flow automation folders have been removed from this checkout. Do not add alternate backend deployment files or external device-flow suites back into this project unless the runtime target changes intentionally.

## Setup

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Plain `flutter run` attaches to the Supabase Edge backend by default. Release/debug builds should pass the same Supabase values through `--dart-define` or Codemagic variables.

## Codemagic APK

`codemagic.yaml` builds Android debug APKs with:

- `API_BASE_URL=https://ouvwogguttybmpgfgctc.supabase.co/functions/v1/api`
- `SUPABASE_URL=https://ouvwogguttybmpgfgctc.supabase.co`
- `SUPABASE_ANON_KEY`
- `APP_ENV=production`
- `ENABLE_LOGGING=false`

## Project Structure

```text
android/                  Android project
ios/                      iOS project
lib/                      Flutter app source
assets/                   Bundled images, fonts, branding, policy assets
supabase/functions/api/   Supabase Edge Function API gateway and handlers
supabase/migrations/      Supabase database migrations
test/                     Flutter source and contract tests
```

## Verification

Use RAM-friendly serial checks:

```bash
flutter analyze
/home/vinay/.deno/bin/deno check supabase/functions/api/index.ts
flutter test --no-pub --concurrency=1 <test-file>
```

Do not run multiple Flutter test/build commands in parallel on low-memory machines.

## Documentation

Only these Markdown files are retained:

- `README.md`
- `PRD.md`
- `SPECS.md`
