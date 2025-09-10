#!/usr/bin/env bash
set -euo pipefail

npm run build >/dev/null

# Start prod server on :3000 (background)
PORT=${PORT:-3000}
npx next start -p "$PORT" >/dev/null 2>&1 & echo $! > .next.pid
sleep 2

# 1) HTML contains our hero copy
curl -sf "http://localhost:$PORT" | grep -qi "Wallet Recovery"

# 2) Parallax CSS present (desktop)
grep -R "background-attachment:\s*fixed" .next/static/ -n >/dev/null

# 3) Mobile fallback present in page output bundle
curl -sf "http://localhost:$PORT" | grep -qi "background-attachment: scroll"

echo "Step 2c checks passed."

# cleanup
kill "$(cat .next.pid)" >/dev/null 2>&1 || true
rm -f .next.pid
