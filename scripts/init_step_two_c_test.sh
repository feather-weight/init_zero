#!/usr/bin/env bash
set -Eeuo pipefail
fport="$(grep -E '^FRONTEND_PORT=' .env | cut -d= -f2)"
[[ -n "$fport" ]] || { echo "Missing FRONTEND_PORT"; exit 1; }

html="$(curl -fsS "http://localhost:${fport}/")"
echo "$html" | grep -qi 'Backend:' && echo "OK: homepage shows backend status" || { echo "Missing backend status on homepage"; exit 1; }
echo "PASS: 2(c)"

