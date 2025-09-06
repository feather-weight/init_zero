#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

say() { printf "\033[1;34m[0A]\033[0m %s\n" "$*"; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

say "Ensuring directories"
mkdir -p scripts docs

say "Seeding .gitignore (if missing)"
if [[ ! -f .gitignore ]]; then
  cat > .gitignore <<'EOF'
# Node
node_modules/
.next/
# Python
__pycache__/
*.py[cod]
.venv/
# Env
.env
.env.*
# OS
.DS_Store
Thumbs.db
# Logs
*.log
# Docker/Build
*.pid
# Reports
docs/*.pdf
EOF
fi

say "Seeding .gitattributes (if missing)"
if [[ ! -f .gitattributes ]]; then
  cat > .gitattributes <<'EOF'
* text=auto eol=lf
*.sh text eol=lf
*.md text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.json text eol=lf
EOF
fi

say "Ensuring core policy docs (do not overwrite existing)"
touch README.md SECURITY.md CODE_OF_CONDUCT.md ETHICS.md

# Seed ETHICS.md if empty (baseline vow)
if [[ ! -s ETHICS.md ]]; then
  cat > ETHICS.md <<'EOF'
# Ethics & Safe Use (“The Vow”)

- Recovery-only; **watch-only by default**.
- No unauthorized access or misuse.
- Follow SECURITY.md for responsible disclosure.
- Follow CODE_OF_CONDUCT.md for community standards.

Using this software implies acceptance of this vow.
EOF
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  say "Initializing git repository"
  git init
fi

say "Creating Step 0A report (Markdown)"
REPORT_MD="docs/init_step_zero_a_repo_reset_and_ethics.md"
cat > "$REPORT_MD" <<'EOF'
# Step 0A — Repo Scaffolding & Ethical Baseline

This step ensures a policy-first foundation:
- Ensure core docs: `README.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `ETHICS.md`.
- Add safe `.gitignore` and `.gitattributes`.
- Initialize Git if needed.

Proceed to **Step 0B** to perform the destructive prune and secret scan.
EOF

say "Attempting to generate PDF (optional)"
if command -v pandoc >/dev/null 2>&1; then
  pandoc "$REPORT_MD" -o "docs/init_step_zero_a_repo_reset_and_ethics.pdf" || true
elif command -v npx >/dev/null 2>&1; then
  npx --yes md-to-pdf "$REPORT_MD" --output "docs/init_step_zero_a_repo_reset_and_ethics.pdf" || true
fi

say "Creating initial commit if nothing committed yet"
if [[ -z "$(git rev-list --all 2>/dev/null)" ]]; then
  git add README.md SECURITY.md CODE_OF_CONDUCT.md ETHICS.md .gitignore .gitattributes scripts docs
  git commit -m "Step 0A: policy baseline, git attrs/ignore, docs & reports"
fi

say "Step 0A complete."

