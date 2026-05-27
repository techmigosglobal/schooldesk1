#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_HEALTH_URL="${API_HEALTH_URL:-http://127.0.0.1:8080/health}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://127.0.0.1:${PROMETHEUS_PORT:-9090}}"
GRAFANA_URL="${GRAFANA_URL:-http://127.0.0.1:${GRAFANA_PORT:-3000}}"
OBS_ATTEMPTS="${OBS_ATTEMPTS:-90}"

case "$API_HEALTH_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Refusing non-local API_HEALTH_URL=$API_HEALTH_URL" >&2
    exit 64
    ;;
esac

case "$PROMETHEUS_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Refusing non-local PROMETHEUS_URL=$PROMETHEUS_URL" >&2
    exit 64
    ;;
esac

case "$GRAFANA_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Refusing non-local GRAFANA_URL=$GRAFANA_URL" >&2
    exit 64
    ;;
esac

cd "$ROOT_DIR"

compose() {
  docker compose -f docker-compose.yml -f docker-compose.observability.yml --profile observability "$@"
}

wait_for_url() {
  local url="$1"
  local label="$2"
  for _ in $(seq 1 "$OBS_ATTEMPTS"); do
    if curl -fsS "$url" >/dev/null 2>/dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "$label did not become ready: $url" >&2
  compose ps >&2 || true
  compose logs --tail=160 go-api prometheus grafana >&2 || true
  exit 1
}

compose config >/tmp/schooldesk-observability-compose.yaml
compose up -d postgres redis go-api prometheus grafana

wait_for_url "$API_HEALTH_URL" "Go API"
wait_for_url "${API_HEALTH_URL%/health}/metrics" "Go API metrics"
wait_for_url "$PROMETHEUS_URL/-/ready" "Prometheus"
wait_for_url "$GRAFANA_URL/api/health" "Grafana"

for _ in $(seq 1 "$OBS_ATTEMPTS"); do
  response="$(
    curl -fsS --get "$PROMETHEUS_URL/api/v1/query" \
      --data-urlencode 'query=up{job="schooldesk-go-api"}' || true
  )"
  if printf '%s' "$response" | rg '"status":"success"' >/dev/null &&
    printf '%s' "$response" | rg '"result":\[\{' >/dev/null; then
    echo "Observability stack is ready."
    echo "Prometheus: $PROMETHEUS_URL"
    echo "Grafana: $GRAFANA_URL"
    exit 0
  fi
  sleep 2
done

echo "Prometheus did not return a scrape result for up{job=\"schooldesk-go-api\"}." >&2
compose logs --tail=160 prometheus >&2 || true
exit 1
