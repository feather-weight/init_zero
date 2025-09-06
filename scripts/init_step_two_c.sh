#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

dc() { if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi; }
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

# Ensure NEXT_PUBLIC_BACKEND_URL exists
if ! grep -q '^NEXT_PUBLIC_BACKEND_URL=' .env; then
  echo "NEXT_PUBLIC_BACKEND_URL=http://localhost:8000" >> .env
fi

# Patch index.tsx to fetch backend health on the server (SSR)
cat > frontend/pages/index.tsx <<'IDX'
import Head from 'next/head';

type Props = { project: string; backendStatus: string };

export async function getServerSideProps() {
  const project = process.env.PROJECT_NAME ?? 'wallet-recoverer';
  const base = process.env.NEXT_PUBLIC_BACKEND_URL ?? 'http://localhost:8000';
  let backendStatus = 'unknown';
  try {
    const res = await fetch(`${base}/health`, { cache: 'no-store' });
    if (res.ok) {
      const j = await res.json();
      backendStatus = j?.status ?? 'unknown';
    } else {
      backendStatus = `http ${res.status}`;
    }
  } catch (e) {
    backendStatus = 'unreachable';
  }
  return { props: { project, backendStatus } };
}

export default function Home({ project, backendStatus }: Props) {
  return (
    <>
      <Head><title>{project}</title></Head>
      <main className="container">
        <h1>{project}</h1>
        <p className="hint">Watch-only wallet recovery — educational and defensive.</p>
        <p><strong>Backend:</strong> <span className="badge">{backendStatus}</span></p>
        <span className="badge">Step 2(c): Frontend ↔ Backend wired via env URL</span>
      </main>
    </>
  );
}
IDX

# Rebuild frontend (no cache to pick up env at build/start)
dc build --no-cache frontend
dc up -d frontend

# docs
cat > docs/init_step_two_c_frontend_backend_wiring.md <<'MD'
# Step 2(c): Frontend ↔ Backend Wiring (SSR)

- Homepage calls `${NEXT_PUBLIC_BACKEND_URL}/health` on the server.
- Displays backend status badge so you can confirm cross-service connectivity at a glance.
- All ports/URLs pulled from `.env`.

MD
source scripts/_pdf.sh
pdfify docs/init_step_two_c_frontend_backend_wiring.md docs/init_step_two_c_frontend_backend_wiring.pdf

echo "[2C] Done."

