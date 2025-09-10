#!/usr/bin/env bash
# shellcheck disable=SC2155
if [ -n "${ZSH_VERSION-}" ]; then emulate -L sh; fi
set -Eeuo pipefail

cd "$(dirname "$0")/.."  # repo root

# Export your .env strictly (fail if missing)
if [ ! -f .env ]; then
  echo "[2A] .env missing" >&2; exit 1
fi
set -a; . ./.env; set +a

req_vars=(
  PROJECT_NAME API_BASE WORKING_DIR
  BE_CONTAINER_NAME FE_CONTAINER_NAME MDB_CONTAINER_NAME
  MONGO_URI MONGO_DB JWT_SECRET
  MDB_IMAGE VOLUME MDB_PORT
  BE_URL NEXT_PUBLIC_APP_NAME NEXT_PUBLIC_API_BASE NEXT_PUBLIC_PARALLAX
  BE_PORT FE_PORT BE_INTERNAL_PORT FE_INTERNAL_PORT
  NETWORK_NAME
)
missing=0
for v in "${req_vars[@]}"; do
  if [ -z "${!v-}" ]; then
    echo "[2A] Missing required var: $v" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || { echo "[2A] Fix missing vars and rerun."; exit 1; }

# Quick sanity: compose parses and no invalid keys (like build.working_dir)
docker compose config >/dev/null

echo "[2A] OK: env + compose look good."

