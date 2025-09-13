import os
from motor.motor_asyncio import AsyncIOMotorClient

_client = None


def get_client() -> AsyncIOMotorClient:
    global _client
    if _client is None:
        uri = (
            os.getenv("MDB_URI")
            or os.getenv("MONGO_URI")
            or "mongodb://localhost:27017"
        )
        _client = AsyncIOMotorClient(uri)
    return _client


def get_db():
    name = (
        os.getenv("MDB_DB")
        or os.getenv("MONGO_DB")
        or os.getenv("MONGO_DB_NAME")
        or "app"
    )
    return get_client()[name]
