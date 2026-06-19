"""Admin endpoints for user management."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import User
from ..schemas.users import UserBase

router = APIRouter()

@router.get("/users", response_model=list[UserBase])
async def list_users(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    result = await db.execute(select(User))
    users = result.scalars().all()
    return [UserBase.from_orm(u) for u in users]

@router.get("/users/me", response_model=UserBase)
async def get_current_user_info(
    current_user = Depends(get_current_user),
):
    return UserBase.from_orm(current_user)
