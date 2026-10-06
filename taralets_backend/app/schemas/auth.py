import re
import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field, field_validator, EmailStr

class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    phone_number: str | None = None
    password: str = Field(min_length=8, max_length=72)

    @field_validator("full_name")
    @classmethod
    def clean_name(cls, v: str) -> str:
        return " ".join(v.split())

    @field_validator("password")
    @classmethod
    def strong_enough(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password must be at most 72 bytes.")
        if not re.search(r"[A-Za-z]", v) or not re.search(r"\d", v):
            raise ValueError("Password must contain at least one letter and one number.")
        return v

class OTPVerifyRequest(BaseModel):
    email: EmailStr
    otp_code: str = Field(min_length=6, max_length=6)

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("email")
    @classmethod
    def normalize(cls, v: str) -> str:
        return v.strip().lower()

class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    full_name: str
    email: str
    is_verified: bool
    created_at: datetime

class RegisterResponse(BaseModel):
    message: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserPublic