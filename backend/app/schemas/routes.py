"""Pydantic schemas for route and telemetry track endpoints."""

from pydantic import BaseModel
from typing import Optional

class RouteResponse(BaseModel):
    id: int
    name: str
    start_location: Optional[str] = None
    end_location: Optional[str] = None

    class Config:
        from_attributes = True

class TrackPointResponse(BaseModel):
    id: int
    user_id: int
    route_id: int
    latitude: float
    longitude: float
    battery_level: float
    recorded_at: str

    class Config:
        from_attributes = True
