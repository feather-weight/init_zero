#!/usr/bin/env bash
# Test script for Step 2(a)
#
# This script checks that all required environment variables are present in `.env`
# and validates the docker-compose configuration. It will exit with non-zero
# status if any required variable is missing or if `docker-compose config` fails.

set -Eeuo pipefail

echo "[2A TEST] Checking required environment variables..."

required_vars=(
  PROJECT_NAME
  API_BASE
  MONGO_PORT
  BE_PORT
  FE_PORT
  BE_INTERNAL_PORT
  
  NETWORK_NAME
  MONGO_SERVICE_NAME
  BE_SERVICE_NAME
  FE_SERVICE_NAME
  NEXT_PUBLIC_BE_URL
  MONGO_URI
  MDB_NAME
  JWT_SECRET
  NEXT_PUBLIC_PARALLAX
)

for key in "${required_vars[@]}"; do
  if ! grep -qE "^${key}=" .env; then
    echo "ERROR: Missing .env variable: $key" >&2
    exit 1
  fi
done

echo "[2A TEST] Validating docker-compose syntax..."

# Use docker compose when available; fallback to docker-compose
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose config -q
else
  docker-compose config -q
fi

# Optionally check if mongo is up (non-fatal)
mongo_container_name=$(grep -E '^MONGO_SERVICE_NAME=' .env | cut -d= -f2 || true)
if [ -n "$mongo_container_name" ]; then
  status=$(docker ps --filter name="$mongo_container_name" --format '{{.Status}}' || true)
  if [ -n "$status" ]; then
    echo "[2A TEST] Mongo container ($mongo_container_name) status: $status"
  else
    echo "[2A TEST] Note: Mongo container $mongo_container_name is not running (this is okay if you haven't run the init script yet)."
  fi
fi

echo "[2A TEST] PASS: All required variables present and compose configuration valid."
