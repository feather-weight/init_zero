#!/usr/bin/env bash
set -Eeuo pipefail

# Helper: prefer 'docker compose', fallback to 'docker-compose'
dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "==> Creating base directories"
mkdir -p scripts backend/app/{api,core,db,models,services} frontend deploy certs docs

echo "==> Creating .gitignore (idempotent)"
cat > .gitignore <<'EOF'
# OS
.DS_Store

# Node
node_modules/
.npm/
.next/
out/

# Python
__pycache__/
*.pyc
.venv/
venv/

# Docker & data
.data/
*.log

# Env
.env
.env.*
EOF

echo "==> Creating .env with safe defaults (idempotent)"
if [ ! -f .env ]; then
  cat > .env <<'EOF'
PROJECT_NAME=wallet_recovery
API_BASE=/api

# Mongo (configure for your environment)
MONGO_URI=mongodb://mongo:27017/wallet_recovery
MONGO_DB=wallet_recovery

# Provider keys (set locally; do not commit)
TATUM_API_KEY=
INFURA_PROJECT_ID=
BLOCKCHAIR_KEY=

# JWT (set a secure value locally)
JWT_SECRET=

# App
NEXT_PUBLIC_APP_NAME=init
NEXT_PUBLIC_API_BASE=/api
NODE_ENV=production

# Flags
MAINNET_ONLY=true
DISABLE_TESTNET=true
WATCH_ONLY_DEFAULT=true
EOF
fi

echo "==> Writing docker-compose.yml (Mongo only)"
cat > docker-compose.yml <<'YML'
services:
  mongo:
    image: mongo:6.0
    container_name: recovery
    restart: unless-stopped
    ports:
      - "27020:27020"
    volumes:
      - mongo_data:/data/db
    command: ["--bind_ip_all"]

networks:
  default:
    name: walletnet

volumes:
  mongo_data:
    driver: local
YML

echo "==> Bringing up Mongo"
dc up -d mongo

echo "==> Done: Step 1(a) base structure ready."

