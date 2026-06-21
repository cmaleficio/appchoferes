"""Telemetry router handling batch tracking points."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, select as sel, and_, cast, Date
from typing import Optional
from datetime import date as date_type

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import Expense, RouteTrack, User
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


@router.get("/summary")
async def telemetry_summary(
    user_id: Optional[int] = None,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")

    from math import radians, sin, cos, sqrt, asin

    def haversine(lat1, lon1, lat2, lon2):
        R = 6371
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))
        return R * c

    stmt = sel(RouteTrack).order_by(RouteTrack.user_id, RouteTrack.recorded_at)
    if user_id:
        stmt = stmt.where(RouteTrack.user_id == user_id)
    result = await db.execute(stmt)
    tracks = result.scalars().all()

    user_distances = {}
    user_battery = {}
    for t in tracks:
        uid = t.user_id
        if uid not in user_distances:
            user_distances[uid] = 0.0
            user_battery[uid] = {"min": 100, "max": 0, "latest": 100, "points": 0}
        user_battery[uid]["min"] = min(user_battery[uid]["min"], t.battery_level or 0)
        user_battery[uid]["max"] = max(user_battery[uid]["max"], t.battery_level or 0)
        user_battery[uid]["latest"] = t.battery_level or 0
        user_battery[uid]["points"] += 1

    tracks_sorted = sorted(tracks, key=lambda t: (t.user_id, t.recorded_at or t.id))
    prev = None
    for t in tracks_sorted:
        if prev is not None and prev.user_id == t.user_id:
            user_distances[t.user_id] += haversine(prev.latitude, prev.longitude, t.latitude, t.longitude)
        prev = t

    result_list = []
    for uid in user_distances:
        user_result = await db.execute(sel(User).where(User.id == uid))
        user = user_result.scalar_one_or_none()
        result_list.append({
            "user_id": uid,
            "user_email": user.email if user else f"user_{uid}",
            "total_km": round(user_distances[uid], 2),
            "battery": user_battery.get(uid, {}),
        })

    return result_list


@router.get("/expense-vs-distance")
async def expense_vs_distance(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")

    from math import radians, sin, cos, sqrt, asin

    def haversine(lat1, lon1, lat2, lon2):
        R = 6371
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)
        a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))
        return R * c

    # Get all users
    users_result = await db.execute(sel(User))
    users = users_result.scalars().all()

    result = []
    for user in users:
        # Total expenses for user
        exp_stmt = sel(func.coalesce(func.sum(Expense.amount), 0)).where(Expense.user_id == user.id)
        exp_result = await db.execute(exp_stmt)
        total_expenses = exp_result.scalar()

        # Get track points for user to calculate distance
        tracks_stmt = sel(RouteTrack).where(RouteTrack.user_id == user.id).order_by(RouteTrack.recorded_at)
        tracks_result = await db.execute(tracks_stmt)
        tracks = tracks_result.scalars().all()

        total_km = 0.0
        prev = None
        for t in tracks:
            if prev is not None:
                total_km += haversine(prev.latitude, prev.longitude, t.latitude, t.longitude)
            prev = t

        result.append({
            "user_id": user.id,
            "user_email": user.email or f"user_{user.id}",
            "user_name": user.name or user.email,
            "total_expenses_usd": round(total_expenses, 2),
            "total_km": round(total_km, 2),
        })

    return result


@router.get("/tracks-by-date")
async def tracks_by_date(
    user_id: int = Query(...),
    date: str = Query(...),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")

    try:
        target_date = date_type.fromisoformat(date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    stmt = (
        sel(RouteTrack)
        .where(
            and_(
                RouteTrack.user_id == user_id,
                cast(RouteTrack.recorded_at, Date) == target_date,
            )
        )
        .order_by(RouteTrack.recorded_at)
    )
    result = await db.execute(stmt)
    tracks = result.scalars().all()

    user_result = await db.execute(sel(User).where(User.id == user_id))
    user = user_result.scalar_one_or_none()

    return {
        "user_id": user_id,
        "user_name": user.name if user else None,
        "user_email": user.email if user else None,
        "date": date,
        "points": [
            {
                "id": t.id,
                "latitude": t.latitude,
                "longitude": t.longitude,
                "battery_level": t.battery_level,
                "recorded_at": str(t.recorded_at) if t.recorded_at else None,
            }
            for t in tracks
        ],
        "total_points": len(tracks),
    }


@router.get("/latest-locations")
async def latest_locations(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin privileges required")

    # Get all active drivers
    users_result = await db.execute(sel(User).where(User.role == "driver", User.is_active == True))
    users = users_result.scalars().all()

    result = []
    for u in users:
        track_stmt = (
            sel(RouteTrack)
            .where(RouteTrack.user_id == u.id)
            .order_by(RouteTrack.recorded_at.desc())
            .limit(1)
        )
        track_result = await db.execute(track_stmt)
        track = track_result.scalar_one_or_none()
        if track is None:
            continue

        result.append({
            "user_id": u.id,
            "user_name": u.name or u.email,
            "user_email": u.email,
            "latitude": track.latitude,
            "longitude": track.longitude,
            "battery_level": track.battery_level,
            "last_seen": str(track.recorded_at) if track.recorded_at else None,
        })

    return result
