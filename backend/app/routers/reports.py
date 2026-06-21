"""Report endpoint: filtered expenses + deposits by user and date range."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select as sel, and_
from typing import Optional
from datetime import date as date_type
from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import Expense, Deposit, User

router = APIRouter()

@router.get("/report")
async def get_report(
    user_id: int = Query(...),
    date_from: str = Query(...),
    date_to: str = Query(...),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")

    try:
        dfrom = date_type.fromisoformat(date_from)
        dto = date_type.fromisoformat(date_to)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    user_result = await db.execute(sel(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # Expenses
    exp_stmt = (
        sel(Expense)
        .where(
            and_(
                Expense.user_id == user_id,
                Expense.created_at >= dfrom,
                Expense.created_at < dto,
            )
        )
        .order_by(Expense.created_at)
    )
    exp_result = await db.execute(exp_stmt)
    expenses = exp_result.scalars().all()

    # Deposits
    dep_stmt = (
        sel(Deposit)
        .where(
            and_(
                Deposit.user_id == user_id,
                Deposit.created_at >= dfrom,
                Deposit.created_at < dto,
            )
        )
        .order_by(Deposit.created_at)
    )
    dep_result = await db.execute(dep_stmt)
    deposits = dep_result.scalars().all()

    return {
        "user_id": user_id,
        "user_name": user.name or user.email,
        "user_email": user.email,
        "date_from": date_from,
        "date_to": date_to,
        "expenses": [
            {
                "id": e.id,
                "category": e.category.value if hasattr(e.category, 'value') else e.category,
                "amount": e.amount,
                "amount_bs": e.amount_bs,
                "exchange_rate": e.exchange_rate,
                "description": e.description,
                "created_at": str(e.created_at) if e.created_at else None,
            }
            for e in expenses
        ],
        "deposits": [
            {
                "id": d.id,
                "amount": d.amount,
                "amount_bs": d.amount_bs,
                "exchange_rate": d.exchange_rate,
                "description": d.description,
                "created_at": str(d.created_at) if d.created_at else None,
            }
            for d in deposits
        ],
        "summary": {
            "total_expenses_usd": round(sum(e.amount for e in expenses), 2),
            "total_expenses_bs": round(sum(e.amount_bs or 0 for e in expenses), 2),
            "total_deposits_usd": round(sum(d.amount for d in deposits), 2),
            "total_deposits_bs": round(sum(d.amount_bs or 0 for d in deposits), 2),
            "count_expenses": len(expenses),
            "count_deposits": len(deposits),
        },
    }
