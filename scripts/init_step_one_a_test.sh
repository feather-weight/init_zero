#!/usr/bin/env bash
set -Eeuo pipefail

dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

echo "==> Validating directories"
test -d scripts && test -d backend && test -d frontend && test -d deploy && test -d certs && test -d docs && echo "OK: directories exist"

echo "==> Validating .env"
grep -q 'MONGO_URI=' .env && grep -q 'JWT_SECRET=' .env && echo "OK: .env basics present"

echo "==> Validating docker-compose syntax"
dc config -q && echo "OK: compose validated"

echo "==> Checking Mongo container is up"
STATUS="$(docker ps --filter name=wallet-mongo --format '{{.Status}}' || true)"
echo "Mongo status: $STATUS"
echo "$STATUS" | grep -qi 'up' && echo "OK: Mongo running" || (echo "ERROR: Mongo not running"; exit 1)

echo "==> PASS: Step 1(a) tests succeeded."
