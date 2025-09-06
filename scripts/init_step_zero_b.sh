#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

say() { printf "\033[1;35m[0B]\033[0m %s\n" "$*"; }

# Safety gate: require explicit confirmation for destructive prune
: "${CONFIRM_CLEAN:=}"
if [[ "$CONFIRM_CLEAN" != "YES" ]]; then
  say "Refusing to prune without CONFIRM_CLEAN=YES (no changes made)."
  say "Run: CONFIRM_CLEAN=YES scripts/init_step_zero_b.sh"
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

say "Preparing whitelist (things to KEEP at repo root)"
# Keep core metadata + scripts/docs + VCS
KEEP_SET=("." ".." ".git" "scripts" "docs" "README.md" "SECURITY.md" "CODE_OF_CONDUCT.md" "ETHICS.md" ".gitignore" ".gitattributes" "LICENSE")

say "Pruning non-whitelisted files/folders at repo root"
shopt -s dotglob nullglob
for path in * .*; do
  skip=false
  for k in "${KEEP_SET[@]}"; do
    [[ "$path" == "$k" ]] && { skip=true; break; }
  done
  $skip && continue
  rm -rf -- "$path"
done
shopt -u dotglob nullglob

say "Writing Step 0B report (Markdown)"
REPORT_MD="docs/init_step_zero_b_secret_scan_and_prune.md"
cat > "$REPORT_MD" <<'EOF'
# Step 0B — Destructive Prune & Secret Scan

Actions:
- Removed non-whitelisted content from repo root (kept policy/docs/VCS).
- Ran secrets scan (Gitleaks in Docker) in the working tree.
- Committed and tagged baseline as `step-0`.

Notes:
- To enforce hard failure on leaks, set STRICT_SECRET_BLOCK=1.
- To re-run the scan later: see the command in this file.
EOF

say "Running secrets scan via Dockerized gitleaks (warn by default)"
: "${STRICT_SECRET_BLOCK:=0}"
GITLEAKS_CMD=(docker run --rm -v "$PWD":/repo zricethezav/gitleaks:latest detect -s /repo --no-git -v -r /repo/docs/init_step_zero_b_gitleaks_report.json)
set +e
"${GITLEAKS_CMD[@]}"
leaks_rc=$?
set -e

if (( leaks_rc != 0 )); then
  if (( STRICT_SECRET_BLOCK )); then
    say "Secrets found and STRICT_SECRET_BLOCK=1 -> failing."
    exit 2
  else
    say "WARNING: Secrets may be present (see docs/init_step_zero_b_gitleaks_report.json). Proceeding (non-strict)."
  fi
fi

say "Attempting to generate PDF (optional)"
if command -v pandoc >/dev/null 2>&1; then
  pandoc "$REPORT_MD" -o "docs/init_step_zero_b_secret_scan_and_prune.pdf" || true
elif command -v npx >/dev/null 2>&1; then
  npx --yes md-to-pdf "$REPORT_MD" --output "docs/init_step_zero_b_secret_scan_and_prune.pdf" || true
fi

say "Committing and tagging Step 0 baseline"
git add -A
git commit -m "Step 0B: destructive prune + secret scan + reports" || true
git tag -f step-0

say "Step 0B complete."

