# SchoolDesk Hostinger App Usage Guide

## Backend

- API base URL: `https://schooldesk-api.187.127.157.43.nip.io/api`
- Health check: `https://schooldesk-api.187.127.157.43.nip.io/health`
- Hostinger VPS template: Ubuntu 24.04 with Docker and Traefik

The API is deployed as Docker services:

- `schooldesk-go-api`
- `schooldesk-postgres`
- `schooldesk-redis`

Postgres and Redis are private Docker services. Public traffic reaches the Go
API through Traefik HTTPS routing.

## Android Build

Build the Android App Bundle with:

```bash
flutter build appbundle --release --dart-define-from-file=env.hostinger.json
```

The `env.hostinger.json` file is intentionally ignored by Git. Change only the
`API_BASE_URL` value when moving from the temporary `nip.io` host to the final
school API domain.

## Login

Use the QA credentials generated for this deployment. They are stored outside
the repository at:

```text
/tmp/schooldesk-hostinger-qa-credentials.md
```

Do not commit real passwords to docs or source files.

## First Use Flow

1. Install the AAB through Play Console internal testing or convert/test through
   your normal Android release workflow.
2. Open the app.
3. Tap `Login`.
4. Sign in with the Principal account first.
5. Confirm Dashboard, School Profile, Access & Permissions, Student Oversight,
   Fees, Communication, and Reports load from the hosted backend.
6. Sign out and verify Admin, Teacher, and Parent accounts.

The Parent QA account is linked to seeded admission number `ADM2025001`.

## Production Domain Cutover

Before publishing outside QA, point a real domain such as
`api.yourschool.com` to `187.127.157.43`, update both:

- Hostinger `/opt/schooldesk_V1/.env`: `API_HOST=api.yourschool.com`
- Flutter `env.hostinger.json`: `API_BASE_URL=https://api.yourschool.com/api`

Then recreate the API container and rebuild the AAB.
