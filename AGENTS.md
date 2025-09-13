# Repository Guidelines

## Project Structure & Module Organization
- `frontend/` (Next.js + TypeScript): pages in `pages/`, shared UI in `components/`, assets in `public/`, styles in `styles/`. Unit tests co‑located as `*.test.tsx`.
- `backend/` (FastAPI): entry `app/main.py`; routes under `app/api/` (e.g., `routes_health.py`). Tests in `backend/tests/`.
- `scripts/`: local automation and setup helpers. `docs/`: design and setup notes.
- Root: `docker-compose.yml`, frontend and backend Dockerfiles, `.env` for configuration.

## Build, Test, and Development Commands
- Docker dev: `docker compose up --build` — builds and runs MongoDB, backend (Uvicorn), and frontend.
- Frontend dev: `cd frontend && npm install && npm run dev` — app at `http://localhost:3000`.
- Backend dev: `cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload` — API at `http://localhost:8000`.
- Lint (frontend): `cd frontend && npx next lint` — ESLint via `eslint-config-next`.
- Tests (frontend): `cd frontend && npm test`. Tests (backend): `cd backend && pytest`.

## Coding Style & Naming Conventions
- TypeScript/React: 2‑space indent; components in PascalCase (e.g., `ThemeToggle.tsx`); hooks/functions in camelCase; SCSS modules `*.module.scss`.
- Python: PEP 8, 4‑space indent; modules in `snake_case`; prefer type hints.
- Keep imports tidy; prefer small, focused components and functions.

## Testing Guidelines
- Frameworks: Jest + React Testing Library (frontend); pytest (backend).
- Location & names: frontend tests co‑located as `*.test.tsx`; backend tests in `backend/tests/`.
- Scope: components, hooks, API routes, and critical services. Keep tests deterministic; no coverage threshold enforced yet.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (e.g., `feat: add parallax tester`, `fix(api): handle CORS`, `chore(docs): update README`).
- Pull requests: provide description & scope, link issues, include screenshots/GIFs for UI changes, add verification steps (commands, URLs), and note any env vars or migrations.

## Security & Configuration Tips
- Never commit secrets. `.env` drives `docker-compose.yml` (e.g., `BE_PORT`, `MDB_*`, `NEXT_PUBLIC_*`).
- Use `mongodb://` URIs via env; validate in backend before use.
- CORS is permissive for development; restrict allowlists before release.

