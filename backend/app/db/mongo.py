import os
from motor.motor_asyncio import AsyncIOMotorClient

_client = None


def get_client() -> AsyncIOMotorClient:
    global _client
    if _client is None:
        uri = os.getenv("MDB_URI", "mongodb://localhost:27017")
        _client = AsyncIOMotorClient(uri)
    return _client


def get_db():
    name = os.getenv("MDB_DB", "app")
    return get_client()[name]

