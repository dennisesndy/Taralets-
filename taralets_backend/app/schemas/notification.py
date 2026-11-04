import uuid
from datetime import datetime

from pydantic import BaseModel


class NotificationPublic(BaseModel):
    id: uuid.UUID
    type: str
    title: str
    message: str
    created_at: datetime
    actor_id: uuid.UUID | None = None
    friend_request_id: uuid.UUID | None = None
    trip_join_request_id: uuid.UUID | None = None
    trip_id: str | None = None
    request_status: str | None = None
    actionable: bool = False
