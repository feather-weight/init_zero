#!/usr/bin/env bash
set -Eeuo pipefail

echo "[0B TEST] Verifying post-prune baseline..."
fail=0

# Must still have policy/docs and VCS
for f in README.md SECURITY.md CODE_OF_CONDUCT.md ETHICS.md .gitignore .gitattributes; do
  [[ -f "$f" ]] || { echo "Missing $f"; fail=1; }
done
[[ -d scripts ]] || { echo "Missing scripts/"; fail=1; }
[[ -d docs ]] || { echo "Missing docs/"; fail=1; }
[[ -d .git ]] || { echo "Missing .git/"; fail=1; }

# Negative checks (common app dirs should be gone if they existed)
for d in frontend backend deploy certs nginx; do
  [[ ! -e "$d" ]] || { echo "Found unexpected $d (should be removed)"; fail=1; }
done

# Secrets report presence is optional (depends on Docker/pull success), so do not fail if missing.
echo "[0B TEST] PASS/FAIL depends on above."
if (( fail )); then
  echo "[0B TEST] FAIL"; exit 1
else
  echo "[0B TEST] PASS"; exit 0
fi

