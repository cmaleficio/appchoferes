"""Schemas for user‑related data."""

from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    id: int
    email: str
    role: str
    name: Optional[str] = None
    is_active: bool = True
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class UserCreate(BaseModel):
    email: str
    password: str
    role: str = "driver"
    name: Optional[str] = None

class UserWithBudget(UserBase):
    budget: float | None = None
