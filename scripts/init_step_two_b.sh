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
note "Detected Next app: $NEXT_DIR"

# ---- 4) CSS Modules purity fix (scoped to NEXT_DIR) ----
STYLES_DIR="$NEXT_DIR/styles"
GLOBAL_FILE="$STYLES_DIR/parallax-globals.scss"
mkdir -p "$STYLES_DIR"
[ -f "$GLOBAL_FILE" ] || printf "/* Global CSS extracted from modules */\n" > "$GLOBAL_FILE"

# gather modules only under NEXT_DIR
MODULES=()
while IFS= read -r -d '' f; do
  MODULES+=("$f")
done < <(find "$NEXT_DIR" -type f \( -name "*.module.scss" -o -name "*.module.sass" \) -print0)

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
  note "Fixing CSS Modules purity across ${#MODULES[@]} files in $NEXT_DIR…"
  for f in "${MODULES[@]}"; do
    extract_root_blocks "$f"
    wrap_html_globals "$f"
  done
  awk '!seen[$0]++' "$GLOBAL_FILE" > "$GLOBAL_FILE.tmp" && mv "$GLOBAL_FILE.tmp" "$GLOBAL_FILE"
  ok "CSS Modules cleaned"
else
  note "No *.module.scss files found under $NEXT_DIR; skipping CSS fixes."
fi

# ---- 5) ensure global import exists in NEXT_DIR ----
IMPORT_LINE='import "@/styles/parallax-globals.scss";'
TARGET=""
if [ -f "$NEXT_DIR/app/layout.tsx" ]; then
  TARGET="$NEXT_DIR/app/layout.tsx"
elif [ -f "$NEXT_DIR/pages/_app.tsx" ]; then
  TARGET="$NEXT_DIR/pages/_app.tsx"
fi

if [ -n "$TARGET" ] && ! grep -Fq "$IMPORT_LINE" "$TARGET"; then
  note "Adding global import to $TARGET"
  tmp="$(mktemp)"; { echo "$IMPORT_LINE"; cat "$TARGET"; } > "$tmp"; mv "$tmp" "$TARGET"
  ok "Global import added"
else
  note "Global import already present or router entry not found; skipping."
fi

# ---- 6) build (non-interactive) in NEXT_DIR ----
note "Building Next.js in $NEXT_DIR…"
if jq -e '.scripts.build' "$NEXT_DIR/package.json" >/dev/null 2>&1; then
  ( cd "$NEXT_DIR" && npm run -s build )
else
  ( cd "$NEXT_DIR" && npx --yes next build )
fi
ok "Build completed"
