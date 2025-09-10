# Repository Guidelines

## Project Structure & Module Organization
- `frontend/`: Next.js (TypeScript) app. Pages in `pages/`, UI in `components/`, assets in `public/`, styles in `styles/`.
- `backend/`: FastAPI service. Entry at `app/main.py`; routes in `app/api/` (e.g., `routes_health.py`).
- `scripts/`: Local automation and setup helpers.
- `docs/`: Design and setup notes.
- Root: `docker-compose.yml`, frontend and backend Dockerfiles, `.env` for configuration.

## Build, Test, and Development Commands
- Local dev (Docker): `docker compose up --build` — starts MongoDB, backend (Uvicorn), and frontend (Next.js). Ensure `.env` is populated.
- Frontend dev: `cd frontend && npm install && npm run dev` — runs Next.js on port 3000.
- Backend dev: `cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload` — runs FastAPI on port 8000.
- Lint (frontend): `cd frontend && npx next lint` — ESLint via Next.

## Coding Style & Naming Conventions
- TypeScript/React: 2-space indent; components in PascalCase (e.g., `ThemeToggle.tsx`); hooks/functions in camelCase; SCSS modules as `*.module.scss`.
- Python: PEP 8 (4-space indent); modules in snake_case; prefer type hints.
- Linting: Frontend uses ESLint (`eslint-config-next`). No backend linter configured yet.

## Testing Guidelines
- Current repo has no formal test suites. Recommended:
  - Frontend: Jest/React Testing Library; co-locate tests as `*.test.tsx`.
  - Backend: pytest; place tests under `backend/tests/`.
- Run examples (once added): `npm test` (frontend), `pytest` (backend). No coverage threshold enforced yet.

## Commit & Pull Request Guidelines
- History is inconsistent; adopt Conventional Commits:
  - Examples: `feat: add parallax tester`, `fix(api): handle CORS`, `chore(docs): update README`.
- PRs must include:
  - Clear description and scope; link related issues.
  - Screenshots/GIFs for UI changes.
  - Steps to verify (commands, URLs).
  - Note any env vars or migrations.

## Security & Configuration Tips
- Do not commit secrets. `.env` config drives `docker-compose.yml` (e.g., `BE_PORT`, `MDB_*`, `NEXT_PUBLIC_*`).
- Backend CORS is permissive for dev; tighten allowlists before release.
- Prefer `mongodb://` URIs via env; validate in the backend before use.

