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
