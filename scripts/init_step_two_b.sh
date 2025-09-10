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

# ---- 1) strict .env loader: literal KEY=VALUE only ----
ENV_FILE="${ENV_FILE:-.env}"
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
  # trim leading spaces around value
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

# ---- 3) CSS Modules purity fix (no editors, no prompts) ----
STYLES_DIR="styles"
GLOBAL_FILE="$STYLES_DIR/parallax-globals.scss"
mkdir -p "$STYLES_DIR"
[ -f "$GLOBAL_FILE" ] || printf "/* Global CSS extracted from modules */\n" > "$GLOBAL_FILE"

# find all SCSS module files (top-level styles/ and elsewhere)
mapfile -t MODULES < <(find . -type f \( -name "*.module.scss" -o -name "*.module.sass" \))

# extract :root { … } blocks to GLOBAL_FILE and remove from modules (robust, multiline-safe)
extract_root_blocks() {
  local f="$1"
  # quick check
  grep -qE '(^|[[:space:]])(:global\(\s*)?:root[[:space:]]*\{' "$f" || return 0
  cp -n "$f" "$f.bak" || true
  # extract
  perl -0777 -ne 'while (m/(:global\(\s*)?:root\s*\{([^{}]|\{[^}]*\})*?\}/gms) { print "$&\n"; }' "$f" >> "$GLOBAL_FILE" || true
  # remove
  perl -0777 -pe 's/(:global\(\s*)?:root\s*\{([^{}]|\{[^}]*\})*?\}//gms' -i "$f"
}

# wrap leading html[...] prefixes with :global(...) to appease CSS Modules
wrap_html_globals() {
  local f="$1" tmp
  cp -n "$f" "$f.bak" || true
  tmp="$(mktemp)"
  # Replace only when html[...] is a leading/segment prefix before a class selector
  # Example: "html[data-theme=light] .layerBack" -> ":global(html[data-theme=light]) .layerBack"
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
  # simple de-dup rows in global file
  awk '!seen[$0]++' "$GLOBAL_FILE" > "$GLOBAL_FILE.tmp" && mv "$GLOBAL_FILE.tmp" "$GLOBAL_FILE"
  ok "CSS Modules cleaned"
else
  note "No *.module.scss files found; skipping CSS Modules fixes."
fi

# ---- 4) ensure global import exists (prepend via temp file; no sed -i tricks) ----
IMPORT_LINE='import "@/styles/parallax-globals.scss";'
TARGET=""
if [ -f "app/layout.tsx" ]; then
  TARGET="app/layout.tsx"
elif [ -f "pages/_app.tsx" ]; then
  TARGET="pages/_app.tsx"
fi

if [ -n "$TARGET" ] && ! grep -Fq "$IMPORT_LINE" "$TARGET"; then
  note "Adding global import to $TARGET"
  tmp="$(mktemp)"
  {
    echo "$IMPORT_LINE"
    cat "$TARGET"
  } > "$tmp"
  mv "$tmp" "$TARGET"
  ok "Global import added"
else
  note "Global import already present or router entry not found; skipping."
fi

# ---- 5) build (non-interactive) ----
note "Building Next.js…"
if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
  npm run -s build
else
  npx --yes next build
fi
ok "Build completed"

