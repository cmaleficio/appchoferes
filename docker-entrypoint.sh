#!/bin/bash
set -e

echo "⏳ Creating database tables..."
python -c "
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from app.models import Base
from app.core.security import get_password_hash
from sqlalchemy import text

async def init():
    # Use the DATABASE_URL from environment
    import os
    db_url = os.environ['DATABASE_URL']
    engine = create_async_engine(db_url, echo=False)
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        print('✅ Tables created')
        
        # Seed admin if not exists
        result = await conn.execute(text("SELECT id FROM users WHERE email = 'admin@example.com'"))
        if not result.scalar_one_or_none():
            pw = get_password_hash('secret')
            await conn.execute(
                text(\"INSERT INTO users (email, hashed_password, role, name, is_active) VALUES (:e, :p, :r, :n, :a)\"),
                {'e': 'admin@example.com', 'p': pw, 'r': 'admin', 'n': 'Admin Principal', 'a': 1}
            )
            print('✅ Admin seeded: admin@example.com / secret')
        
        # Seed drivers if not exist
        for email in ['driver1@example.com', 'driver2@example.com']:
            result = await conn.execute(text(\"SELECT id FROM users WHERE email = :e\"), {'e': email})
            if not result.scalar_one_or_none():
                pw = get_password_hash('secret')
                await conn.execute(
                    text(\"INSERT INTO users (email, hashed_password, role, name, is_active) VALUES (:e, :p, :r, :n, :a)\"),
                    {'e': email, 'p': pw, 'r': 'driver', 'n': email.split('@')[0], 'a': 1}
                )
                print(f'✅ Driver seeded: {email} / secret')
    
    await engine.dispose()

asyncio.run(init())
"

echo "🚀 Starting server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
