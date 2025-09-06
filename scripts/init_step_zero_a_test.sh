#!/usr/bin/env bash
set -Eeuo pipefail

echo "[0A TEST] Checking baseline files & folders..."
fail=0
for f in README.md SECURITY.md CODE_OF_CONDUCT.md ETHICS.md .gitignore .gitattributes; do
  [[ -f "$f" ]] || { echo "Missing $f"; fail=1; }
done
[[ -d scripts ]] || { echo "Missing scripts/"; fail=1; }
[[ -d docs ]] || { echo "Missing docs/"; fail=1; }

# Soft check: README mentions watch-only / ethics (warn only)
if [[ -f README.md ]] && ! grep -Eiq 'watch-?only|ethic' README.md; then
  echo "NOTE: README.md does not reference watch-only/ethics yet."
fi

if (( fail )); then
  echo "[0A TEST] FAIL"; exit 1
else
  echo "[0A TEST] PASS"; exit 0
fi

