import uuid
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class AddFriendRequest(BaseModel):
    email: EmailStr


class FriendUser(BaseModel):
    id: uuid.UUID
    full_name: str
    email: EmailStr


class FriendRequestUser(BaseModel):
    request_id: uuid.UUID
    user_id: uuid.UUID
    full_name: str
    email: EmailStr
    created_at: datetime
