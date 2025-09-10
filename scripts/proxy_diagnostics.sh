#!/usr/bin/env bash
set -Eeuo pipefail

die(){ echo "❌ $*" >&2; exit 1; }
note(){ echo "➜ $*"; }
ok(){ echo "✅ $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
if [ ! -f "$ENV_FILE" ]; then die "Missing .env at $ENV_FILE"; fi

# Load .env literally (no var expansion)
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
PROXY_USER="${env[PROXY_USER]:-}"
PROXY_PASS="${env[PROXY_PASS]:-}"
PROXY_CAFILE="${env[PROXY_CAFILE]:-}"
NPM_STRICT_SSL="${env[NPM_STRICT_SSL]:-true}"

mask_url(){
  local s="$1"; printf '%s' "$s" | sed -E 's#(https?://)([^:@/]*)(:([^@/]*))?@#\1****:****@#g'
}

HTTP_PROXY_ENV="${HTTP_PROXY:-}"
HTTPS_PROXY_ENV="${HTTPS_PROXY:-}"
NO_PROXY_ENV="${NO_PROXY:-}"

echo "— Proxy Environment —"
echo "HTTP_PROXY:  $(mask_url "${HTTP_PROXY_ENV}")"
echo "HTTPS_PROXY: $(mask_url "${HTTPS_PROXY_ENV}")"
echo "NO_PROXY:    ${NO_PROXY_ENV:-<unset>}"
echo "PROXY_CAFILE: ${PROXY_CAFILE:-<unset>} (exists? $([ -n "$PROXY_CAFILE" ] && [ -f "$PROXY_CAFILE" ] && echo yes || echo no))"

echo "— frontend/.npmrc —"
if [ -f "$ROOT_DIR/frontend/.npmrc" ]; then
  sed -E 's#(proxy=|https-proxy=)(https?://)([^:@/]*)(:([^@/]*))?@#\1\2****:****@#' "$ROOT_DIR/frontend/.npmrc" | sed 's/^/  /'
else
  echo "  (not found)"
fi

echo "— Node & npm —"
if command -v node >/dev/null 2>&1; then node -v; else echo "node: not found"; fi
if command -v npm  >/dev/null 2>&1; then npm -v;  else echo "npm:  not found"; fi

echo "— NPM registry ping —"
if command -v npm >/dev/null 2>&1; then
  if HTTP_PROXY="$HTTP_PROXY_ENV" HTTPS_PROXY="$HTTPS_PROXY_ENV" npm_config_fetch_timeout=15000 npm ping >/dev/null 2>&1; then
    ok "npm registry reachable"
  else
    echo "❌ npm ping failed (check proxy, CA, or credentials)"
  fi
else
  echo "(skipped: npm not installed)"
fi

echo "— Curl checks —"
curl_check(){
  local url="$1"; local label="$2"
  local out
  out=$(HTTPS_PROXY="$HTTPS_PROXY_ENV" HTTP_PROXY="$HTTP_PROXY_ENV" curl -I -sS --max-time 15 -o /dev/null -w "%{http_code} %{remote_ip} %{ssl_verify_result}" "$url" 2>&1) || true
  printf "  %s: %s\n" "$label" "$out"
}
curl_check "https://registry.npmjs.org/" "npmjs"
curl_check "https://pypi.org/simple/" "pypi"

echo "— Python HTTPS via urllib —"
if command -v python3 >/dev/null 2>&1; then
  HTTPS_PROXY="$HTTPS_PROXY_ENV" HTTP_PROXY="$HTTP_PROXY_ENV" python3 - <<'PY' || true
import os, ssl, urllib.request
url = 'https://pypi.org/simple/'
timeout = 10
cafile = os.environ.get('PROXY_CAFILE') or ''
ctx = ssl.create_default_context(cafile=cafile if cafile else None)
try:
    with urllib.request.urlopen(urllib.request.Request(url, method='HEAD'), timeout=timeout, context=ctx) as r:
        print(f"ok urllib HEAD {url} -> {r.status}")
except Exception as e:
    print(f"fail urllib HEAD {url}: {e}")
PY
else
  echo "(skipped: python3 not installed)"
fi

echo "— Suggestions —"
echo "If npm ping fails: ensure PROXY_* in .env are correct, run scripts/setup_proxy_from_env.sh, and set PROXY_CAFILE if TLS is intercepted."
echo "You can also temporarily set NPM_STRICT_SSL=false in .env (not recommended long-term)."

ok "Diagnostics complete"

