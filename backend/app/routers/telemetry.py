"""Telemetry router handling batch tracking points."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import RouteTrack
from ..schemas.telemetry import TelemetryBatch, TrackPoint

router = APIRouter()

@router.post("/track", status_code=status.HTTP_201_CREATED)
async def receive_track_batch(
    batch: TelemetryBatch,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Ensure the user matches token (or admin can post for others)
    if current_user.role != "admin" and current_user.id != batch.user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User mismatch")

    # Build list of ORM objects
    track_objects = [
        RouteTrack(
            user_id=batch.user_id,
            route_id=batch.route_id,
            latitude=pt.latitude,
            longitude=pt.longitude,
            battery_level=pt.battery_level,
        )
        for pt in batch.points
    ]
    db.add_all(track_objects)
    await db.commit()
    return {"inserted": len(track_objects)}
