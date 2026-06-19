"""Schemas for user‑related data."""

from pydantic import BaseModel

class UserBase(BaseModel):
    id: int
    email: str
    role: str

    class Config:
        from_attributes = True

class UserWithBudget(UserBase):
    budget: float | None = None
