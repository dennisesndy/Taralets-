import asyncio
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.security import DUMMY_HASH, create_access_token, verify_password
from app.models.user import User
from app.models.otp import OTP
from app.schemas.auth import LoginRequest, TokenResponse, UserPublic, OTPVerifyRequest

from app.api.v1.registration_view import send_otp_email
from app.schemas.auth import ForgotPasswordRequest, ResetPasswordRequest
from app.core.security import hash_password
import random
from datetime import timedelta
from fastapi import BackgroundTasks

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/verify")
async def verify_otp(payload: OTPVerifyRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(OTP).where(OTP.email == payload.email, OTP.otp_code == payload.otp_code)
    )
    otp_record = result.scalar_one_or_none()

    if not otp_record or otp_record.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")

    user = await db.scalar(select(User).where(User.email == payload.email))
    if user:
        user.is_verified = True
        await db.execute(delete(OTP).where(OTP.email == payload.email))
        await db.commit()

    return {"message": "Email verified successfully. You can now log in."}

@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(User.email == payload.email))
    
    hash_to_check = user.password_hash if user else DUMMY_HASH
    valid = await asyncio.to_thread(verify_password, payload.password, hash_to_check)
    
    if user is None or not valid or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    if not user.is_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified. Please verify your OTP first."
        )

    token, expires_in = create_access_token(str(user.id))
    
    return TokenResponse(
        access_token=token,
        expires_in=expires_in,
        user=UserPublic.model_validate(user),
    )

@router.get("/me", response_model=UserPublic)
async def me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/forgot-password")
async def forgot_password(payload: ForgotPasswordRequest, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(User.email == payload.email))
    
    if user:
        # Generate 6-digit OTP
        otp_code = str(random.randint(100000, 999999))
        expires = datetime.now(timezone.utc) + timedelta(minutes=10)
        
        # Burahin ang lumang OTPs para sa email na ito
        await db.execute(delete(OTP).where(OTP.email == payload.email))
        
        # I-save ang bagong OTP
        db.add(OTP(email=payload.email, otp_code=otp_code, expires_at=expires))
        await db.commit()
        
        # I-send sa email
        background_tasks.add_task(send_otp_email, payload.email, otp_code)

    # Laging ibalik ito for security (para hindi ma-spam kung nag-e-exist ba ang email o hindi)
    return {"message": "If that email is registered, we have sent a reset OTP."}

@router.post("/reset-password")
async def reset_password(payload: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    # 1. I-verify ang OTP
    result = await db.execute(select(OTP).where(OTP.email == payload.email, OTP.otp_code == payload.otp_code))
    otp_record = result.scalar_one_or_none()
    
    if not otp_record or otp_record.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")
        
    # 2. I-update ang password
    user = await db.scalar(select(User).where(User.email == payload.email))
    if user:
        user.password_hash = await asyncio.to_thread(hash_password, payload.new_password)
        await db.execute(delete(OTP).where(OTP.email == payload.email))
        await db.commit()
        
    return {"message": "Password has been reset successfully."}