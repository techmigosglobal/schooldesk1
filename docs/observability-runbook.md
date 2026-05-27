# SchoolDesk Observability Runbook

SchoolDesk exposes Prometheus-format backend metrics at `/metrics`. The
optional observability overlay starts Prometheus and Grafana without changing the
normal API/Postgres/Redis compose stack.

## Local Start

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml --profile observability up -d
```

Default URLs:

- API metrics: `http://127.0.0.1:8080/metrics`
- Prometheus: `http://127.0.0.1:9090`
- Grafana: `http://127.0.0.1:3000`

Default Grafana login is `admin` / `schooldesk-admin`. For any shared or VPS
environment, set `GRAFANA_ADMIN_PASSWORD` before starting the stack.

```bash
GRAFANA_ADMIN_PASSWORD='replace_with_a_strong_password' \
docker compose -f docker-compose.yml -f docker-compose.observability.yml --profile observability up -d
```

## VPS / Hostinger Start

Keep Prometheus and Grafana bound to localhost unless a reverse proxy with auth
is deliberately configured.

```bash
SCHOOLDESK_ENV_FILE=.env \
GRAFANA_ADMIN_PASSWORD='replace_with_a_strong_password' \
docker compose -f docker-compose.hostinger-traefik.yml -f docker-compose.observability.yml --profile observability up -d
```

Open the tools through an SSH tunnel:

```bash
ssh -L 3000:127.0.0.1:3000 -L 9090:127.0.0.1:9090 root@your-vps-host
```

Then use `http://127.0.0.1:3000` for Grafana and
`http://127.0.0.1:9090` for Prometheus from your local browser.

## Verification

```bash
scripts/verify-observability.sh
```

Manual checks:

```bash
curl -fsS http://127.0.0.1:8080/metrics | rg 'schooldesk_backend_up|schooldesk_http_requests_total'
curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS --get http://127.0.0.1:9090/api/v1/query --data-urlencode 'query=up{job="schooldesk-go-api"}'
```

## What Is Collected

- Backend, database, and Redis up gauges
- HTTP request counts, latency summaries, and 4xx/5xx counters
- Database pool open/in-use/idle connections and wait counters
- Redis-backed queue availability and pending job length
- Notification worker failure counter

Grafana provisions the `SchoolDesk API Overview` dashboard automatically from
`monitoring/grafana/dashboards/schooldesk-api-overview.json`.
