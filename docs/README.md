# Step Zero Monorepo

This repository contains a Next.js frontend and a FastAPI backend, wired together with Docker Compose and MongoDB.

## Structure
- `frontend/`: Next.js (TypeScript)
- `backend/`: FastAPI service
- `scripts/`: Local automation helpers
- `docs/`: Design and setup notes
- Root: `docker-compose.yml`, service Dockerfiles, `.env`

## Development

Docker (recommended):

```
docker compose up --build
```

Local dev:

```
# Backend
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Frontend
cd frontend
npm install
npm run dev
```

## Tests
- Frontend: `cd frontend && npm test`
- Backend: `cd backend && pytest`

## Env Vars
See `.env.example`. In dev, `.env` is read by Docker Compose.

Key vars:
- `BE_PORT`: backend port (default 8000)
- `FE_PORT`: frontend port (default 3000)
- `NEXT_PUBLIC_API_BASE`: frontend -> backend URL
- `MDB_URI`: MongoDB connection URI (e.g., `mongodb://mongodb:27017/app`)
- `CORS_ALLOW_ORIGINS`: comma-separated origins or `*`

