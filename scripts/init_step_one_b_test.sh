#!/usr/bin/env bash
set -Eeuo pipefail

dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

echo "==> Compose validate"
dc config -q && echo "OK: compose config"

echo "==> Backend container running?"
STATUS="$(docker ps --filter name=wallet-backend --format '{{.Status}}' || true)"
echo "Backend status: $STATUS"
echo "$STATUS" | grep -qi 'up' && echo "OK: backend running" || (echo "ERROR: backend not running"; exit 1)

echo "==> /health endpoint"
if command -v curl >/dev/null 2>&1; then
  RESP="$(curl -fsS http://localhost:8000/health)"
else
  RESP="$(wget -qO- http://localhost:8000/health)"
fi
echo "Response: $RESP"
echo "$RESP" | grep -q '"status": *"ok"' && echo "OK: health endpoint returns ok" || (echo "ERROR: health failed"; exit 1)

echo "==> PASS: Step 1(b) tests succeeded."

