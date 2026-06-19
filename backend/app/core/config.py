"""Application configuration using Pydantic Settings."""

from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    """Settings for the FastAPI application.

    The database URL should be provided via the ``DATABASE_URL`` environment
    variable. Example for PostgreSQL:
    ``postgresql+asyncpg://user:password@localhost:5432/appchoferes``
    """

    DATABASE_URL: str = "sqlite+aiosqlite:///./test.db"
    JWT_SECRET_KEY: str = "change-me-secret"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 1 day

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
