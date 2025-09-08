# fix_compose_working_dir.sh
set -euo pipefail

FILE=docker-compose.yml

# 1) Ensure 'working_dir: /app' exists at the service level
# 2) Remove any stray 'working_dir' nested under 'services.frontend.build'
if command -v yq >/dev/null 2>&1; then
  yq -i '
    .services.frontend.working_dir = "/app" |
    ( .services.frontend.build as $b | del(.services.frontend.build.working_dir) )
  ' "$FILE"
else
  # Fallback sed: delete any line with working_dir inside build: for frontend
  # (keeps indentation tolerant; adds service-level working_dir if missing)
  awk '
    BEGIN{in_frontend=0; in_build=0; has_wd=0}
    /^services:/ {print; next}
    {
      if ($0 ~ /^[[:space:]]*frontend:/ && prev ~ /^[[:space:]]*services:/) in_frontend=1
      if (in_frontend && $0 ~ /^[[:space:]]*build:/) in_build=1
      if (in_frontend && $0 ~ /^[[:space:]]*working_dir:[[:space:]]*\/app[[:space:]]*$/) has_wd=1
      # Skip working_dir lines while inside build for frontend
      if (in_frontend && in_build && $0 ~ /^[[:space:]]*working_dir:/) {next}

      print

      # Track leaves
      if (in_frontend && $0 ~ /^[[:space:]]*[A-Za-z0-9_-]+:/ && $0 !~ /^[[:space:]]*(build|frontend):/) {
        in_build=0
      }
      if (in_frontend && $0 ~ /^[^[:space:]]/ && $0 !~ /^[[:space:]]*frontend:/) {
        in_frontend=0
      }
      prev=$0
    }
    END{
      # No-op: we can’t reliably append with awk here.
    }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

  # If no service-level working_dir was present, insert one after dockerfile line
  if ! grep -qE '^[[:space:]]*working_dir:[[:space:]]*/app' "$FILE"; then
    perl -0777 -pe '
      s/(frontend:\s*\n(?:[^\n]*\n)*?\s*dockerfile:\s*frontend\/Dockerfile[^\n]*\n)/$1    working_dir: \/app\n/s
    ' -i "$FILE"
  fi
fi

echo "[compose-fix] Done."

