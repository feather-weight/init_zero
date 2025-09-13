import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes_health import router as health_router
from app.api.routes_auth import router as auth_router
from app.api.routes_auth_pgp import router as auth_pgp_router

app = FastAPI(title="${PROJECT_NAME}", version="0.1.0")

# Allow CORS from configured frontend origin(s). Treat empty env values as unset.
origins_env = os.getenv("CORS_ORIGINS") or os.getenv("FRONTEND_BASE_URL") or "http://localhost:3000"
allow_origins = [o.strip() for o in origins_env.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routes
app.include_router(health_router, prefix="")
app.include_router(auth_router, prefix="")
app.include_router(auth_pgp_router, prefix="")
