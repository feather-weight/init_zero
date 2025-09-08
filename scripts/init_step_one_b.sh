#!/usr/bin/env bash
set -Eeuo pipefail

dc() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

echo "==> Writing backend requirements (pinned)"
cat > backend/requirements.txt <<'REQ'
fastapi==0.111.0
uvicorn[standard]==0.30.0
motor==3.7.1
REQ

echo "==> Writing backend FastAPI app"
mkdir -p backend/app/api backend/app/core

cat > backend/app/api/routes_health.py <<'PY'
from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter()

@router.get("/health")
async def health():
    return {
        "status": "ok",
        "service": "backend",
        "ts": datetime.now(timezone.utc).isoformat()
    }
PY

cat > backend/app/core/config.py <<'PY'
import os

class Settings:
    PROJECT_NAME: str = os.getenv("PROJECT_NAME")
    API_BASE: str = os.getenv("API_BASE", "/api")
    MONGO_URI: str = os.getenv("MONGO_URI")
    MONGO_DB: str = os.getenv("MONGO_DB")
    JWT_SECRET: str = os.getenv("JWT_SECRET")
    MONGO_CONTAINER: str = os.getenv("MONGO_CONTAINER"
    )
settings = Settings()
PY

cat > backend/app/main.py <<'PY'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes_health import router as health_router

app = FastAPI(title="${PROJECT_NAME}", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # dev-friendly; tighten later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routes
app.include_router(health_router, prefix="")
PY

echo "==> Writing backend Dockerfile"
cat > backend/Dockerfile <<'DOCKER'
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /tmp/requirements.txt
RUN python -m pip install --upgrade pip && pip install -r /tmp/requirements.txt

# Copy code to /app/app so the import path is 'app'
COPY backend /app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER

echo "==> Extending docker-compose to include backend"
# Re-write compose with mongo + backend (idempotent for mongo block)
cat > docker-compose.yml <<'YML'
services:
  mongo:
    image: mongo:6.0
    container_name: ${MONGO_DB}
    restart: unless-stopped
    ports:
      - "27020:27020"
    volumes:
      - ./.data/mongo:/data/db
    command: ["--bind_ip_all"]

  backend:
    build:
      context: .
      dockerfile: backend/Dockerfile
    container_name: ${MONGO_CONTAINER}
    restart: unless-stopped
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - API_BASE=${API_BASE}
      - MONGO_URI=${MONGO_URI}
      - MDB_NAME=${MONGO_DB}
      - JWT_SECRET=${JWT_SECRET}
    ports:
      - "8000:8000"
    depends_on:
      - mongo

networks:
  default:
    name: recoverynet
YML

echo "==> Build & start backend"
dc build backend
dc up -d backend

echo "==> Verify /health"
# Try curl, fallback to wget
if command -v curl >/dev/null 2>&1; then
  curl -fsS http://localhost:8000/health | tee /tmp/BE_health.json
else
  wget -qO- http://localhost:8000/health | tee /tmp/BE_health.json
fi

echo "==> Generate step PDF"
cat > scripts/init_step_one_b_scaffold_BE_healthcheck.md <<'MD'
# Step 1(b): Scaffold Backend Healthcheck

This step adds a minimal **FastAPI** backend with a `/health` route, permissive CORS (dev), a pinned `requirements.txt`, and a small Python 3.12-slim Dockerfile. Docker Compose is extended to include the backend alongside Mongo.

- Outcome: `GET http://localhost:8000/health` returns `{"status":"ok",...}`.
- This aligns with the baseline scaffold in the 0→20 plan and stages the async, Mongo-ready scanner services for Infura/Tatum/Blockchair integrations in later sub-steps.

MD

docker run --rm -v "$PWD":/workdir pandoc/latex:3.1 \
  -o scripts/init_step_one_b_scaffold_BE_healthcheck.pdf \
  scripts/init_step_one_b_scaffold_BE_healthcheck.md || {
    echo "WARN: Pandoc container not available now. MD generated; you can convert later."
}

echo "==> Done: Step 1(b) backend scaffold is up."
