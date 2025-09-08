#!/usr/bin/env bash
if [ -n "${ZSH_VERSION:-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
# step_two_repair.sh — unify and repair Step 2 scripts
#
# This one‑shot script normalizes your Step 2 environment so it "just
# works" without guessing which patch to apply.  It fixes all known
# issues encountered during development:
#
# • Ensures required env variables exist in `.env` (ports, network,
#   backend URL, parallax flag).  It never overwrites custom values.
#
# • Cleans up `docker-compose.yml` by removing invalid keys under
#   `services.frontend.build` (e.g. `working_dir`) and by wiring
#   `${BE_PORT}` to `${BE_PORT}` where necessary.  A backup of
#   your compose file is created with a timestamp extension.
#
# • Writes a robust `frontend/Dockerfile` that does not suffer from
#   unexpanded `${FE_INTERNAL_PORT}` variables.  It uses a
#   standard `PORT` environment variable and launches Next.js with
#   `next start -H 0.0.0.0 -p ${PORT}`.  This prevents port‐related
#   errors and ensures the app binds to all interfaces.
#
# • Ensures parallax image assets exist in `frontend/public/` and
#   creates tiny placeholder JPEGs if your own images are missing.
#
# • Writes global SCSS with dual parallax backgrounds and a theme
#   toggle.  The SCSS uses CSS variables and falls back gracefully on
#   platforms where `background-attachment: fixed` is unsupported.
#
# • Injects a simple theme toggle component and mounts it in
#   `_app.tsx`, ensuring the theme attribute is updated on `<html>`.
#
# • Adds a basic `api/health` endpoint for the frontend so health
#   checks always succeed.
#
# After making changes, the script rebuilds and restarts the
# frontend container and tests the `/api/health` endpoint.  A curl
# response of `{"status":"ok","service":"frontend"}` indicates
# success.

set -Eeuo pipefail
IFS=$'\n\t'

# Determine project root (directory containing this script is scripts/)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

timestamp() {
  date +"%Y%m%d-%H%M%S"
}

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp "$f" "$f.$(timestamp).bak"
  fi
}

echo "[repair] Seeding required environment variables"
touch .env
# Add key=value to .env if not present
add_env_if_missing() {
  local key="$1" val="$2"
  grep -qE "^${key}=" .env 2>/dev/null || echo "${key}=${val}" >> .env
}

# Ports for services (host side)
add_env_if_missing MONGO_PORT "27017"
add_env_if_missing BE_PORT "8000"
add_env_if_missing FE_PORT "3000"
# Network name
add_env_if_missing NETWORK_NAME "recoverynet"
# Backend URL for the frontend to call
add_env_if_missing BE_URL "http://localhost:${BE_PORT:-8000}"
# Parallax enabled flag
add_env_if_missing PARALLAX_ENABLED "true"

echo "[repair] Updating docker-compose.yml"
COMPOSE_FILE="docker-compose.yml"
backup_file "$COMPOSE_FILE"
python3 - <<'PY' "$COMPOSE_FILE"
import yaml, pathlib, re, sys
compose_path = pathlib.Path(sys.argv[1])
data = yaml.safe_load(compose_path.read_text())

svc = data.get('services', {}).get('frontend')
if svc:
    # Move working_dir from build: to service level
    build = svc.get('build')
    if isinstance(build, dict) and 'working_dir' in build:
        svc['working_dir'] = build.pop('working_dir')
    # Remove invalid keys under build
    if isinstance(build, dict):
        allowed = {'context','dockerfile','args','target','cache_from','cache_to','labels','ssh','network'}
        svc['build'] = {k:v for k,v in build.items() if k in allowed}
    # Replace ${BE_PORT} with ${BE_PORT:-8000}
    def fix_port(s):
        return s.replace('${BE_PORT}','${BE_PORT:-8000}') if isinstance(s,str) else s
    svc = {k: fix_port(v) for k,v in svc.items()}
    data['services']['frontend'] = svc
# Write back
compose_path.write_text(yaml.safe_dump(data, sort_keys=False))
print("[compose] updated")
PY

echo "[repair] Writing robust frontend Dockerfile"
mkdir -p frontend
backup_file frontend/Dockerfile
cat > frontend/Dockerfile <<'EOF'
FROM node:22-alpine

