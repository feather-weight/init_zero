#!/usr/bin/env bash
set -Eeuo pipefail

note(){ echo "➜ $*"; }
ok(){ echo "✅ $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

note "Removing frontend/.npmrc (proxy settings) if present"
rm -f "$ROOT_DIR/frontend/.npmrc" && ok "Removed frontend/.npmrc" || true

note "To clear current shell proxy env (run these in your terminal):"
cat <<'EOT'
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
unset npm_config_proxy npm_config_https_proxy npm_config_strict_ssl npm_config_noproxy
EOT

note "Docker images will no longer receive proxy args (compose updated). Rebuild if previously built with proxy:"
echo "  docker compose build --no-cache"
ok "Proxy disabled for local toolchain"

