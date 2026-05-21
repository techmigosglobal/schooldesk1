# Hostinger Docker Compose Deployment SOP

Use this SOP for repeatable SchoolDesk backend deployments from the local
checkout to the Hostinger VPS.

## Production Target

| Item | Value |
| --- | --- |
| VPS SSH | `root@187.127.157.43` |
| SSH key | `~/.ssh/schooldesk_hostinger_vps` |
| Host fingerprint | `SHA256:ZqqHqq502eUL+j3N5ccdlfVD7nxPUBkGchftOj40atA` |
| Remote root | `/opt/schooldesk_V1` |
| Compose file | `docker-compose.hostinger-traefik.yml` |
| API service | `go-api` / `schooldesk-go-api` |
| Health URL | `https://schooldesk-api.187.127.157.43.nip.io/health` |
| API base URL | `https://schooldesk-api.187.127.157.43.nip.io/api` |

## One-Time Local Setup

```bash
cp deploy/hostinger-deploy.env.example deploy/hostinger-deploy.env
chmod +x scripts/deploy-hostinger-backend.sh
```

Do not put production passwords in `deploy/hostinger-deploy.env`. For optional
login smoke testing, export the password only in the current shell:

```bash
export HOSTINGER_SMOKE_LOGIN_USERNAME=principal
export HOSTINGER_SMOKE_LOGIN_PASSWORD='<set-in-current-shell>'
```

## Deployment Sequence

### 1. Verify The VPS Without Changing It

```bash
scripts/deploy-hostinger-backend.sh --check-only
```

This confirms:

- SSH host fingerprint matches the expected Hostinger server.
- SSH login works.
- Docker Compose is present.
- `/opt/schooldesk_V1/.env` and compose file exist.
- Current containers are visible.
- Public health endpoint returns HTTP 200.
- Optional login smoke passes when credentials are exported.

### 2. Run A Safe Dry Run

```bash
scripts/deploy-hostinger-backend.sh --dry-run
```

This runs local backend tests and shows the exact `rsync` file changes without
modifying the VPS.

### 3. Deploy Code-Only Backend Changes

Use this for handler, service, validation, RBAC, or bug-fix changes that do not
need schema migration.

```bash
scripts/deploy-hostinger-backend.sh --execute --yes
```

The script will:

- Run `go test ./...` in `school-backend`.
- Verify remote Docker Compose state.
- Create a remote backup under `/root/schooldesk-backups/deploy-<timestamp>`.
- Sync only `school-backend/` source with safe excludes.
- Rebuild/restart only the `go-api` service.
- Verify public health.
- Run optional login smoke.

### 4. Deploy Backend Changes That Need Migration

Use this when models or migrations changed, for example a new DB column.

```bash
scripts/deploy-hostinger-backend.sh --execute --migrate --yes
```

The script temporarily sets:

```text
MIGRATE_ON_START=true
```

For relationship constraint deployments, also set this only after local Docker
verification and a fresh Postgres backup:

```text
ENABLE_RELATIONSHIP_CONSTRAINTS=true
```

Then after health verification it sets:

```text
MIGRATE_ON_START=false
```

and recreates the API container without rebuilding. Steady-state production
should always finish with `MIGRATE_ON_START=false`.
The relationship constraint flag can return to `false` after the idempotent
constraints are installed and role smoke tests pass.

## Backup Contents

Each successful execute run creates:

```text
/root/schooldesk-backups/deploy-<timestamp>/
```

with:

- `docker-compose-ps.txt`
- `docker-ps.txt`
- `docker-compose.hostinger-traefik.yml`
- `env.backup`
- `postgres.sql`
- `school-backend-source.tgz`

## Rollback Outline

Rollback is manual by design.

1. SSH to the VPS.
2. Pick the backup folder from `/root/schooldesk-backups`.
3. Restore source:

```bash
cd /opt/schooldesk_V1
rm -rf school-backend
tar -xzf /root/schooldesk-backups/deploy-<timestamp>/school-backend-source.tgz
```

4. Restore DB only if the issue is data/schema related and you accept losing
   writes after the backup timestamp:

```bash
docker compose -f docker-compose.hostinger-traefik.yml stop go-api
docker exec -i schooldesk-postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < /root/schooldesk-backups/deploy-<timestamp>/postgres.sql
```

5. Rebuild API:

```bash
docker compose -f docker-compose.hostinger-traefik.yml up -d --build go-api
curl -fsS https://schooldesk-api.187.127.157.43.nip.io/health
```

## Rules For Future Deployments

- Start with `--check-only`.
- Run `--dry-run` before every `--execute`.
- Use `--migrate` only when schema changes are intentionally part of the deploy.
- Never leave production with `MIGRATE_ON_START=true`.
- Never sync the whole repository to the VPS; sync only `school-backend/`.
- Never commit `deploy/hostinger-deploy.env` or any password-bearing file.
- If SSH host fingerprint changes, stop and confirm the VPS identity from
  Hostinger before updating `known_hosts`.
