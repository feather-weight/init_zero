#!/usr/bin/env bash
# Step 2 all-in-one: normalize env, fix compose, write frontend Dockerfile, build & run.
# Idempotent. Run from repo root:  bash ./scripts/init_step_two_allinone.sh

# If launched from zsh, re-exec under bash for stricter error handling
if [ -n "${ZSH_VERSION:-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
set -Eeuo pipefail

# Colours for logs
RED=$'\e[31m'; YLW=$'\e[33m'; BLU=$'\e[34m'; GRN=$'\e[32m'; RST=$'\e[0m'

# Find repository root (assumes this script is in scripts/)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT"

echo "${BLU}[repair] Checking docker & docker compose availability…${RST}"
command -v docker >/dev/null || { echo "${RED}docker is not installed${RST}"; exit 1; }
docker compose version >/dev/null || { echo "${RED}docker compose plugin is not available${RST}"; exit 1; }

ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"
FRONTEND_DOCKERFILE="Dockerfile"

# Helper to read an env var from .env
read_env() {
  local key="$1"
  grep -E "^${key}=" "$ENV_FILE" | cut -d= -f2- || true
}

# Ensure .env exists and seed variables without overwriting existing values
touch "$ENV_FILE"
seed_env() {
  local key="$1"; local default="$2"
  if ! grep -qE "^${key}=" "$ENV_FILE"; then
    echo "${key}=${default}" >> "$ENV_FILE"
  elif [ -z "$(read_env "$key")" ]; then
    # Replace empty assignment with default
    sed -i.bak -E "s|^(${key}=).*|\1${default}|" "$ENV_FILE"
  fi
}

echo "${BLU}[repair] Seeding required environment keys…${RST}"
# Variables used in the YAML and Dockerfile. Add more here as needed.
seed_env PROJECT_NAME "wallet-recoverer"
seed_env API_BASE "/api"
seed_env WORKING_DIR "frontend"
seed_env MDB_CONTAINER_NAME "wallet-mongo"
seed_env BE_CONTAINER_NAME "wallet-backend"
seed_env FE_CONTAINER_NAME "wallet-frontend"
seed_env FE_PORT "3000"
seed_env BE_PORT "8000"
seed_env NETWORK_NAME "recoverynet"
# Mongo connection defaults
seed_env MONGO_URI "mongodb://mongo:27017/wallet_db"
seed_env MONGO_DB "wallet_db"
seed_env MONGO_DB_NAME "$(read_env MONGO_DB || echo wallet_db)"
# Security/feature defaults
seed_env JWT_SECRET "dev-secret"
seed_env NEXT_PUBLIC_BACKEND_URL "http://localhost:$(read_env BE_PORT || echo 8000)"
seed_env NEXT_PUBLIC_PARALLAX "true"

# Patch docker-compose.yml: remove invalid build.working_dir, fix API_BASE placeholder
if [ -f "$COMPOSE_FILE" ]; then
  echo "${BLU}[repair] Fixing ${COMPOSE_FILE}…${RST}"
  # Remove any `working_dir: ${WORKING_DIR}` line nested under build: in the frontend service
  # This line is invalid in Compose v3 under build section
  sed -i.bak '/^\s*build:\s*$/,/^\s*[A-Za-z]/{
    /^\s*working_dir:\s*\${WORKING_DIR}/d
  }' "$COMPOSE_FILE"

  # Replace API_BASE={API_BASE} with API_BASE=${API_BASE}
  sed -i.bak 's/API_BASE={API_BASE}/API_BASE=${API_BASE}/' "$COMPOSE_FILE"
fi

# Write a robust root-level Dockerfile for the frontend
# It installs dependencies, builds the Next.js app, and runs on $PORT
echo "${BLU}[repair] Writing ${FRONTEND_DOCKERFILE} for frontend…${RST}"
cat > "$FRONTEND_DOCKERFILE" <<'DOCKER'
FROM node:22-alpine

