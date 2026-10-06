import asyncio
import random
import smtplib
import os
from datetime import datetime, timedelta, timezone
from email.message import EmailMessage

from dotenv import load_dotenv

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy import select, delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import hash_password
from app.models.user import User
from app.models.otp import OTP
from app.schemas.auth import RegisterRequest, RegisterResponse

load_dotenv()

router = APIRouter(prefix="/auth", tags=["Authentication"])

def send_otp_email(receiver_email: str, otp_code: str):
    sender_email = os.getenv("SENDER_EMAIL")
    sender_password = os.getenv("SENDER_PASSWORD")
    
    if not sender_email or not sender_password:
        print("Error: Hindi nabasa ang SENDER_EMAIL o SENDER_PASSWORD sa .env file.")
        return

    msg = EmailMessage()
    msg.set_content(f"Welcome to Taralets! Your verification code is: {otp_code}. It expires in 10 minutes.")
    msg["Subject"] = "Taralets - Email Verification"
    msg["From"] = sender_email
    msg["To"] = receiver_email

    try:
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.ehlo()
            server.starttls()
            server.login(sender_email, sender_password)
            server.send_message(msg)
            print(f"Success! OTP email sent to {receiver_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")

@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: RegisterRequest, background_tasks: BackgroundTasks, db: AsyncSession = Depends(get_db)):
    # 1. Check kung nasa database na ang user
    existing_user = await db.scalar(select(User).where(User.email == payload.email))
    
    password_hash = await asyncio.to_thread(hash_password, payload.password)

    if existing_user:
        if existing_user.is_verified:
            # Kung verified na, bawal na mag-register
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Email is already registered and verified.")
        else:
            # Kung HINDI PA verified, i-update ang details niya para maka-resend ng OTP
            existing_user.full_name = payload.full_name
            existing_user.phone_number = payload.phone_number
            existing_user.password_hash = password_hash
            
            # Burahin ang mga lumang OTP na nakatali sa email na ito
            await db.execute(delete(OTP).where(OTP.email == payload.email))
            user_to_use = existing_user
    else:
        # Kung bagong-bago ang email, gumawa ng bagong User
        user_to_use = User(
            full_name=payload.full_name,
            email=payload.email,
            phone_number=payload.phone_number,
            password_hash=password_hash,
            is_verified=False
        )
        db.add(user_to_use)

    try:
        await db.flush() 
    except IntegrityError:
        await db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Database conflict occurred.")

    # 2. Gumawa ng bagong OTP
    otp_code = str(random.randint(100000, 999999))
    expires = datetime.now(timezone.utc) + timedelta(minutes=10)
    
    otp_record = OTP(email=user_to_use.email, otp_code=otp_code, expires_at=expires)
    db.add(otp_record)
    
    await db.commit()
    
    # 3. I-send ang OTP
    background_tasks.add_task(send_otp_email, user_to_use.email, otp_code)

    return RegisterResponse(message="Account created. Please check your email for the OTP.")