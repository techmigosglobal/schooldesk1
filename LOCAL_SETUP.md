# Local Setup

## Prerequisites

- Flutter SDK and Dart SDK
- Docker Desktop or Docker Engine
- Supabase CLI
- Deno, required by `supabase functions serve`
- Patrol CLI for Patrol tests
Install examples:

```sh
npm install -g supabase
dart pub global activate patrol_cli
```

## Environment

Create `env.local.json` from `env.local.example.json` or run:

```sh
cp env.local.example.json env.local.json
```

The local defaults are:

- Supabase URL: `http://127.0.0.1:54321`
- API base URL: `http://127.0.0.1:54321/functions/v1/api`
- Principal: `principal` / `Principal@12345`
- Admin: `admin` / `Admin@12345`
- Teacher: `teacher` / `Teacher@12345`
- Parent: `parent` / `Parent@12345`
- Student: `student` / `Student@12345`

## Commands

```sh
scripts/local_supabase.sh prepare
scripts/local_supabase.sh start
scripts/local_supabase.sh reset
scripts/local_supabase.sh functions
scripts/local_supabase.sh stop
```

`prepare` starts Supabase, resets the database, applies deterministic seed data, and prints the Flutter command to use.

Run the app locally:

```sh
flutter run --dart-define-from-file=env.local.json
```

This repo's implementation verification workflow is local-only: use local
Supabase, local Edge Functions, integration tests, and Patrol before pushing.
Do not build APKs as part of normal implementation verification in this repo.
Release builders and teammates who build APKs should use `env.supabase.json`
from `env.supabase.example.json` or the Codemagic production variables.

Run tests:

```sh
flutter test
flutter test integration_test --dart-define-from-file=env.local.json
patrol test --dart-define-from-file=env.local.json
```

Run the verification gate:

```sh
scripts/qa_verify.sh
scripts/verify_production_backend_config.sh
```

## Reset Database

```sh
scripts/local_supabase.sh reset
```

This runs `supabase db reset`, applies migrations, and loads `supabase/seed.sql`.

## Storage

The local migration creates a public `school-assets` bucket used by profile avatars, school logos, staff/student documents, event posts, and payment proof uploads.

## Debugging

- If `supabase` is missing, install Supabase CLI and retry.
- If local Supabase fails to start, verify Docker is running.
- If Edge Functions fail, verify Deno is installed.
- If login fails after reset, confirm `supabase/seed.sql` ran and the auth users exist.
- If the app calls production, confirm `env.local.json` is passed to Flutter and `APP_ENV` is `local`.
