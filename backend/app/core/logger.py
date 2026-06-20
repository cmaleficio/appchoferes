"""Logging helper to record user actions."""

from sqlalchemy.ext.asyncio import AsyncSession
from ..models import Log

async def create_log_entry(
    db: AsyncSession,
    user_id: int,
    action: str,
    resource: str,
    resource_id: int | None = None,
    details: str | None = None,
    ip_address: str | None = None,
) -> Log:
    entry = Log(
        user_id=user_id,
        action=action,
        resource=resource,
        resource_id=resource_id,
        details=details,
        ip_address=ip_address,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry
