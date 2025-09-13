import os
from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
def health():
    mdb_uri = os.getenv("MDB_URI", "")
    mdb_uri_valid = mdb_uri.startswith("mongodb://") or mdb_uri.startswith("mongodb+srv://")
    return {
        "service": "backend",
        "status": "ok",
        "mongodb_uri_present": bool(mdb_uri),
        "mongodb_uri_valid": mdb_uri_valid,
    }

