"""Expense related endpoints, including edit request workflow."""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_, exists
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.logger import create_log_entry
from ..models import Expense, ExpenseRequest, ExpenseRequestStatus, User
from ..schemas.expenses import (
    ExpenseCreate,
    ExpenseEdit,
    ExpenseResponse,
    ExpenseEditRequestCreate,
    ExpenseEditRequestResponse,
)

router = APIRouter()

@router.get("/", response_model=list[ExpenseResponse])
async def list_expenses(
    user_id: Optional[int] = Query(None),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(Expense)
    if user_id:
        stmt = stmt.where(Expense.user_id == user_id)
    result = await db.execute(stmt)
    expenses = result.scalars().all()
    return [ExpenseResponse.from_orm(e) for e in expenses]


@router.get("/requests")
async def list_expense_requests(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(ExpenseRequest)
    if status_filter:
        stmt = stmt.where(ExpenseRequest.status == status_filter)
    stmt = stmt.order_by(ExpenseRequest.created_at.desc())
    result = await db.execute(stmt)
    requests = result.scalars().all()

    response = []
    for req in requests:
        user_result = await db.execute(select(User).where(User.id == req.user_id))
        user = user_result.scalar_one_or_none()
        expense_result = await db.execute(select(Expense).where(Expense.id == req.expense_id))
        expense = expense_result.scalar_one_or_none()
        response.append({
            "id": req.id,
            "expense_id": req.expense_id,
            "user_id": req.user_id,
            "user_email": user.email if user else None,
            "reason": req.reason,
            "status": req.status.value if hasattr(req.status, 'value') else req.status,
            "created_at": str(req.created_at) if req.created_at else None,
            "expense_amount": expense.amount if expense else None,
            "expense_category": expense.category.value if expense and hasattr(expense.category, 'value') else (expense.category if expense else None),
            "expense_description": expense.description if expense else None,
        })
    return response


@router.put("/requests/{request_id}/approve")
async def approve_expense_request(
    request_id: int,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    result = await db.execute(select(ExpenseRequest).where(ExpenseRequest.id == request_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if req.status != ExpenseRequestStatus.PENDIENTE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Request is not pending")
    req.status = ExpenseRequestStatus.APROBADO
    await db.commit()
    await db.refresh(req)
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "approve", "expense_request", req.id, f"Approved edit request for expense #{req.expense_id}", ip)
    return {"detail": "Request approved", "request_id": request_id, "expense_id": req.expense_id}


@router.put("/requests/{request_id}/reject")
async def reject_expense_request(
    request_id: int,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    result = await db.execute(select(ExpenseRequest).where(ExpenseRequest.id == request_id))
    req = result.scalar_one_or_none()
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found")
    if req.status != ExpenseRequestStatus.PENDIENTE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Request is not pending")
    req.status = ExpenseRequestStatus.RECHAZADO
    await db.commit()
    await db.refresh(req)
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "reject", "expense_request", req.id, f"Rejected edit request for expense #{req.expense_id}", ip)
    return {"detail": "Request rejected", "request_id": request_id}


@router.post("/request-edit", response_model=ExpenseEditRequestResponse)
async def request_expense_edit(
    req: ExpenseEditRequestCreate,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Expense).where(and_(Expense.id == req.expense_id, Expense.user_id == current_user.id))
    result = await db.execute(stmt)
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Expense not found for user")

    new_req = ExpenseRequest(
        expense_id=req.expense_id,
        user_id=current_user.id,
        reason=req.reason,
        status=ExpenseRequestStatus.PENDIENTE,
    )
    db.add(new_req)
    await db.commit()
    await db.refresh(new_req)
    return ExpenseEditRequestResponse.from_orm(new_req)


@router.put("/{expense_id}", response_model=ExpenseResponse)
async def admin_edit_expense(
    expense_id: int,
    payload: ExpenseEdit,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")

    approved_req_exists = await db.execute(
        select(ExpenseRequest)
        .where(
            and_(
                ExpenseRequest.expense_id == expense_id,
                ExpenseRequest.status == ExpenseRequestStatus.APROBADO,
            )
        )
    )
    approved_req = approved_req_exists.scalar_one_or_none()
    if not approved_req:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No approved edit request for this expense",
        )

    stmt = (
        update(Expense)
        .where(Expense.id == expense_id)
        .values(
            category=payload.category,
            amount=payload.amount,
            description=payload.description,
            is_multiple_tolls=payload.is_multiple_tolls,
            toll_count=payload.toll_count,
        )
        .execution_options(synchronize_session="fetch")
    )
    await db.execute(stmt)
    await db.commit()

    expense_stmt = select(Expense).where(Expense.id == expense_id)
    expense_res = await db.execute(expense_stmt)
    expense = expense_res.scalar_one()
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "edit", "expense", expense_id, f"Edited expense #{expense_id}: ${payload.amount}", ip)
    return ExpenseResponse.from_orm(expense)
