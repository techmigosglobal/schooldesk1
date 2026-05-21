# SchoolDesk Coolify Deployment

This repo can be deployed from GitHub to a Hostinger VPS running Coolify with `docker-compose.coolify.yml`.

## What Persists

- PostgreSQL data persists in the Docker named volume `schooldesk_postgres_data`.
- Redis session/cache/job data persists in `schooldesk_redis_data` with Redis AOF enabled.
- The backend is forced to use Postgres in production via `USE_POSTGRES_ONLY=true`; it will not silently fall back to SQLite.
- Flutter web is built with `API_BASE_URL` at image build time, so the frontend talks to the deployed API domain.

Do not delete these volumes unless you intentionally want to wipe production data.

## GitHub Checklist

- Commit `web/`, `school-backend/`, `pubspec.lock`, `Dockerfile.web`, `docker-compose.coolify.yml`, and `deploy/`.
- Do not commit `.env`, `env.json`, `*.db`, `*.sqlite`, `school-backend/school.db`, or the compiled `school-backend/school-backend` binary.
- Push the full repository to GitHub, then connect that repository in Coolify.

## Coolify Project Setup

1. Create a new Coolify resource from the GitHub repository.
2. Select Docker Compose deployment.
3. Set the compose file path to `docker-compose.coolify.yml`.
4. Create domains:
   - `web` service: `https://yourdomain.com`
   - `api` service: `https://api.yourdomain.com`
5. In Coolify, set the API service public port to `8080` if it asks for the container port.

## Required Environment Variables

Set these in Coolify before the first deploy:

```env
API_BASE_URL=https://api.yourdomain.com/api/v1
ALLOWED_ORIGINS=https://yourdomain.com
JWT_SECRET=generate_a_random_secret_at_least_32_characters
POSTGRES_DB=schooldesk
POSTGRES_USER=schooldesk
POSTGRES_PASSWORD=generate_a_strong_database_password
REDIS_PASSWORD=generate_a_strong_redis_password
BOOTSTRAP_PRINCIPAL_EMAIL=principal@yourdomain.com
BOOTSTRAP_PRINCIPAL_PASSWORD=generate_a_strong_initial_password
MIGRATE_ON_START=true
DISABLE_PUBLIC_REGISTRATION=true
ENABLE_LOGGING=false
```

After the first successful deploy and login, you may set `MIGRATE_ON_START=false` for stricter production startup. Keeping it `true` is acceptable for early releases because GORM `AutoMigrate` is idempotent for the current schema, but schema changes should eventually move to explicit migrations.

## First Login

On an empty database, the backend creates one Principal user:

- Username: `PRINC`
- Email: the value of `BOOTSTRAP_PRINCIPAL_EMAIL`
- Password: the value of `BOOTSTRAP_PRINCIPAL_PASSWORD`

Change this password from the application as soon as user-management/password-change UX is available. Until then, keep the Coolify environment value secret.

## Verification

Run these after deployment:

```bash
curl -fsS https://api.yourdomain.com/health
curl -fsS https://api.yourdomain.com/
```

Then open `https://yourdomain.com`, log in through the Principal portal, create a test school record/domain object, redeploy, and verify the record still exists. Persistence is correct only if data survives redeploys and container restarts.

## Backup Notes

Configure Hostinger/Coolify backups for the Docker volumes, especially `schooldesk_postgres_data`. For manual backups from the VPS, use `pg_dump` against the Postgres container or Coolify's database backup tooling. Redis is important for sessions and queues, but Postgres is the system of record.
