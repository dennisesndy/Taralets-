import asyncio

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import generate_recovery_key, hash_password, hash_recovery_key
from app.models.user import User
from app.schemas.auth import RegisterRequest, RegisterResponse, UserPublic

router = APIRouter(prefix="/auth", tags=["Authentication"])

_TAKEN = HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Username is already taken.")


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = await db.scalar(select(User.id).where(User.username == payload.username))
    if existing is not None:
        raise _TAKEN

    recovery_key = generate_recovery_key()
    password_hash = await asyncio.to_thread(hash_password, payload.password)
    recovery_hash = await asyncio.to_thread(hash_recovery_key, recovery_key)

    user = User(
        full_name=payload.full_name,
        username=payload.username,
        password_hash=password_hash,
        recovery_key_hash=recovery_hash,
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError:  # race condition: may nauna sa'yo sa parehong username
        await db.rollback()
        raise _TAKEN
    await db.refresh(user)

    return RegisterResponse(
        user=UserPublic.model_validate(user),
        recovery_key=recovery_key,
        message="Account created. Save your recovery key now - it will not be shown again.",
    )