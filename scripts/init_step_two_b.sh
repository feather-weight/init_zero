#!/usr/bin/env bash
# zsh guard
if [ -n "${ZSH_VERSION-}" ]; then exec /usr/bin/env bash "$0" "$@"; fi

set -Eeuo pipefail
trap 'echo "❌ Error on line $LINENO: $BASH_COMMAND" >&2' ERR

# -- hard-disable anything interactive/editorial --------------------------------
export VISUAL=
export EDITOR=true
export GIT_EDITOR=true
export HUSKY=0
export CI=${CI:-1}
export PAGER=cat
export LESS=FRX
export NPM_CONFIG_FUND=false
export npm_config_audit=false

die(){ echo "❌ $*" >&2; exit 1; }
note(){ echo "➜ $*"; }
ok(){ echo "✅ $*"; }

DO_BUILD=0
TRACE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --build) DO_BUILD=1 ;;
    --no-build) DO_BUILD=0 ;;
    --trace) TRACE=1 ;;
    *) die "Unknown flag: $1" ;;
  esac; shift
done
[ "$TRACE" -eq 1 ] && set -x

# ---- 1) strict .env loader ----------------------------------------------------
ENV_FILE=".env"
[ -f "$ENV_FILE" ] || die "Missing $ENV_FILE"

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
  val="${val#"${val%%[![:space:]]*}"}"   # ltrim
  export "$key=$val"
done < "$ENV_FILE"
set +a
ok "Loaded environment from $ENV_FILE (literal-only)"

# ---- 2) docker compose validation (best effort) -------------------------------
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  note "Validating docker compose config…"
  docker compose config >/dev/null
  ok "docker compose config OK"
else
  note "docker compose not found; skipping compose validation."
fi

# ---- 3) CSS Modules purity fix ------------------------------------------------
STYLES_DIR="styles"
GLOBAL_FILE="$STYLES_DIR/parallax-globals.scss"
mkdir -p "$STYLES_DIR"
[ -f "$GLOBAL_FILE" ] || printf "/* Global CSS extracted from modules */\n" > "$GLOBAL_FILE"

# gather modules project-wide
mapfile -t MODULES < <(find . -type f \( -name "*.module.scss" -o -name "*.module.sass" \))

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
  awk '
    {
      gsub(/(^|[ \t{;])html(\[[^]]*\])([ \t]+(\.))/ , "\\1:global(html\\2)\\3");
      print;
    }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

if ((${#MODULES[@]})); then
  note "Fixing CSS Modules purity across ${#MODULES[@]} files…"
  for f in "${MODULES[@]}"; do
    extract_root_blocks "$f"
    wrap_html_globals "$f"
  done
  awk '!seen[$0]++' "$GLOBAL_FILE" > "$GLOBAL_FILE.tmp" && mv "$GLOBAL_FILE.tmp" "$GLOBAL_FILE"
  ok "CSS Modules cleaned"
else
  note "No *.module.scss files found; skipping CSS Modules fixes."
fi

# ensure global import present
IMPORT_LINE='import "@/styles/parallax-globals.scss";'
TARGET=""
if [ -f "app/layout.tsx" ]; then
  TARGET="app/layout.tsx"
elif [ -f "pages/_app.tsx" ]; then
  TARGET="pages/_app.tsx"
fi
if [ -n "$TARGET" ] && ! grep -Fq "$IMPORT_LINE" "$TARGET"; then
  note "Adding global import to $TARGET"
  tmp="$(mktemp)"; { echo "$IMPORT_LINE"; cat "$TARGET"; } > "$tmp"; mv "$tmp" "$TARGET"
  ok "Global import added"
else
  note "Global import already present or router entry not found; skipping."
fi

# ---- 4) Build (optional; default OFF so we can isolate issues) ----------------
if [ "$DO_BUILD" -eq 1 ]; then
  note "Building Next.js (non-interactive)…"
  if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
    npm run -s build
  else
    npx --yes next build
  fi
  ok "Build completed"
else
  note "Skipping build (use --build to enable)."
fi

ok "init_step_two_b.sh finished."

