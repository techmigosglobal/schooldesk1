# SchoolDesk GitHub CI/CD Runbook

This runbook activates the root monorepo workflow for Android Play Internal
Closed testing uploads and Hostinger VPS backend deployment.

## Workflows

- `CI`: runs on pull requests and pushes to `main`/`master`.
- `Local Docker CI Reusable`: shared Flutter, Go, Compose, and local Docker API
  verification gate used by CI and release.
- `Release Android AAB and VPS`: runs only from manual dispatch or
  `schooldesk-v*` tags.

## Root Monorepo Activation

This workspace root currently owns the GitHub workflow files, while the
`school-backend/` folder may still have its own nested Git repository. Before
the first GitHub release, make the root folder the repository that is connected
to GitHub and preserve the existing backend history separately. The deploy
workflow expects `school-backend/` to be regular source code inside the root
repository, not an external submodule.

## GitHub Environments

Create these environments before the first release:

- `play-closed-testing`
- `hostinger-production`

Required `play-closed-testing` secrets:

- `ANDROID_KEYSTORE_BASE64`: base64 of the upload keystore JKS.
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `SCHOOLDESK_HOSTINGER_ENV_JSON`: production Flutter env JSON, including the
  HTTPS Hostinger `API_BASE_URL`.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Google Play Android Publisher service
  account JSON with access to `com.techmigos.schooldesk1`.

## Google Play Access Setup

The workflow does not receive Play Store access automatically. It uploads only
through `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`.

1. In Google Play Console, open API access and link or create a Google Cloud
   project.
2. Create a service account and download its JSON key.
3. In Play Console, grant that service account access to the SchoolDesk app
   package `com.techmigos.schooldesk1`.
4. Give the service account release-management permission for this app. Prefer
   app-scoped access instead of full developer-account access.
5. Store the entire JSON key as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` in the
   `play-closed-testing` GitHub Environment.

The first automated release should keep `play_track=alpha` unless your Play
Console Closed testing page shows a custom track name. If it does, use that
exact track name for `play_track`. Production promotion remains a manual Play
Console decision after verification.

Required `hostinger-production` secrets:

- `HOSTINGER_SSH_PRIVATE_KEY`
- `HOSTINGER_SSH_HOST`
- `HOSTINGER_SSH_USER`
- `HOSTINGER_EXPECTED_ED25519_SHA256`
- `HOSTINGER_REMOTE_ROOT`
- `HOSTINGER_API_HEALTH_URL`
- `HOSTINGER_API_LOGIN_URL`

Optional `hostinger-production` secrets:

- `HOSTINGER_COMPOSE_FILE`
- `HOSTINGER_COMPOSE_SERVICE`
- `HOSTINGER_COMPOSE_EXTRA_SERVICES`
- `HOSTINGER_COMPOSE_PROFILES`
- `HOSTINGER_BACKUP_ROOT`
- `HOSTINGER_SMOKE_LOGIN_USERNAME`
- `HOSTINGER_SMOKE_LOGIN_PASSWORD`

## Release Flow

1. Bump `pubspec.yaml` to a versionCode greater than the current Google Play
   release.
2. Push to `main` and confirm the `CI` workflow passes.
3. Start `Release Android AAB and VPS` manually or push a tag such as
   `schooldesk-v1.0.6-14`.
4. Keep `play_track=alpha` for the first automated release to Closed testing.
5. Set `run_migrations=true` only when the backend change needs the one-time
   `MIGRATE_ON_START=true` deployment path.
6. Review the GitHub summary and artifacts before promoting the Play release.

The release workflow records AAB metadata, checksum, signing output, Play track,
VPS deploy logs, health/readiness/metrics responses, and the remote backup path.

## Rollback

The VPS deploy script creates a backup under `HOSTINGER_BACKUP_ROOT` before it
syncs source or restarts containers. Use the backup path from the workflow
summary or `deploy-execute.log`, then restore the saved compose/env/source files
on the VPS and rebuild `go-api`.

Do not promote the Play release beyond Closed testing until the VPS health,
readiness, metrics, and role-login smoke checks are green.
