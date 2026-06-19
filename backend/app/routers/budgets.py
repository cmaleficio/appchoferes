"""Budget management endpoints for admin."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import Budget, User
from ..schemas.budget import BudgetCreate, BudgetResponse

router = APIRouter()

@router.get("/budgets", response_model=list[BudgetResponse])
async def list_budgets(
    user_id: Optional[int] = Query(None),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(Budget)
    if user_id:
        stmt = stmt.where(Budget.user_id == user_id)
    result = await db.execute(stmt)
    budgets = result.scalars().all()
    return [BudgetResponse.from_orm(b) for b in budgets]

@router.post("/budgets", response_model=BudgetResponse, status_code=status.HTTP_201_CREATED)
async def create_budget(
    payload: BudgetCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    user_result = await db.execute(select(User).where(User.id == payload.user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    budget = Budget(
        user_id=payload.user_id,
        amount=payload.amount,
        period_start=payload.period_start,
        period_end=payload.period_end,
    )
    db.add(budget)
    await db.commit()
    await db.refresh(budget)
    return BudgetResponse.from_orm(budget)
