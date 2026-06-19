"""Pydantic schemas for budgets and expense‑request updates."""

from pydantic import BaseModel
from datetime import datetime

class BudgetCreate(BaseModel):
    user_id: int
    amount: float
    period_start: datetime
    period_end: datetime

class BudgetResponse(BaseModel):
    id: int
    user_id: int
    amount: float
    period_start: datetime
    period_end: datetime

    class Config:
        from_attributes = True

class ExpenseRequestStatusUpdate(BaseModel):
    status: str  # expected values: 'pendiente', 'aprobado', 'rechazado'
