"""Authentication router handling login and token issuance."""

from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..core.database import get_db
from ..core.security import verify_password, create_access_token
from ..models import User
from ..schemas.auth import UserLogin, Token

router = APIRouter()

@router.post("/login", response_model=Token)
async def login(user: UserLogin, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.email == user.email)
    result = await db.execute(stmt)
    db_user = result.scalar_one_or_none()
    if not db_user or not verify_password(user.password, db_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    access_token_expires = timedelta(minutes=60 * 24)
    access_token = create_access_token(
        data={"sub": str(db_user.id), "role": db_user.role}, expires_delta=access_token_expires
    )
    return Token(access_token=access_token)
