"""Deposit management endpoints for admin."""

from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.logger import create_log_entry
from ..models import Deposit, ExchangeRate, User
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
    # Auto-calculate missing values using today's exchange rate
    today = date.today()
    if deposit.amount > 0:
        if deposit.amount_bs is None and deposit.exchange_rate is not None:
            deposit.amount_bs = round(deposit.amount * deposit.exchange_rate, 2)
        elif deposit.amount_bs is not None and deposit.exchange_rate is None:
            deposit.exchange_rate = round(deposit.amount_bs / deposit.amount, 2)
        elif deposit.amount_bs is None and deposit.exchange_rate is None:
            rate_result = await db.execute(
                select(ExchangeRate).where(ExchangeRate.date == today).order_by(desc(ExchangeRate.created_at))
            )
            rate_row = rate_result.scalar_one_or_none()
            if rate_row:
                deposit.exchange_rate = rate_row.rate
                deposit.amount_bs = round(deposit.amount * rate_row.rate, 2)
    elif deposit.amount_bs and deposit.amount_bs > 0:
        if deposit.exchange_rate is not None:
            deposit.amount = round(deposit.amount_bs / deposit.exchange_rate, 2)
        else:
            rate_result = await db.execute(
                select(ExchangeRate).where(ExchangeRate.date == today).order_by(desc(ExchangeRate.created_at))
            )
            rate_row = rate_result.scalar_one_or_none()
            if rate_row:
                deposit.exchange_rate = rate_row.rate
                deposit.amount = round(deposit.amount_bs / rate_row.rate, 2)
    db.add(deposit)
    await db.commit()
    await db.refresh(deposit)
    ip = request.client.host if request.client else None
    details = f"Deposit ${deposit.amount:.2f} USD to user {user.email}"
    if deposit.amount_bs and deposit.exchange_rate:
        details += f" | Bs.{deposit.amount_bs:.2f} @ tasa {deposit.exchange_rate:.2f}"
    await create_log_entry(db, current_user.id, "create", "deposit", deposit.id, details, ip)
    return DepositResponse.from_orm(deposit)
