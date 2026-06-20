"""Activity log endpoints for admin."""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..models import Log
from ..schemas.logs import LogResponse

router = APIRouter()

@router.get("/logs", response_model=list[LogResponse])
async def list_logs(
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
    user_id: Optional[int] = Query(None),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(Log).order_by(desc(Log.created_at)).offset(offset).limit(limit)
    if user_id:
        stmt = stmt.where(Log.user_id == user_id)
    result = await db.execute(stmt)
    logs = result.scalars().all()
    return [LogResponse.from_orm(l) for l in logs]
