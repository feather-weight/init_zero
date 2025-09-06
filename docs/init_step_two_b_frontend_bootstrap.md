# Step 2(b): Frontend (Next.js) Bootstrap with SCSS & Parallax

- Minimal Next.js app (TypeScript) with `/api/health`.
- SCSS wired via `sass` dependency and `globals.scss`.
- Reusable `<Parallax>` component and optional hero section gated by `NEXT_PUBLIC_PARALLAX`.
- Dockerized; uses env ports: `${FRONTEND_PORT}:${FRONTEND_INTERNAL_PORT}`.
- Includes a safety fix to ensure `frontend:` lives under `services:` and not under `networks:`.
- Pins ESLint to a version compatible with `eslint-config-next` (`8.57.0`) and uses `--legacy-peer-deps` to avoid peer dependency conflicts during npm install.
