import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes_health import router as health_router


def get_cors_origins() -> list[str]:
    origins = os.getenv("CORS_ALLOW_ORIGINS", "*")
    if origins.strip() == "*":
        return ["*"]
    return [o.strip() for o in origins.split(",") if o.strip()]


app = FastAPI(title="Step Zero Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    return {"service": "backend", "status": "ok"}


app.include_router(health_router)

