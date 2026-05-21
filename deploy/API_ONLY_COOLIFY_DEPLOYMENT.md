# SchoolDesk API-Only Coolify Deployment

This deployment runs only the backend platform services:

- Go API: `school-backend`
- PostgreSQL: system of record
- Redis: cache, rate limit, sessions, and background job primitives

Flutter web and any frontend build are intentionally out of scope for this
API-only stack.

## Compose File

Use:

```bash
docker-compose.api.coolify.yml
```

When deploying directly over SSH on a VPS that already runs the Coolify proxy,
also include:

```bash
docker-compose.api.coolify-proxy.yml
```

Set `API_HOST` to the public API hostname. The override connects only the `api`
container to Coolify's external `coolify` Docker network and adds Traefik labels.

Services:

- `api` exposes container port `8080`
- `postgres` stores data in `schooldesk_postgres_data`
- `redis` stores append-only data in `schooldesk_redis_data`

## Required Coolify Environment Variables

Set these in Coolify as application environment variables:

```env
ALLOWED_ORIGINS=https://your-frontend-domain.example
JWT_SECRET=replace_with_a_random_secret_at_least_32_characters
POSTGRES_DB=schooldesk
POSTGRES_USER=schooldesk
POSTGRES_PASSWORD=replace_with_a_strong_postgres_password
REDIS_PASSWORD=replace_with_a_strong_redis_password
MIGRATE_ON_START=true
SEED_ON_START=false
DISABLE_PUBLIC_REGISTRATION=true
API_HOST=api.yourdomain.example
```

The compose file derives:

```env
DATABASE_URL=postgres://POSTGRES_USER:POSTGRES_PASSWORD@postgres:5432/POSTGRES_DB?sslmode=disable
REDIS_URL=redis://:REDIS_PASSWORD@redis:6379/0
```

Do not commit real secrets, `.env`, SQLite databases, binaries, or test reports.

## First Deploy

Use `MIGRATE_ON_START=true` on the first deploy so the Go API creates the
PostgreSQL schema. Keep `SEED_ON_START=false` for an empty production backend.

After the first successful deploy and schema verification, change:

```env
MIGRATE_ON_START=false
```

This keeps steady-state production startup strict while preserving the database
volume across redeploys.

## Verification

From the VPS:

```bash
docker ps
curl -fsS http://127.0.0.1:8080/health
```

From the public route configured in Coolify:

```bash
curl -fsS https://your-api-domain.example/health
curl -fsS https://your-api-domain.example/
```

PostgreSQL verification:

```bash
docker exec -i <postgres-container> psql -U schooldesk -d schooldesk -At <<'SQL'
select count(*) from information_schema.tables where table_schema = 'public';
select table_name from information_schema.tables where table_schema = 'public' order by table_name limit 20;
SQL
```

Redis verification:

```bash
docker exec <redis-container> redis-cli -a "$REDIS_PASSWORD" ping
```

## Reuse Contract For Future Apps

This stack is reusable as a backend template when a future app follows these
rules:

- The app API reads configuration only from environment variables.
- PostgreSQL remains the durable source of truth.
- Redis is used only for replaceable runtime state: cache, sessions, rate
  limits, and queues.
- App-specific routes, models, and migrations live inside the Go API source.
- Compose owns infrastructure wiring only; it does not encode app roles, seed
  users, or domain business data.

SchoolDesk is the first app implemented on top of this pattern.
