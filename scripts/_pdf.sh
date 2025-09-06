#!/usr/bin/env bash
set -Eeuo pipefail
pdfify() {
  local src="${1:?markdown path required}"
  local dst="${2:?pdf path required}"
  echo "[pdfify] $src -> $dst"
  if command -v npx >/dev/null 2>&1 && npx --yes md-to-pdf --version >/dev/null 2>&1; then
    npx --yes md-to-pdf "$src" "$dst"
    return
  fi
  if command -v pandoc >/dev/null 2>&1; then
    pandoc --from=gfm "$src" -o "$dst"
    return
  fi
  echo "[pdfify] Skipping PDF (no md-to-pdf or pandoc)."
}
