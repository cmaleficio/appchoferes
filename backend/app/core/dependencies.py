"""FastAPI dependencies for authentication and DB session."""

from fastapi import Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .database import get_db
from .security import decode_access_token

async def get_current_user(request: Request, db: AsyncSession = Depends(get_db)):
    """Extracts user info from JWT provided in ``Authorization: Bearer <token>``.
    Returns the ORM ``User`` instance.
    """
    auth: str | None = request.headers.get("Authorization")
    if not auth or not auth.lower().startswith("bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authentication token")
    token = auth.split(" ", 1)[1]
    try:
        payload = decode_access_token(token)
        user_id: int = int(payload.get("sub"))
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    # fetch user
    from ..models import User  # local import to avoid circular
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user

