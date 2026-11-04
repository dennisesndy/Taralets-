from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.friend_request import FriendRequest
from app.models.notification import Notification
from app.models.trip_join_request import TripJoinRequest
from app.models.user import User
from app.schemas.notification import NotificationPublic

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=list[NotificationPublic])
async def list_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = await db.execute(
        select(
            Notification,
            User.full_name,
            FriendRequest.status,
            TripJoinRequest.status,
            TripJoinRequest.trip_id,
        )
        .outerjoin(User, Notification.actor_id == User.id)
        .outerjoin(FriendRequest, Notification.friend_request_id == FriendRequest.id)
        .outerjoin(TripJoinRequest, Notification.trip_join_request_id == TripJoinRequest.id)
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(100)
    )
    notifications = []
    for notification, actor_name, friend_status, trip_request_status, trip_id in rows.all():
        message = notification.message
        if notification.type == "friend_request" and actor_name:
            message = f"{actor_name} wants to be your friend."
        actionable_status = friend_status if notification.friend_request_id else trip_request_status
        notifications.append(
            NotificationPublic(
                id=notification.id,
                type=notification.type,
                title=notification.title,
                message=message,
                created_at=notification.created_at,
                actor_id=notification.actor_id,
                friend_request_id=notification.friend_request_id,
                trip_join_request_id=notification.trip_join_request_id,
                trip_id=trip_id,
                request_status=actionable_status,
                actionable=actionable_status == "pending",
            )
        )
    return notifications
