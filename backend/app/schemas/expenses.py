"""Pydantic schemas for expense endpoints."""

from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field

class ExpenseCategory(str, Enum):
    peaje = "peaje"
    hotel = "hotel"
    gasolina = "gasolina"
    otros = "otros"

class ExpenseBase(BaseModel):
    category: ExpenseCategory
    amount: float
    description: Optional[str] = None
    is_multiple_tolls: Optional[bool] = None
    toll_count: Optional[int] = None

class ExpenseCreate(ExpenseBase):
    pass

class ExpenseEdit(ExpenseBase):
    pass

class ExpenseResponse(ExpenseBase):
    id: int
    user_id: int

    class Config:
        orm_mode = True

class ExpenseEditRequestCreate(BaseModel):
    expense_id: int
    reason: str = Field(..., alias="motivo")

class ExpenseEditRequestResponse(BaseModel):
    id: int
    expense_id: int
    user_id: int
    reason: str
    status: str
    created_at: str

    class Config:
        orm_mode = True
