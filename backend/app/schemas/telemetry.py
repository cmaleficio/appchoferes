"""Pydantic schema for telemetry track points."""

from pydantic import BaseModel
from typing import List

class TrackPoint(BaseModel):
    latitude: float
    longitude: float
    battery_level: float
    recorded_at: str | None = None  # optional; server can set now

class TelemetryBatch(BaseModel):
    user_id: int
    route_id: int
    points: List[TrackPoint]
