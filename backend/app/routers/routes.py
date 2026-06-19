"""Route and telemetry track browsing endpoints for admin."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import Route, RouteTrack
from ..schemas.routes import RouteResponse, TrackPointResponse

router = APIRouter()

@router.get("/routes", response_model=list[RouteResponse])
async def list_routes(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    result = await db.execute(select(Route))
    routes = result.scalars().all()
    return [RouteResponse.from_orm(r) for r in routes]

@router.get("/routes/{route_id}/tracks", response_model=list[TrackPointResponse])
async def get_route_tracks(
    route_id: int,
    user_id: Optional[int] = Query(None),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(RouteTrack).where(RouteTrack.route_id == route_id).order_by(RouteTrack.recorded_at)
    if user_id:
        stmt = stmt.where(RouteTrack.user_id == user_id)
    result = await db.execute(stmt)
    tracks = result.scalars().all()
    return [TrackPointResponse.from_orm(t) for t in tracks]
