#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

dc() { if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi; }
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

echo "[2D] Ensure env flag for parallax"
grep -q '^NEXT_PUBLIC_PARALLAX=' .env || echo 'NEXT_PUBLIC_PARALLAX=1' >> .env

echo "[2D] Ensure public/ exists and note images"
mkdir -p frontend/public
# (User should copy their images into these exact paths)
#   frontend/public/parallax-dark.jpg
#   frontend/public/parallax-light.jpg

echo "[2D] Add ThemeToggle and Theme bootstrap"

mkdir -p frontend/components

cat > frontend/components/ThemeToggle.tsx <<'TSX'
import React from 'react';

export default function ThemeToggle() {
  const [theme, setTheme] = React.useState<string | null>(null);

  React.useEffect(() => {
    // hydration-safe read
    const saved = typeof window !== 'undefined' ? localStorage.getItem('theme') : null;
    if (saved === 'light' || saved === 'dark') {
      setTheme(saved);
      document.documentElement.setAttribute('data-theme', saved);
    } else {
      // fallback to prefers-color-scheme
      const prefersDark = typeof window !== 'undefined' &&
        window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      const initial = prefersDark ? 'dark' : 'light';
      setTheme(initial);
      document.documentElement.setAttribute('data-theme', initial);
      localStorage.setItem('theme', initial);
    }
  }, []);

  const toggle = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
  };

  return (
    <button aria-label="Toggle color scheme" onClick={toggle} style={{marginLeft: 'auto'}}>
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
TSX

echo "[2D] Update _app.tsx to mount toggle in a simple header"
# safe replace to ensure import of scss and toggle header
cat > frontend/pages/_app.tsx <<'APP'
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';

export default function App({ Component, pageProps }: AppProps) {
  return (
    <>
      <header style={{display:'flex', alignItems:'center', gap:'1rem', padding:'0.75rem 1rem'}}>
        <strong>wallet-recoverer</strong>
        <ThemeToggle />
      </header>
      <Component {...pageProps} />
    </>
  );
}
APP

echo "[2D] Update globals.scss with theme CSS vars and dual parallax"
# Convert to SCSS if not already present (Step 2b created it)
mkdir -p frontend/styles
cat > frontend/styles/globals.scss <<'SCSS'
:root {
  color-scheme: light dark;
  --hero-image: url('/parallax-light.jpg');
  --overlay: rgba(0,0,0,.25);
}

html[data-theme="dark"] {
  --hero-image: url('/parallax-dark.jpg');
  --overlay: rgba(0,0,0,.35);
}

@media (prefers-color-scheme: dark) {
  :root { --hero-image: url('/parallax-dark.jpg'); --overlay: rgba(0,0,0,.35); }
}

/* base */
body { margin: 0; font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial; }
.container { max-width: 880px; margin: 2rem auto; padding: 1rem; }
.badge { display:inline-block; padding:.2rem .5rem; border-radius:.5rem; border:1px solid currentColor; font-size:.8rem; opacity:.8; }
.hint { opacity:.7; font-size:.9rem; }

/* Parallax */
.parallax {
  position: relative;
  min-height: 40vh;
  display: grid;
  place-items: center;
  color: white;
  text-shadow: 0 1px 2px rgba(0,0,0,.4);
  background-size: cover;
  background-position: center;
  background-attachment: fixed; /* simple, compatible parallax */
}

.parallax--hero {
  /* dual-mode background chosen by CSS var */
  background-image: linear-gradient(var(--overlay), var(--overlay)), var(--hero-image);
}

/* Accessibility: respect reduced motion */
@media (prefers-reduced-motion: reduce) {
  .parallax { background-attachment: scroll; }
}
SCSS

echo "[2D] Ensure homepage keeps parallax gated by env and shows backend status if present"
cat > frontend/pages/index.tsx <<'IDX'
import Head from 'next/head';

type Props = { project: string; parallax: boolean; backendStatus: string };

export async function getServerSideProps() {
  const project = process.env.PROJECT_NAME ?? 'wallet-recoverer';
  const parallax = (process.env.NEXT_PUBLIC_PARALLAX ?? '1') === '1';
  const base = process.env.NEXT_PUBLIC_BACKEND_URL ?? 'http://localhost:8000';
  let backendStatus = 'unknown';
  try {
    const res = await fetch(`${base}/health`, { cache: 'no-store' });
    backendStatus = res.ok ? (await res.json())?.status ?? 'unknown' : `http ${res.status}`;
  } catch {
    backendStatus = 'unreachable';
  }
  return { props: { project, parallax, backendStatus } };
}

export default function Home({ project, parallax, backendStatus }: Props) {
  return (
    <>
      <Head><title>{project}</title></Head>
      {parallax && (
        <section className="parallax parallax--hero" role="img" aria-label="Decorative parallax background">
          <h1 style={{margin:0}}>{project}</h1>
        </section>
      )}
      <main className="container">
        <p className="hint">Watch-only wallet recovery — educational and defensive.</p>
        <p><strong>Backend:</strong> <span className="badge">{backendStatus}</span></p>
        <span className="badge">Step 2(d): Theme toggle + dual parallax</span>
      </main>
    </>
  );
}
IDX

echo "[2D] Extend compose only if frontend service is missing (usually present from 2b)"
# no compose changes if already added in 2(b); just rebuild
echo "[2D] Build & restart frontend"
dc build frontend
dc up -d frontend

echo "[2D] Write doc"
mkdir -p docs
cat > docs/init_step_two_d_theme_and_dual_parallax.md <<'MD'
# Step 2(d): Theme Toggle + Dual Parallax

- Adds a light/dark toggle persisted in localStorage with `prefers-color-scheme` fallback.
- Parallax hero uses CSS variables so the background image swaps by theme:
  - Light → `/parallax-light.jpg`
  - Dark →  `/parallax-dark.jpg`
- Respects `NEXT_PUBLIC_PARALLAX` in `.env` (1 on, 0 off).
- Accessible: background-attachment relaxes if user prefers reduced motion.

Place your images at:
- `frontend/public/parallax-dark.jpg`
- `frontend/public/parallax-light.jpg`
MD

# Try to PDF if your environment has a converter; otherwise skip
if [[ -f scripts/_pdf.sh ]]; then
  source scripts/_pdf.sh
  pdfify docs/init_step_two_d_theme_and_dual_parallax.md docs/init_step_two_d_theme_and_dual_parallax.pdf || true
fi

echo "[2D] Done."

