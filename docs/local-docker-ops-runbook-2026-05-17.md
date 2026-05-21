# SchoolDesk Local Docker Ops Runbook

Date: 2026-05-17  
Scope: Local Docker backend only. Do not run Hostinger deployment commands from this runbook.

## Start And Verify

```bash
docker compose up -d postgres redis go-api
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/ready
curl -fsS http://127.0.0.1:8080/metrics
scripts/verify-local-docker-api.sh
```

## Standard Quality Gate

```bash
flutter analyze
flutter test
(cd school-backend && go test ./...)
scripts/verify-local-docker-api.sh
```

## Failed Request Triage

1. Capture the `X-Request-ID` response header or `request_id` from the JSON error body.
2. Inspect local API logs:

```bash
docker logs --tail=300 schooldesk-go-api | rg '<request_id>|http_request|ERROR|panic'
```

3. Confirm dependency health:

```bash
docker compose ps
docker compose exec -T redis redis-cli ping
set -a; source .env; set +a
docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

## Backup Smoke

```bash
set -a; source .env; set +a
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" >/tmp/schooldesk-backup-smoke.sql
test -s /tmp/schooldesk-backup-smoke.sql
```

## Export Artifact Check

```bash
find school-backend/uploads/exports -maxdepth 3 -type f 2>/dev/null | sort | tail
```

Report/export records should contain `status`, `artifact_path`, and `download_url`. Keep cleanup manual locally until the VPS retention policy is approved.

## Rollback Locally

```bash
docker compose down
git diff --name-only
```

This repo is not currently a git checkout in this workspace, so rollback is a file-level/manual operation here. Do not delete Docker volumes unless you intentionally want to reset local data.
