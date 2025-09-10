#!/usr/bin/env bash
# Generate local proxy config from .env for npm and shell
set -euo pipefail

die(){ echo "❌ $*" >&2; exit 1; }
ok(){ echo "✅ $*"; }
note(){ echo "➜ $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"

[ -f "$ENV_FILE" ] || die "Missing .env at $ENV_FILE"

# Simple literal loader (no var expansion)
declare -A env
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
    k="${BASH_REMATCH[1]}"; v="${BASH_REMATCH[2]}"
    v="${v#"${v%%[![:space:]]*}"}" # ltrim
    env[$k]="$v"
  fi
done < "$ENV_FILE"

PROXY_IP="${env[PROXY_IP]:-}"
PROXY_PORT="${env[PROXY_PORT]:-}"
PROXY_USER_RAW="${env[PROXY_USER]:-}"
PROXY_PASS_RAW="${env[PROXY_PASS]:-}"
PROXY_CAFILE="${env[PROXY_CAFILE]:-}"
NPM_STRICT_SSL="${env[NPM_STRICT_SSL]:-true}"

[ -n "$PROXY_IP" ] && [ -n "$PROXY_PORT" ] || die "PROXY_IP/PROXY_PORT must be set in .env"

# URL-encode user/pass if possible
encode(){
  local s="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY 2>/dev/null
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1], safe=''))
PY
  else
    # Fallback: naive replacements
    printf '%s' "$s" | sed -e 's/%/%25/g' -e 's/@/%40/g' -e 's/:/%3A/g' -e 's/\//%2F/g' -e 's/\+/%2B/g' -e 's/ /%20/g'
  fi
}

PROXY_USER="$(encode "$PROXY_USER_RAW")"
PROXY_PASS="$(encode "$PROXY_PASS_RAW")"

# Build URL
AUTH=""
if [ -n "$PROXY_USER_RAW" ] && [ -n "$PROXY_PASS_RAW" ]; then AUTH="${PROXY_USER}:${PROXY_PASS}@"; fi
PROXY_URL="http://${AUTH}${PROXY_IP}:${PROXY_PORT}"

# Exports suggestion
HTTP_PROXY="$PROXY_URL"
HTTPS_PROXY="$PROXY_URL"
NO_PROXY_DEFAULT="localhost,127.0.0.1,backend,frontend,mongo,.local,.docker.internal"

note "Writing frontend/.npmrc"
mkdir -p "$ROOT_DIR/frontend"
{
  echo "proxy=${HTTP_PROXY}"
  echo "https-proxy=${HTTPS_PROXY}"
  echo "strict-ssl=${NPM_STRICT_SSL}"
  if [ -n "$PROXY_CAFILE" ]; then echo "cafile=${PROXY_CAFILE}"; fi
  echo "fund=false"
  echo "audit=false"
  echo "registry=https://registry.npmjs.org/"
  echo "fetch-retry-maxtimeout=120000"
  echo "fetch-retry-mintimeout=10000"
  echo "fetch-timeout=60000"
} > "$ROOT_DIR/frontend/.npmrc"
ok "Created frontend/.npmrc (gitignored)"

note "You can export these in your shell (paste to terminal or add to ~/.zshrc):"
cat <<EOT
export HTTP_PROXY=${HTTP_PROXY}
export HTTPS_PROXY=${HTTPS_PROXY}
export NO_PROXY=${NO_PROXY:-$NO_PROXY_DEFAULT}
EOT

ok "Done"
