#!/usr/bin/env bash
#
# Step 2(d) fix script
#
# This script fixes the dual parallax backgrounds and light/dark theme toggle
# for the wallet‑recoverer frontend. It assumes the project uses the
# pages router (frontend/pages) and that your parallax images are stored
# in `frontend/public/parallax-dark.png` and `frontend/public/parallax-light.jpg`.
#
# The script performs the following operations:
#   1. Verifies that the images exist in the public folder.
#   2. Writes a robust ThemeToggle component that persists the user's
#      theme choice and toggles a data-theme attribute on the <html> tag.
#   3. Updates globals.scss to define CSS variables for the hero
#      background and overlay in light and dark mode, and applies
#      parallax via `background-attachment: fixed`.
#   4. Updates pages/_app.tsx to mount the ThemeToggle and set the
#      initial theme on load.
#   5. Rebuilds and restarts the frontend service via docker compose.

set -Eeuo pipefail

# Determine repository root
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

IMG_DARK="frontend/public/parallax-dark.png"
IMG_LIGHT="frontend/public/parallax-light.jpg"

# Check that images exist
if [[ ! -f "$IMG_DARK" || ! -f "$IMG_LIGHT" ]]; then
  echo "Error: parallax images not found. Please ensure you have placed your" >&2
  echo "dark mode image at $IMG_DARK and light mode image at $IMG_LIGHT." >&2
  exit 1
fi

echo "[2D-fix] Updating ThemeToggle component"
mkdir -p frontend/components
cat > frontend/components/ThemeToggle.tsx <<'TSX'
import React, { useEffect, useState } from 'react';

export default function ThemeToggle() {
  // Hydration-safe theme state.  We initialise undefined and then set
  // from localStorage or prefers-color-scheme in useEffect.
  const [theme, setTheme] = useState<'light' | 'dark'>();

  // On mount, set the initial theme.
  useEffect(() => {
    const saved = typeof window !== 'undefined'
      ? (localStorage.getItem('theme') as 'light' | 'dark' | null)
      : null;
    const prefersDark = typeof window !== 'undefined'
      && window.matchMedia
      && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const initial = saved ?? (prefersDark ? 'dark' : 'light');
    setTheme(initial);
    document.documentElement.setAttribute('data-theme', initial);
    localStorage.setItem('theme', initial);
  }, []);

  // Toggle handler
  const flip = () => {
    const next: 'light' | 'dark' = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
  };

  // Render a simple button with emoji indicator. Avoid SSR mismatch by
  // defaulting to null until theme is set.
  return (
    <button onClick={flip} aria-label="Toggle colour theme">
      {theme === 'dark' ? '🌙 Dark' : '☀️ Light'}
    </button>
  );
}
TSX

echo "[2D-fix] Updating globals.scss for dual parallax backgrounds"
mkdir -p frontend/styles
cat > frontend/styles/globals.scss <<'SCSS'
/* Base colour scheme and CSS variables for parallax backgrounds. */

:root {
  color-scheme: light dark;
  /* Default (light) hero image and overlay. */
  --hero-image: url('/parallax-light.jpg');
  --overlay: rgba(0, 0, 0, 0.25);
}

/* Dark theme variables: override image and overlay. */
html[data-theme='dark'] {
  --hero-image: url('/parallax-dark.png');
  --overlay: rgba(0, 0, 0, 0.35);
}

/* Fallback for system dark mode when no explicit theme is stored. */
@media (prefers-color-scheme: dark) {
  :root {
    --hero-image: url('/parallax-dark.png');
    --overlay: rgba(0, 0, 0, 0.35);
  }
}

/* Basic typography and layout */
body {
  margin: 0;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial;
  /* Dual-layer parallax: overlay gradient and hero image. */
  background-image: linear-gradient(var(--overlay), var(--overlay)), var(--hero-image);
  background-position: center top;
  background-repeat: no-repeat;
  background-size: cover;
  background-attachment: fixed;
  min-height: 100vh;
}

.container {
  max-width: 880px;
  margin: 2rem auto;
  padding: 1rem;
}

.badge {
  display: inline-block;
  padding: 0.2rem 0.5rem;
  border-radius: 0.5rem;
  border: 1px solid currentColor;
  font-size: 0.8rem;
  opacity: 0.8;
}

.hint {
  opacity: 0.7;
  font-size: 0.9rem;
}

/* Parallax container for hero content */
.parallax {
  position: relative;
  min-height: 40vh;
  display: grid;
  place-items: center;
  color: white;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
  background-size: cover;
  background-position: center;
  background-attachment: fixed;
}

.parallax--hero {
  /* Use the CSS variables for the hero section background. */
  background-image: linear-gradient(var(--overlay), var(--overlay)), var(--hero-image);
}

/* Respect reduced motion preferences */
@media (prefers-reduced-motion: reduce) {
  body, .parallax {
    background-attachment: scroll;
  }
}
SCSS

echo "[2D-fix] Updating _app.tsx to initialise theme and mount toggle"
mkdir -p frontend/pages
cat > frontend/pages/_app.tsx <<'APP'
import type { AppProps } from 'next/app';
import '../styles/globals.scss';
import ThemeToggle from '../components/ThemeToggle';
import { useEffect } from 'react';

export default function App({ Component, pageProps }: AppProps) {
  // On mount, ensure the HTML element has a data-theme attribute.
  useEffect(() => {
    const saved = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const initial = (saved as 'light' | 'dark' | null) ?? (prefersDark ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', initial);
    localStorage.setItem('theme', initial);
  }, []);

  return (
    <>
      <header style={{ display: 'flex', alignItems: 'center', gap: '1rem', padding: '0.75rem 1rem' }}>
        <strong>wallet‑recoverer</strong>
        <ThemeToggle />
      </header>
      <Component {...pageProps} />
    </>
  );
}
APP

echo "[2D-fix] Fix complete. Rebuilding frontend container..."
# Rebuild and restart the frontend service to pick up changes
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose build frontend
  docker compose up -d frontend
else
  docker-compose build frontend
  docker-compose up -d frontend
fi

echo "[2D-fix] Done. Test the frontend at http://localhost:3000 and toggle themes."