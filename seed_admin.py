import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "backend")))
import asyncio
from app.core.database import AsyncSessionLocal, engine, Base
from app.core.security import get_password_hash
from app.models import User

async def main():
    async with AsyncSessionLocal() as session:
        # Create tables (in case not yet)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        # Check if admin exists
        result = await session.execute(
            User.__table__.select().where(User.email == "admin@example.com")
        )
        if result.first():
            print("Admin already exists")
            return
        admin = User(
            email="admin@example.com",
            hashed_password=get_password_hash("secret"),
            role="admin",
        )
        session.add(admin)
        await session.commit()
        print("Admin user created")

if __name__ == "__main__":
    asyncio.run(main())
