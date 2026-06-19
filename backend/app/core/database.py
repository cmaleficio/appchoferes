"""SQLAlchemy async engine and session utilities."""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from .config import settings

# Create async engine using the DATABASE_URL from settings.
# For SQLite used in development we need ``aiosqlite`` driver.
engine = create_async_engine(settings.DATABASE_URL, echo=False, future=True)

# Async session factory
AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

Base = declarative_base()

async def get_db():
    """FastAPI dependency that yields an async DB session."""
    async with AsyncSessionLocal() as session:
        yield session
