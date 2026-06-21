"""Pydantic schemas for expense endpoints."""

from enum import Enum
from typing import Optional, List
from pydantic import BaseModel, Field
from datetime import datetime

class ExpenseCategory(str, Enum):
    peaje = "peaje"
    hotel = "hotel"
    gasolina = "gasolina"
    otros = "otros"

class ExpenseBase(BaseModel):
    category: ExpenseCategory
    amount: float
    amount_bs: Optional[float] = None
    exchange_rate: Optional[float] = None
    description: Optional[str] = None
    is_multiple_tolls: Optional[bool] = None
    toll_count: Optional[int] = None

class ExpenseCreate(BaseModel):
    category: ExpenseCategory
    amount_bs: float
    exchange_rate: float
    description: Optional[str] = None
    receipt_image_path: Optional[str] = None
    audio_path: Optional[str] = None
    is_multiple_tolls: Optional[bool] = None
    toll_count: Optional[int] = None

class ExpenseEdit(ExpenseBase):
    pass

class ExpenseResponse(ExpenseBase):
    id: int
    user_id: int
    receipt_image_path: Optional[str] = None
    audio_path: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

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
        from_attributes = True
