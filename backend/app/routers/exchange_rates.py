"""Exchange rate management endpoints for admin."""

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.logger import create_log_entry
from ..core.bcv_scraper import fetch_bcv_rate
from ..models import ExchangeRate
from ..schemas.exchange_rates import ExchangeRateCreate, ExchangeRateResponse

router = APIRouter()


@router.get("/exchange-rates", response_model=list[ExchangeRateResponse])
async def list_exchange_rates(
    limit: int = Query(30, ge=1, le=365),
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(ExchangeRate).order_by(desc(ExchangeRate.date)).limit(limit)
    result = await db.execute(stmt)
    rates = result.scalars().all()
    return [ExchangeRateResponse.from_orm(r) for r in rates]


@router.post("/exchange-rates", response_model=ExchangeRateResponse, status_code=status.HTTP_201_CREATED)
async def create_exchange_rate(
    payload: ExchangeRateCreate,
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")

    from datetime import date as date_type
    today = date_type.today()
    if payload.date != today:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Only today's date ({today}) is allowed. Got: {payload.date}",
        )

    # Check for existing rate on this date
    existing = await db.execute(select(ExchangeRate).where(ExchangeRate.date == payload.date))
    existing_rate = existing.scalar_one_or_none()
    if existing_rate:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Rate already exists for {payload.date}: Bs.{existing_rate.rate}",
        )

    rate = ExchangeRate(date=payload.date, rate=payload.rate, source=payload.source)
    db.add(rate)
    await db.commit()
    await db.refresh(rate)
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "create", "exchange_rate", rate.id, f"Rate: Bs.{payload.rate}/USD on {payload.date}", ip)
    return ExchangeRateResponse.from_orm(rate)


@router.get("/exchange-rates/latest")
async def get_latest_rate(
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")
    stmt = select(ExchangeRate).order_by(desc(ExchangeRate.date)).limit(1)
    result = await db.execute(stmt)
    rate = result.scalar_one_or_none()
    if not rate:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No exchange rates found")
    return ExchangeRateResponse.from_orm(rate)


@router.post("/exchange-rates/bcv")
async def scrape_bcv_rate(
    request: Request,
    current_user = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Scrape BCV website, save rate for today (or upsert if exists)."""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin privileges required")

    data = await fetch_bcv_rate()
    if data.get("error") or data["rate"] is None or data["date"] is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=data.get("error", "Failed to fetch BCV rate"),
        )

    from datetime import date as date_type
    rate_date = date_type.fromisoformat(data["date"])

    # Check if rate already exists for this date → update it
    existing = await db.execute(select(ExchangeRate).where(ExchangeRate.date == rate_date))
    existing_rate = existing.scalar_one_or_none()

    if existing_rate:
        existing_rate.rate = data["rate"]
        existing_rate.source = "bcv"
        await db.commit()
        await db.refresh(existing_rate)
        ip = request.client.host if request.client else None
        await create_log_entry(db, current_user.id, "update", "exchange_rate", existing_rate.id, f"BCV rate updated: Bs.{data['rate']}/USD", ip)
        return {
            "detail": "Rate updated from BCV",
            "rate": data["rate"],
            "date": data["date"],
            "source": "bcv",
        }

    rate = ExchangeRate(date=rate_date, rate=data["rate"], source="bcv")
    db.add(rate)
    await db.commit()
    await db.refresh(rate)
    ip = request.client.host if request.client else None
    await create_log_entry(db, current_user.id, "create", "exchange_rate", rate.id, f"BCV rate: Bs.{data['rate']}/USD", ip)
    return {
        "detail": "Rate saved from BCV",
        "rate": data["rate"],
        "date": data["date"],
        "source": "bcv",
    }