# Disable Next.js telemetry
ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# Copy package definitions
COPY frontend/package.json frontend/package-lock.json* ./

# Install dependencies (try npm ci first, fallback to install with legacy peer deps)
RUN (npm ci --no-audit --progress=false) || (npm install --no-audit --progress=false --legacy-peer-deps)

# Copy the rest of the frontend source
COPY frontend ./

# Default port inside container; can be overridden by PORT env
ARG FE_PORT=3000
ENV PORT=${FE_PORT}

# Build production bundle
RUN npm run build

EXPOSE 3000

# Start Next.js with host binding; use shell form for env expansion
CMD sh -lc 'HOST=0.0.0.0 PORT="${PORT:-3000}" npm run start -- -H 0.0.0.0 -p "${PORT:-3000}"'
DOCKER

# Optionally ensure parallax images exist (create tiny placeholder JPGs if missing)
mkdir -p frontend/public
for img in parallax-dark.jpg parallax-light.jpg; do
  [ -f "frontend/public/$img" ] || printf '\xFF\xD8\xFF\xD9' > "frontend/public/$img"
done

# Ensure basic theme toggle and global styles (overwrite if needed)
mkdir -p frontend/styles frontend/components frontend/pages/api
cat > frontend/styles/globals.scss <<'SCSS'
:root {
  --bg-url: url('/parallax-light.jpg');
  --overlay: rgba(255,255,255,.10);
  --text: #0b0b0b;
  --bg: #ffffff;
}
[data-theme='dark'] {
  --bg-url: url('/parallax-dark.jpg');
  --overlay: rgba(0,0,0,.30);
  --text: #f7f7f7;
  --bg: #0b0b0b;
}
html, body, #__next { height: 100%; }
body {
  margin: 0;
  color: var(--text);
  background: var(--bg);
  background-image: linear-gradient(var(--overlay), var(--overlay)), var(--bg-url);
  background-position: center;
  background-size: cover;
  background-repeat: no-repeat;
  background-attachment: fixed;
}
@supports (-webkit-overflow-scrolling: touch) {
  body { background-attachment: scroll; }
}
.header {
  position: sticky; top: 0;
  display: flex; gap: .75rem; align-items: center;
  padding: .5rem .75rem;
  background: rgba(0,0,0,.25);
  backdrop-filter: blur(6px);
}
SCSS

cat > frontend/components/ThemeToggle.tsx <<'TSX'
import { useEffect, useState } from 'react';
function getInitial() {
  if (typeof window === 'undefined') return 'light';
  const saved = localStorage.getItem('theme');
  if (saved === 'dark' || saved === 'light') return saved;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}
export default function ThemeToggle() {
  const [theme, setTheme] = useState(getInitial());
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);
  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
TSX

# Wrap pages with header and theme toggle
cat > frontend/pages/_app.tsx <<'APP'
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <div className="header">
        <strong>Wallet Recoverer</strong>
        <div style={{ marginLeft: 'auto' }}><ThemeToggle /></div>
      </div>
      <Component {...pageProps} />
    </>
  );
}
APP

# API health endpoint for frontend
cat > frontend/pages/api/health.ts <<'API'
import type { NextApiRequest, NextApiResponse } from 'next';
export default function handler(_req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({ status: 'ok', service: 'frontend' });
}
API

# Build and run the frontend service
echo "${BLU}[build] Building frontend container…${RST}"
docker compose build frontend

echo "${BLU}[up] Starting frontend (and dependencies)…${RST}"
docker compose up -d frontend

echo "${BLU}[logs] Frontend logs (first 60 lines)…${RST}"
docker compose logs -n 60 frontend || true

# Health check
echo "${BLU}[health] Checking http://localhost:${FE_PORT:-3000}/api/health…${RST}"
set +e
curl -fsS "http://localhost:$(read_env FE_PORT || echo 3000)/api/health" || true
set -e

echo "${GRN}Step 2 completed. You can proceed to Step 3.${RST}"

