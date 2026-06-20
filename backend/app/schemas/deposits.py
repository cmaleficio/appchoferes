"""Pydantic schemas for driver deposits."""

from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class DepositCreate(BaseModel):
    user_id: int
    amount: float
    amount_bs: Optional[float] = None
    exchange_rate: Optional[float] = None
    description: Optional[str] = None

class DepositResponse(BaseModel):
    id: int
    user_id: int
    amount: float
    amount_bs: Optional[float] = None
    exchange_rate: Optional[float] = None
    description: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