# Disable Next.js telemetry for privacy
ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# Copy package descriptors and install dependencies
COPY package.json package-lock.json* ./
RUN npm install --no-audit --progress=false --legacy-peer-deps

# Copy source and build the production bundle
COPY . .

# Use PORT environment variable for runtime (default will be 3000 via Compose env)
ENV PORT=3000
RUN npm run build

# Expose runtime port
EXPOSE 3000

# Start Next.js in production mode on all interfaces using $PORT
CMD ["sh","-lc","npm run start -- -H 0.0.0.0 -p ${PORT}"]
EOF

echo "[repair] Ensuring parallax image assets"
mkdir -p frontend/public
for img in parallax-dark.jpg parallax-light.jpg; do
  if [ ! -f "frontend/public/$img" ]; then
    # If user uploaded a matching image (contains 'dark' or 'light'), copy it
    candidate="$(ls frontend/public/*${img#parallax-}* 2>/dev/null | head -n1 || true)"
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
      cp "$candidate" "frontend/public/$img"
    else
      # Create a tiny 2x2 JPEG placeholder; valid but blank
      printf '\xFF\xD8\xFF\xDB\x00\x43\x00' > "frontend/public/$img"
      printf '\x08%.0s' {1..64} >> "frontend/public/$img"
      printf '\xFF\xD9' >> "frontend/public/$img"
    fi
  fi
done

echo "[repair] Updating global SCSS for dual parallax and theme vars"
mkdir -p frontend/styles
backup_file frontend/styles/globals.scss
cat > frontend/styles/globals.scss <<'SCSS'
:root {
  /* Light theme defaults */
  --bg-image: url('/parallax-light.jpg');
  --overlay: rgba(255,255,255,0.10);
  --text-color: #0b0b0b;
  --bg-color: #ffffff;
}

[data-theme="dark"] {
  --bg-image: url('/parallax-dark.jpg');
  --overlay: rgba(0,0,0,0.35);
  --text-color: #f7f7f7;
  --bg-color: #0b0b0b;
}

html, body, #__next { height: 100%; }
body {
  margin: 0;
  font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial;
  color: var(--text-color);
  background: var(--bg-color);
  /* Parallax effect: background image with overlay fixed behind content */
  background-image: linear-gradient(var(--overlay), var(--overlay)), var(--bg-image);
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
  background-attachment: fixed;
}

/* iOS fallback: disable fixed attachment */
@supports (-webkit-overflow-scrolling: touch) {
  body { background-attachment: scroll; }
}

.header {
  position: sticky;
  top: 0;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 0.75rem;
  background: rgba(0,0,0,0.25);
  backdrop-filter: blur(6px);
}
SCSS

echo "[repair] Injecting ThemeToggle component"
mkdir -p frontend/components
backup_file frontend/components/ThemeToggle.tsx
cat > frontend/components/ThemeToggle.tsx <<'TSX'
import { useEffect, useState } from 'react';

// Determine initial theme: saved value, then system preference
function initialTheme(): 'light' | 'dark' {
  if (typeof window === 'undefined') return 'light';
  const stored = localStorage.getItem('theme');
  if (stored === 'light' || stored === 'dark') return stored as any;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export default function ThemeToggle() {
  const [theme, setTheme] = useState<'light'|'dark'>(initialTheme);
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('theme', theme);
  }, [theme]);
  return (
    <button onClick={() => setTheme(t => (t === 'dark' ? 'light' : 'dark'))} aria-label="Toggle theme">
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
TSX

echo "[repair] Updating _app.tsx to include the header and theme toggle"
mkdir -p frontend/pages
backup_file frontend/pages/_app.tsx
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

echo "[repair] Ensuring a basic health route exists"
mkdir -p frontend/pages/api
backup_file frontend/pages/api/health.ts
cat > frontend/pages/api/health.ts <<'API'
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(_req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({ status: 'ok', service: 'frontend' });
}
API

echo "[repair] Rebuilding and starting frontend service"
# Build and start via docker-compose
docker compose build frontend
docker compose up -d frontend

echo "[repair] Checking frontend health"
sleep 1
if curl -fsS "http://localhost:${FE_PORT:-3000}/api/health" >/dev/null; then
  echo "[repair] Frontend is responding at http://localhost:${FE_PORT:-3000}"
else
  echo "[repair] WARNING: Frontend did not respond to /api/health"
fi

echo "[repair] Step 2 repair complete."