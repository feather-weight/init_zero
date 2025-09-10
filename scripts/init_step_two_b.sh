#!/usr/bin/env bash
# zsh guard
if [ -n "${ZSH_VERSION-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi
set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND" >&2' ERR

# ---- ensure nothing opens an editor (git hooks / tools) ----
export VISUAL=
export EDITOR=true
export GIT_EDITOR=true
export HUSKY=0
export CI=1
export NPM_CONFIG_FUND=false
export npm_config_audit=false

die(){ echo "❌ $*" >&2; exit 1; }
note(){ echo "➜ $*"; }
ok(){ echo "✅ $*"; }

# ---- 1) strict .env loader: allow override and fallback to parent .env ----
ENV_FILE="${ENV_FILE:-.env}"
if [ ! -f "$ENV_FILE" ] && [ -f "../.env" ]; then ENV_FILE="../.env"; fi
[ -f "$ENV_FILE" ] || die "Missing .env (set ENV_FILE or place a .env file here or one directory up)"

# Canonicalise to absolute path so a subsequent cd doesn't break it
ENV_FILE="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"

if grep -n '\$' "$ENV_FILE" >/dev/null; then
  echo "❌ $ENV_FILE must be literal-only (no \$ or \${…}). Offending lines:" >&2
  grep -n '\$' "$ENV_FILE" >&2 || true
  exit 1
fi

set -a
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  if [[ ! "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=(.*)$ ]]; then
    die "Invalid line in $ENV_FILE: $line"
  fi
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  val="${val#"${val%%[![:space:]]*}"}"
  export "$key=$val"
done < "$ENV_FILE"
set +a
ok "Loaded environment from $ENV_FILE (literal-only)"

# ---- 2) docker compose validation (if available) ----
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  note "Validating docker compose config…"
  docker compose config >/dev/null
  ok "docker compose config OK"
else
  note "docker compose not found; skipping compose validation."
fi

# ---- 3) locate Next.js app dir (supports monorepos) ----
detect_next_dir() {
  # Common monorepo locations first
  for d in ./frontend ./apps/frontend ./apps/web ./packages/frontend ./packages/web .; do
    if [ -f "$d/package.json" ] &&
       grep -q '"next"' "$d/package.json" &&
       { [ -d "$d/app" ] || [ -d "$d/pages" ]; }; then
      echo "$d"; return 0
    fi
  done
  # Fallback: scan up to 3 directories deep
  while IFS= read -r -d '' pjson; do
    dir="$(dirname "$pjson")"
    if grep -q '"next"' "$pjson" &&
       { [ -d "$dir/app" ] || [ -d "$dir/pages" ]; }; then
      echo "$dir"; return 0
    fi
  done < <(find . -maxdepth 3 -type f -name package.json -print0)
  return 1
}
NEXT_DIR="$(detect_next_dir)" || die "No Next.js app found (needs package.json with \"next\" AND app/ or pages/)"
note "Detected Next app: ${NEXT_DIR}"

# ---- 4) CSS Modules purity fix (scoped to NEXT_DIR) ----
STYLES_DIR="${NEXT_DIR}/styles"
GLOBAL_FILE="$STYLES_DIR/parallax-globals.scss"
mkdir -p "$STYLES_DIR"
[ -f "$GLOBAL_FILE" ] || printf "/* Global CSS extracted from modules */\n" > "$GLOBAL_FILE"

# gather modules only under NEXT_DIR
MODULES=()
while IFS= read -r -d '' f; do
  MODULES+=("$f")
done < <(find "${NEXT_DIR}" -type f \( -name "*.module.scss" -o -name "*.module.sass" \) -print0)

extract_root_blocks() {
  local f="$1"
  grep -qE '(^|[[:space:]])(:global\(\s*)?:root[[:space:]]*\{' "$f" || return 0
  cp -n "$f" "$f.bak" || true
  perl -0777 -ne 'while (m/(:global\(\s*)?:root\s*\{([^{}]|\{[^}]*\})*?\}/gms) { print "$&\n"; }' "$f" >> "$GLOBAL_FILE" || true
  perl -0777 -pe 's/(:global\(\s*)?:root\s*\{([^{}]|\{[^}]*\})*?\}//gms' -i "$f"
}

wrap_html_globals() {
  local f="$1" tmp
  cp -n "$f" "$f.bak" || true
  tmp="$(mktemp)"
  awk '{ gsub(/(^|[ \t{;])html(\[[^]]*\])([ \t]+(\.))/ , "\\1:global(html\\2)\\3"); print; }' "$f" > "$tmp" && mv "$tmp" "$f"
}

if [ "${#MODULES[@]}" -gt 0 ]; then
  note "Collecting any :root globals from ${#MODULES[@]} module files..."
  for f in "${MODULES[@]}"; do
    extract_root_blocks "$f"
  done
  # Do not dedupe line-by-line; it can drop closing braces and break CSS.
  ok "Global variables consolidated"
else
  note "No *.module.scss files found under ${NEXT_DIR}; skipping CSS fixes."
fi

# ---- 5) ensure global import exists in NEXT_DIR ----
IMPORT_LINE='import "../styles/parallax-globals.scss";'
TARGET=""
if [ -f "${NEXT_DIR}/app/layout.tsx" ]; then
  TARGET="${NEXT_DIR}/app/layout.tsx"
elif [ -f "${NEXT_DIR}/pages/_app.tsx" ]; then
  TARGET="${NEXT_DIR}/pages/_app.tsx"
fi

if [ -n "$TARGET" ] && ! grep -Fq "parallax-globals.scss" "$TARGET"; then
  note "Adding global import to $TARGET"
  tmp="$(mktemp)"; { echo "$IMPORT_LINE"; cat "$TARGET"; } > "$tmp"; mv "$tmp" "$TARGET"
  ok "Global import added"
else
  note "Global import already present or router entry not found; skipping."
fi

# ---- 6) install deps if needed, then build (non-interactive) ----

# Ensure Node and npm are available
command -v npm >/dev/null 2>&1 || die "npm not found. Install Node.js >= 18."

note "Ensuring Node dependencies in ${NEXT_DIR}..."
# Print effective proxy config without invoking protected npm getters
( cd "${NEXT_DIR}" && {
  echo "npm (.npmrc):";
  if [ -f .npmrc ]; then
    grep -E '^(proxy|https-proxy|cafile|strict-ssl)=' .npmrc || true;
  else
    echo "(no .npmrc present)";
  fi
  echo "env HTTP_PROXY:  ${HTTP_PROXY:-<unset>}";
  echo "env HTTPS_PROXY: ${HTTPS_PROXY:-<unset>}";
  echo "env NO_PROXY:    ${NO_PROXY:-<unset>}";
  } )

# Fail fast if npm cannot reach the registry via proxy
note "Pinging npm registry to verify connectivity..."
if ! ( cd "${NEXT_DIR}" && npm_config_proxy='' npm_config_https_proxy='' npm_config_noproxy="${NO_PROXY:-}" npm_config_strict_ssl="${NPM_STRICT_SSL:-true}" npm_config_fetch_timeout=15000 npm ping >/dev/null 2>&1 ); then
  echo "❌ npm registry unreachable with current proxy settings." >&2
  echo "   Check HTTP_PROXY/HTTPS_PROXY credentials and reachability." >&2
  echo "   If your company intercepts TLS, set PROXY_CAFILE in .env and rerun scripts/setup_proxy_from_env.sh" >&2
  echo "   For debug: cd frontend && npm ping -ddd" >&2
  exit 1
fi
MISSING_TS_DEPS=0
if [ -d "${NEXT_DIR}/node_modules" ]; then
  for d in "typescript" "@types/react" "@types/node"; do
    if [ ! -d "${NEXT_DIR}/node_modules/${d}" ]; then MISSING_TS_DEPS=1; break; fi
  done
fi

REASON=""
if [ ! -d "${NEXT_DIR}/node_modules" ]; then
  REASON="node_modules missing"
elif [ ! -x "${NEXT_DIR}/node_modules/.bin/next" ]; then
  REASON="next binary missing"
elif [ "$MISSING_TS_DEPS" -eq 1 ]; then
  REASON="TypeScript dev deps missing"
fi

if [ -n "$REASON" ]; then
  note "Installing Node dependencies (dev included); reason: $REASON"
  ( cd "${NEXT_DIR}" && \
    if [ -f package-lock.json ]; then npm_config_production=false npm_config_fetch_timeout=60000 npm_config_fetch_retries=2 npm_config_proxy="${HTTP_PROXY:-}" npm_config_https_proxy="${HTTPS_PROXY:-}" npm_config_strict_ssl="${NPM_STRICT_SSL:-true}" npm ci --no-audit --progress=false; else npm_config_production=false npm_config_fetch_timeout=60000 npm_config_fetch_retries=2 npm_config_proxy="${HTTP_PROXY:-}" npm_config_https_proxy="${HTTPS_PROXY:-}" npm_config_strict_ssl="${NPM_STRICT_SSL:-true}" npm install --no-audit --progress=false; fi )
  ok "Node dependencies installed"
else
  note "node_modules present; skipping install"
fi

note "Building Next.js in ${NEXT_DIR}..."
if jq -e '.scripts.build' "${NEXT_DIR}/package.json" >/dev/null 2>&1; then
  (
    set +e
    cd "${NEXT_DIR}" && npm_config_production=false npm run -s build
  )
else
  ( cd "${NEXT_DIR}" && npx --yes next build )
fi
ok "Build completed"
