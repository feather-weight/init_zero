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
