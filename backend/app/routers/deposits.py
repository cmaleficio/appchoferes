"""Deposit management endpoints for admin."""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.logger import create_log_entry
from ..models import Deposit, User
from ..schemas.deposits import DepositCreate, DepositResponse

router = APIRouter()


@router.get("/deposits", response_model=list[DepositResponse])
async def list_deposits(
    user_id: Optional[int] = Query(None),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(Deposit).order_by(desc(Deposit.created_at))
    if user_id:
        stmt = stmt.where(Deposit.user_id == user_id)
    result = await db.execute(stmt)
    deposits = result.scalars().all()
    return [DepositResponse.from_orm(d) for d in deposits]


@router.get("/deposits/my", response_model=list[DepositResponse])
async def list_my_deposits(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Deposit).where(Deposit.user_id == current_user.id).order_by(desc(Deposit.created_at))
    result = await db.execute(stmt)
    deposits = result.scalars().all()
    return [DepositResponse.from_orm(d) for d in deposits]


@router.post("/deposits", response_model=DepositResponse, status_code=status.HTTP_201_CREATED)
async def create_deposit(
    payload: DepositCreate,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    user_result = await db.execute(select(User).where(User.id == payload.user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    deposit = Deposit(
        user_id=payload.user_id,
        amount=payload.amount,
        amount_bs=payload.amount_bs,
        exchange_rate=payload.exchange_rate,
        description=payload.description,
    )
    db.add(deposit)
    await db.commit()
    await db.refresh(deposit)
    ip = request.client.host if request.client else None
    details = f"Deposit ${payload.amount:.2f} USD to user {user.email}"
    if payload.amount_bs and payload.exchange_rate:
        details += f" | Bs.{payload.amount_bs:.2f} @ tasa {payload.exchange_rate:.2f}"
    await create_log_entry(db, current_user.id, "create", "deposit", deposit.id, details, ip)
    return DepositResponse.from_orm(deposit)
