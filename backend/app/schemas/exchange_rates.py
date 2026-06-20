"""Pydantic schemas for exchange rate management."""

from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional

class ExchangeRateCreate(BaseModel):
    date: date
    rate: float
    source: str = "manual"

class ExchangeRateResponse(BaseModel):
    id: int
    date: date
    rate: float
    source: str = "manual"
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
