import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "backend")))

import sys
from sqlalchemy import create_engine, inspect
from app.core.config import settings
# Use sync URL for inspection
sync_url = settings.DATABASE_URL.replace('+aiosqlite', '')
engine = create_engine(sync_url)
inspector = inspect(engine)
print('Tables:', inspector.get_table_names())
