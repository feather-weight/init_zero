#!/usr/bin/env bash
set -Eeuo pipefail

echo "[2D TEST] Compose check"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose config -q
else
  docker-compose config -q
fi

echo "[2D TEST] Frontend reachable"
fport="$(grep -E '^FE_PORT=' .env | cut -d= -f2)"
[[ -n "$fport" ]] || { echo "Missing FE_PORT in .env"; exit 1; }

curl -fsS "http://localhost:${fport}/" >/dev/null && echo "OK: homepage responds"

echo "[2D TEST] API health still good (if backend running)"
bport="$(grep -E '^BE_PORT=' .env | cut -d= -f2)"
if [[ -n "$bport" ]]; then
  (curl -fsS "http://localhost:${bport}/health" >/dev/null && echo "OK: backend /health") || echo "NOTE: backend not responding; may be expected if 1(b) not run"
fi

# Optional: verify assets if present
for img in parallax-dark.jpg parallax-light.jpg; do
  if [[ -f "frontend/public/$img" ]]; then
    echo "OK: found frontend/public/$img"
  else
    echo "NOTE: frontend/public/$img not found (page will fall back to default vars)"
  fi
done

echo "PASS: 2(d)"

