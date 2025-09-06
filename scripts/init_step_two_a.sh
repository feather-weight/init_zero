#!/usr/bin/env bash
# Step 2(a) — Env-first refactor & Compose variables (wallet recoverer)
# - Makes ports, service names, network, and URLs come from .env
# - Nounset-safe: reads values from .env when interpolating
# - Leaves system in working order: brings up mongo; backend only if present
set -Eeuo pipefail
IFS=$'\n\t'

dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

say() { printf "\033[1;36m[2A]\033[0m %s\n" "$*"; }

add_env_if_missing() {
  local key="$1"
  local val="$2"
  if ! grep -qE "^${key}=" .env 2>/dev/null; then
    echo "${key}=${val}" >> .env
    echo "  + .env -> ${key}=${val}"
  fi
}

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

say "Ensuring .env exists"
[[ -f .env ]] || touch .env

say "Seeding/Updating env variables (idempotent)"
add_env_if_missing PROJECT_NAME "wallet-recoverer"
add_env_if_missing API_BASE "/api"

# Host-published ports
add_env_if_missing MONGO_PORT "27017"
add_env_if_missing BACKEND_PORT "8000"
add_env_if_missing FRONTEND_PORT "3000"

# Internal container ports
add_env_if_missing BACKEND_INTERNAL_PORT "8000"
add_env_if_missing FRONTEND_INTERNAL_PORT "3000"

# Network + service names
add_env_if_missing NETWORK_NAME "recoverynet"
add_env_if_missing MONGO_SERVICE_NAME "recoverer-mongo"
add_env_if_missing BACKEND_SERVICE_NAME "recoverer-backend"
add_env_if_missing FRONTEND_SERVICE_NAME "recoverer-frontend"

# UI feature flags
add_env_if_missing NEXT_PUBLIC_PARALLAX "1"

# Cross-service URL for frontend -> backend
BACKEND_PORT_VAL="$(grep -E '^BACKEND_PORT=' .env | cut -d= -f2 || true)"
: "${BACKEND_PORT_VAL:=8000}"
add_env_if_missing NEXT_PUBLIC_BACKEND_URL "http://localhost:${BACKEND_PORT_VAL}"

# Mongo URI + DB name
if ! grep -qE '^MONGO_URI=' .env; then
  MONGO_PORT_VAL="$(grep -E '^MONGO_PORT=' .env | cut -d= -f2 || true)"
  : "${MONGO_PORT_VAL:=27017}"
  echo "MONGO_URI=mongodb://mongo:${MONGO_PORT_VAL}/wallet_recoverer_db" >> .env
  echo "  + .env -> MONGO_URI=mongodb://mongo:${MONGO_PORT_VAL}/wallet_recoverer_db"
fi
add_env_if_missing MONGO_DB_NAME "wallet_recoverer_db"

# Secrets & provider keys (do not overwrite if present)
add_env_if_missing JWT_SECRET "changeme_fill_in_step_later"
add_env_if_missing INFURA_API_KEY ""
add_env_if_missing TATUM_API_KEY ""
add_env_if_missing BLOCKCHAIR_API_KEY ""

say "Writing docker-compose.yml with env substitution"
cat > docker-compose.yml <<'YML'
services:
  mongo:
    image: mongo:6.0
    container_name: ${MONGO_SERVICE_NAME}
    restart: unless-stopped
    ports:
      - "${MONGO_PORT}:27017"
    volumes:
      - ./.data/mongo:/data/db
    command: ["--bind_ip_all"]

  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: ${BACKEND_SERVICE_NAME}
    restart: unless-stopped
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - API_BASE=${API_BASE}
      - MONGO_URI=${MONGO_URI}
      - MONGO_DB_NAME=${MONGO_DB_NAME}
      - JWT_SECRET=${JWT_SECRET}
    ports:
      - "${BACKEND_PORT}:${BACKEND_INTERNAL_PORT}"
    depends_on:
      - mongo

networks:
  default:
    name: ${NETWORK_NAME}
YML

say "Validating docker-compose and bringing services up"
dc config -q

# Build/start only mongo if backend isn't present yet
if [[ -f backend/Dockerfile ]]; then
  dc up -d --build mongo backend
else
  dc up -d mongo
fi

say "Done: Step 2(a) applied successfully."
