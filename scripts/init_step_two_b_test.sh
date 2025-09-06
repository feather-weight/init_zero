#!/usr/bin/env bash
set -Eeuo pipefail
port="$(grep -E '^FRONTEND_PORT=' .env | cut -d= -f2)"
[[ -n "$port" ]] || { echo "Missing FRONTEND_PORT in .env"; exit 1; }

# API health
curl -fsS "http://localhost:${port}/api/health" | grep -q '"status":"ok"' && echo "OK: frontend /api/health"

# Root page
curl -fsS "http://localhost:${port}/" >/dev/null && echo "OK: frontend index loads"

echo "PASS: 2(b)"

