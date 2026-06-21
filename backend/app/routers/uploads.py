"""Unified upload endpoint for expense + photo + audio + Whisper transcription."""

import os
import uuid
import subprocess
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from ..core.dependencies import get_current_user
from ..core.database import get_db
from ..core.logger import create_log_entry
from ..models import Expense

router = APIRouter()

UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@router.post("/upload", status_code=201)
async def upload_expense(
    request: Request,
    category: str = Form(...),
    amount_bs: float = Form(...),
    exchange_rate: float = Form(...),
    description: Optional[str] = Form(None),
    is_multiple_tolls: Optional[bool] = Form(None),
    toll_count: Optional[int] = Form(None),
    receipt_image: Optional[UploadFile] = File(None),
    audio_description: Optional[UploadFile] = File(None),
    current_user=Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Save receipt image
    image_path = None
    if receipt_image:
        ext = os.path.splitext(receipt_image.filename or "photo.jpg")[1] or ".jpg"
        fname = f"{uuid.uuid4().hex}{ext}"
        image_path = os.path.join(UPLOAD_DIR, fname)
        with open(image_path, "wb") as f:
            f.write(await receipt_image.read())

    # Save audio and transcribe
    audio_path = None
    transcribed_text = description
    if audio_description:
        ext = os.path.splitext(audio_description.filename or "audio.wav")[1] or ".wav"
        fname = f"{uuid.uuid4().hex}{ext}"
        audio_path = os.path.join(UPLOAD_DIR, fname)
        with open(audio_path, "wb") as f:
            f.write(await audio_description.read())
        try:
            result = subprocess.run(
                ["whisper", audio_path, "--output_dir", UPLOAD_DIR, "--language", "es"],
                capture_output=True,
                text=True,
                timeout=120,
            )
            txt_path = os.path.splitext(audio_path)[0] + ".txt"
            if os.path.exists(txt_path):
                with open(txt_path, "r") as tf:
                    transcribed = tf.read().strip()
                if transcribed:
                    transcribed_text = transcribed
        except Exception:
            pass

    # Create expense
    amount_usd = amount_bs / exchange_rate if exchange_rate > 0 else 0
    expense = Expense(
        user_id=current_user.id,
        category=category,
        amount=amount_usd,
        amount_bs=amount_bs,
        exchange_rate=exchange_rate,
        description=transcribed_text,
        receipt_image_path=image_path,
        audio_path=audio_path,
        is_multiple_tolls=is_multiple_tolls,
        toll_count=toll_count,
    )
    db.add(expense)
    await db.commit()
    await db.refresh(expense)
    ip = request.client.host if request.client else None
    await create_log_entry(
        db,
        current_user.id,
        "create",
        "expense",
        expense.id,
        f"Upload: Bs.{amount_bs:.2f} @ {exchange_rate:.2f} = ${amount_usd:.2f} - {category}",
        ip,
    )
    return {
        "id": expense.id,
        "amount": expense.amount,
        "amount_bs": expense.amount_bs,
        "exchange_rate": expense.exchange_rate,
        "description": expense.description,
        "category": expense.category,
        "receipt_image_path": expense.receipt_image_path,
        "audio_path": expense.audio_path,
    }
