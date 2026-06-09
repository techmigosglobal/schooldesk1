# SchoolDesk FastAPI Backend

Independent FastAPI backend for the next SchoolDesk migration path. The current implemented slices are:

- Principal-led Goal & Task Setting ERP module.
- First-screen Flutter compatibility endpoints needed for local role smoke verification.
- DB-backed school catalog and directory foundation: school profile, academic years/terms, grades, sections, subjects, rooms, staff, and students.
- Principal approval workflow: Admin-created operational requests, Principal decisions, audit logs, notifications, and explicit non-mutating apply markers.

## Runtime Boundary

FastAPI is the runtime backend for this migration path. The Go backend is not required to run this service and is not proxied by this service. If a Flutter contract is still missing, add a native FastAPI model/service/route and verify it here instead of adding a Go gateway fallback.

## Local Run

```bash
cd schooldesk-fastapi-backend
cp .env.example .env.local
docker compose up --build
```

Expected local endpoints:

- `GET http://localhost:8090/health`
- `GET http://localhost:8090/health/db`
- `GET http://localhost:8090/health/redis`
- `GET http://localhost:8090/docs`
- `GET http://localhost:8090/api/v1/docs`

Seeded local users:

| Role | Username | Password |
| --- | --- | --- |
| Principal | `principal` | `principal123` |
| Admin | `admin` | `admin123` |
| Teacher | `teacher` | `teacher123` |
| Teacher | `teacher2` | `teacher123` |
| Parent | `parent` | `parent123` |

## Database And Redis

The backend uses SQLAlchemy models in `app/models` and Alembic migrations in `alembic/versions`.

- Local Docker uses Postgres 16 at `postgres:5432` inside the compose network and exposes it on host port `5433`.
- Local tests use isolated SQLite databases and `Base.metadata.create_all()` so the suite does not require Docker.
- Postgres runtime uses Alembic migrations as the schema authority. Run `alembic upgrade head` during deployment, or let startup apply migrations when the configured URL is PostgreSQL.
- `SCHOOLDESK_DATABASE_URL` is the preferred setting. Common `DATABASE_URL` values are also accepted, and `postgres://` / `postgresql://` URLs are normalized to `postgresql+psycopg://`.
- Redis is used as a best-effort cache and health dependency, not as the primary data store. `SCHOOLDESK_REDIS_URL` is preferred, with `REDIS_URL` accepted for deployment compatibility.
- `/health/db` verifies SQL connectivity. `/health/redis` returns `200` when Redis is connected, `200` with `redis: disabled` when `SCHOOLDESK_REDIS_HEALTH_ENABLED=false`, and `503` when Redis is required but unavailable.

## Verification

```bash
cd schooldesk-fastapi-backend
python -m pytest
```

The tests use SQLite and disable Redis health checks so they can run without Docker.

Rendered Flutter web smoke should pass against `http://localhost:8090` with no Go API running before treating a newly ported route family as verified.
