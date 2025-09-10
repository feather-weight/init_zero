#!/usr/bin/env bash
set -euo pipefail

# Locate Next.js app root (mirrors step_two_b logic, simplified)
detect_next_dir() {
  for d in ./frontend ./apps/frontend ./apps/web ./packages/frontend ./packages/web .; do
    if [ -f "$d/package.json" ] && \
       grep -q '"next"' "$d/package.json" && \
       { [ -d "$d/app" ] || [ -d "$d/pages" ]; }; then
      echo "$d"; return 0
    fi
  done
  return 1
}
NEXT_DIR="$(detect_next_dir)"
if [ -z "${NEXT_DIR:-}" ]; then
  echo "❌ No Next.js app found (needs package.json with 'next' AND app/ or pages/)" >&2
  exit 1
fi
echo "➜ Operating in ${NEXT_DIR}"

# Choose router mode to avoid conflicts: prefer existing Pages Router if present
ROUTER="pages"
if [ -f "${NEXT_DIR}/pages/index.tsx" ] || [ -f "${NEXT_DIR}/pages/index.jsx" ]; then
  ROUTER="pages"
elif [ -f "${NEXT_DIR}/app/layout.tsx" ] || [ -f "${NEXT_DIR}/app/page.tsx" ]; then
  ROUTER="app"
fi
echo "➜ Detected router: ${ROUTER}"

# If Pages Router is selected but an App Router exists for root, back it up to avoid conflicts
if [ "$ROUTER" = "pages" ] && [ -d "${NEXT_DIR}/app" ]; then
  if [ -f "${NEXT_DIR}/app/page.tsx" ] || [ -f "${NEXT_DIR}/app/page.jsx" ]; then
    BK_DIR="${NEXT_DIR}/app.bak_step_two_c_$(date +%s)"
    echo "➜ Backing up conflicting app/ to ${BK_DIR}"
    mv "${NEXT_DIR}/app" "$BK_DIR"
  fi
fi

# Pre-reqs: ensure sass is available for SCSS
if ! grep -q '"sass"' "${NEXT_DIR}/package.json"; then
  echo "➜ Adding sass to devDependencies…"
  ( cd "${NEXT_DIR}" && npm pkg set devDependencies.sass="^1.77.0" >/dev/null && npm_config_production=false npm install --no-audit --progress=false )
fi

# SCSS structure
mkdir -p "${NEXT_DIR}/styles"

# variables
cat > "${NEXT_DIR}/styles/_variables.scss" <<'VARS'
$brand: #0ea5e9;
$bg-dark: #0b1220;
$text: #e5eefb;
$radius: 16px;
VARS

# mixins
cat > "${NEXT_DIR}/styles/_mixins.scss" <<'MIX'
@use 'variables' as *;

@mixin glass() {
  background: rgba(255,255,255,0.06);
  backdrop-filter: blur(6px);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: $radius;
}
MIX

# global (import order: variables → mixins → rest)
cat > "${NEXT_DIR}/styles/global.scss" <<'GLOBAL'
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

if [ "$ROUTER" = "app" ]; then
  # Ensure root layout imports global.scss (App Router)
  LAYOUT_FILE="${NEXT_DIR}/app/layout.tsx"
  if [ ! -f "$LAYOUT_FILE" ]; then
    mkdir -p "${NEXT_DIR}/app"
    cat > "$LAYOUT_FILE" <<'LAY'
import '../styles/global.scss';
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
    if ! grep -q "import '../styles/global.scss'" "$LAYOUT_FILE"; then
      tmp="$(mktemp)"; { echo "import '../styles/global.scss';"; cat "$LAYOUT_FILE"; } > "$tmp" && mv "$tmp" "$LAYOUT_FILE"
    fi
  fi

  # Home page (App Router)
  PAGE_FILE="${NEXT_DIR}/app/page.tsx"
  mkdir -p "${NEXT_DIR}/app"
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
else
  # Pages Router: ensure _app.tsx imports global.scss
  APP_FILE="${NEXT_DIR}/pages/_app.tsx"
  mkdir -p "${NEXT_DIR}/pages"
  if [ ! -f "$APP_FILE" ]; then
    cat > "$APP_FILE" <<'APP'
import '../styles/global.scss';
import type { AppProps } from 'next/app';

export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />;
}
APP
  else
    if ! grep -q "import '../styles/global.scss'" "$APP_FILE"; then
      tmp="$(mktemp)"; { echo "import '../styles/global.scss';"; cat "$APP_FILE"; } > "$tmp" && mv "$tmp" "$APP_FILE"
    fi
  fi
fi

# Provide a placeholder parallax image if none exists
if [ ! -f "${NEXT_DIR}/public/parallax.jpg" ]; then
  mkdir -p "${NEXT_DIR}/public"
  # tiny gradient PNG as placeholder masquerading as .jpg
  printf '\211PNG\r\n\032\n' > "${NEXT_DIR}/public/parallax.jpg" 2>/dev/null || true
fi

echo "➜ Building to validate SCSS in ${NEXT_DIR}…"
( cd "${NEXT_DIR}" && npm_config_production=false npm run -s build >/dev/null )

echo "init_step_two_c complete."
