#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8080/api}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080/health}"
READY_URL="${READY_URL:-${HEALTH_URL%/health}/ready}"
METRICS_URL="${METRICS_URL:-${HEALTH_URL%/health}/metrics}"
VERIFY_MODE="${VERIFY_MODE:-mutating}"

case "$API_BASE_URL" in
  http://127.0.0.1:*|http://localhost:*|http://go-api:*|http://schooldesk-go-api:*) ;;
  *)
    echo "Refusing non-local API_BASE_URL=$API_BASE_URL" >&2
    echo "This verifier is intentionally limited to the local Docker backend." >&2
    exit 64
    ;;
esac

case "$HEALTH_URL" in
  http://127.0.0.1:*|http://localhost:*|http://go-api:*|http://schooldesk-go-api:*) ;;
  *)
    echo "Refusing non-local HEALTH_URL=$HEALTH_URL" >&2
    echo "This verifier is intentionally limited to the local Docker backend." >&2
    exit 64
    ;;
esac

for local_url in "$READY_URL" "$METRICS_URL"; do
  case "$local_url" in
    http://127.0.0.1:*|http://localhost:*|http://go-api:*|http://schooldesk-go-api:*) ;;
    *)
      echo "Refusing non-local verification URL=$local_url" >&2
      echo "This verifier is intentionally limited to the local Docker backend." >&2
      exit 64
      ;;
  esac
done

cd "$ROOT_DIR"

docker compose up -d postgres redis go-api

for _ in $(seq 1 60); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    break
  fi
  sleep 1
done

curl -fsS "$HEALTH_URL" >/dev/null
curl -fsS "$READY_URL" >/dev/null
curl -fsS "$METRICS_URL" >/dev/null

if [[ "${SKIP_SEED:-0}" != "1" ]]; then
  docker compose exec -T go-api go run ./cmd/seed >/tmp/schooldesk-local-seed.log
fi

(
  cd "$ROOT_DIR/school-backend"
  API_BASE_URL="$API_BASE_URL" \
  HEALTH_URL="$HEALTH_URL" \
  VERIFY_MODE="$VERIFY_MODE" \
  RATE_LIMIT_DELAY_MS="${RATE_LIMIT_DELAY_MS:-350}" \
  go run ./cmd/local-api-verify
)
