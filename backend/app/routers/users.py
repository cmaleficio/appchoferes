"""Admin endpoints for user management."""

from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from datetime import datetime

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.security import get_password_hash
from ..core.logger import create_log_entry
from ..models import User
from ..schemas.users import UserBase, UserCreate

router = APIRouter()

@router.get("/users", response_model=list[UserBase])
async def list_users(
    include_inactive: Optional[bool] = Query(False),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(User)
    if not include_inactive:
        stmt = stmt.where(User.is_active == True)
    result = await db.execute(stmt)
    users = result.scalars().all()
    return [UserBase.from_orm(u) for u in users]

@router.get("/users/me", response_model=UserBase)
async def get_current_user_info(
    current_user = Depends(get_current_user),
):
    return UserBase.from_orm(current_user)

@router.post("/users", response_model=UserBase, status_code=status.HTTP_201_CREATED)
async def create_user(
    payload: UserCreate,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    user = User(
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
        role=payload.role,
        name=payload.name,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "create", "user", user.id, f"Created user {user.email} ({user.role})", ip)
    return UserBase.from_orm(user)

@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot disable yourself")
    user.is_active = False
    user.disabled_at = datetime.utcnow()
    await db.commit()
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "disable", "user", user.id, f"Disabled user {user.email}", ip)
    return {"detail": "User disabled", "user_id": user_id}
