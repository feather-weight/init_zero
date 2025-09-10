#!/usr/bin/env bash
set -euo pipefail

# Pre-reqs
if ! grep -q '"sass"' package.json; then
  echo "Adding sass…"
  npm pkg set devDependencies.sass="^1.77.0" >/dev/null
  npm ci
fi

# SCSS structure
mkdir -p styles

# variables
cat > styles/_variables.scss <<'VARS'
$brand: #0ea5e9;
$bg-dark: #0b1220;
$text: #e5eefb;
$radius: 16px;
VARS

# mixins
cat > styles/_mixins.scss <<'MIX'
@use 'variables' as *;

@mixin glass() {
  background: rgba(255,255,255,0.06);
  backdrop-filter: blur(6px);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: $radius;
}
MIX

# global (import order: variables → mixins → rest)
cat > styles/global.scss <<'GLOBAL'
@use 'variables' as *;
@use 'mixins' as *;

:root {
  --brand: #0ea5e9;
  --bg-dark: #0b1220;
  --text: #e5eefb;
}

* { box-sizing: border-box; }
html, body { height: 100%; }
body {
  margin: 0;
  font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, "Helvetica Neue", Arial;
  color: var(--text);
  background: var(--bg-dark);
}

.container {
  max-width: 1100px; margin: 0 auto; padding: 2rem;
}

.btn {
  display: inline-block; padding: .75rem 1rem; border-radius: $radius;
  color: white; text-decoration: none; background: $brand;
}

.parallax {
  min-height: 70vh;
  background-image: linear-gradient(180deg, rgba(14,165,233,.18), rgba(11,18,32,1)), url('/parallax.jpg');
  background-attachment: fixed; /* desktop parallax */
  background-size: cover;
  background-position: center;
  display: grid; place-items: center;
}

.card { @include glass(); padding: 1.25rem; }
GLOBAL

# Ensure root layout imports global.scss (Next.js App Router)
LAYOUT_FILE="app/layout.tsx"
if [ ! -f "$LAYOUT_FILE" ]; then
  mkdir -p app
  cat > "$LAYOUT_FILE" <<'LAY'
import './styles/global.scss';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Wallet Recovery',
  description: 'Ethical, watch-only wallet recovery toolkit',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
LAY
else
  # inject import if missing
  grep -q "import './styles/global.scss'" "$LAYOUT_FILE" || \
    sed -i.bak "1i import './styles/global.scss';" "$LAYOUT_FILE"
fi

# Home page with parallax hero + mobile fallback <style>
PAGE_FILE="app/page.tsx"
mkdir -p app
cat > "$PAGE_FILE" <<'PAGE'
export default function Home() {
  return (
    <main>
      <section className="parallax">
        <div className="card container">
          <h1>Wallet Recovery</h1>
          <p>Watch-only, ethical scanning. No sweeping. Recovery only.</p>
          <a className="btn" href="#login">Login</a>
        </div>
      </section>
      <style jsx global>{`
        /* Mobile fallback: disable fixed attachment */
        @media (max-width: 768px) {
          .parallax { background-attachment: scroll; }
        }
      `}</style>
      <section className="container" style={{paddingBottom:'3rem'}}>
        <h2>Purpose, Ethics & Safe Use</h2>
        <p>Use this tool only to recover wallets you rightfully own or are explicitly authorized to help recover.</p>
      </section>
    </main>
  );
}
PAGE

# Provide a placeholder parallax image if none exists
if [ ! -f "public/parallax.jpg" ]; then
  mkdir -p public
  # tiny gradient PNG as placeholder masquerading as .jpg
  printf '\211PNG\r\n\032\n' > public/parallax.jpg 2>/dev/null || true
fi

echo "Building to validate SCSS…"
npm run build >/dev/null

echo "init_step_two_c complete."
