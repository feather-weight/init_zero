#!/usr/bin/env bash
#
# Step 2(b) static fix script
#
# This script rewrites docker‑compose.yml with a clean static
# configuration for the mongo, backend and frontend services using
# fixed host ports. It also builds and starts the frontend service
# to confirm the new configuration works. Use this when the compose
# file has been corrupted by stray `networks.frontend` blocks and
# environment variables for ports are causing issues.

set -Eeuo pipefail
IFS=$'\n\t'

# Determine repository root (so script works from any location)
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "[2B-static-fix] Rewriting docker-compose.yml with static ports"

cat > docker-compose.yml <<'YML'
version: "3.8"

services:
  mongo:
    image: mongo:6.0
    container_name: recoverer-mongo
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - ./.data/mongo:/data/db

  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: recoverer-backend
    restart: unless-stopped
    environment:
      - PROJECT_NAME=wallet-recoverer
      - API_BASE=/api
      - MONGO_URI=mongodb://recoverer-mongo:27017/wallet_recoverer_db
      - MDB_NAME=wallet_recoverer_db
      - JWT_SECRET=changeme_fill_in_step_later
    ports:
      - "8000:8000"
    depends_on:
      - mongo

  frontend:
    build:
      context: .
      dockerfile: frontend/Dockerfile
    container_name: recoverer-frontend
    restart: unless-stopped
    environment:
      - PROJECT_NAME=wallet-recoverer
      - NEXT_PUBLIC_BE_URL=http://localhost:8000
      - NEXT_PUBLIC_PARALLAX=1
    depends_on:
      - backend
    ports:
      - "3000:3000"

networks:
  default:
    name: recoverynet
YML

# Try to build and start the frontend to validate the configuration. If
# docker compose is not available, fall back to docker‑compose.
echo "[2B-static-fix] Building and starting frontend with static ports"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose up -d --build frontend || true
else
  docker-compose up -d --build frontend || true
fi

echo "[2B-static-fix] Done. Please check 'docker compose logs frontend' to verify the frontend is running."