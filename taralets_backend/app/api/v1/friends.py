import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.user import User
from app.models.user_friend import UserFriend
from app.models.friend_request import FriendRequest
from app.models.notification import Notification
from app.schemas.friends import AddFriendRequest, FriendRequestUser, FriendUser

router = APIRouter(prefix="/friends", tags=["Friends"])


def _friend_user(user: User) -> FriendUser:
    return FriendUser(id=user.id, full_name=user.full_name, email=user.email)


@router.get("", response_model=list[FriendUser])
async def list_friends(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(User)
        .join(UserFriend, UserFriend.friend_id == User.id)
        .where(UserFriend.user_id == current_user.id)
        .order_by(User.full_name, User.id)
    )
    return [_friend_user(user) for user in result.scalars().all()]


@router.get("/search", response_model=FriendUser)
async def search_friend(
    email: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    normalized_email = email.strip().lower()
    if not normalized_email:
        raise HTTPException(status_code=400, detail="Enter your friend's email.")

    user = await db.scalar(
        select(User).where(
            User.email == normalized_email,
            User.id != current_user.id,
            User.is_active.is_(True),
            User.is_verified.is_(True),
        )
    )
    if user is None:
        raise HTTPException(status_code=404, detail="No verified user found for that email.")
    return _friend_user(user)


@router.get("/requests/incoming", response_model=list[FriendRequestUser])
async def list_incoming_friend_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.sender_id)
        .where(
            FriendRequest.recipient_id == current_user.id,
            FriendRequest.status == "pending",
        )
        .order_by(FriendRequest.created_at.desc())
    )
    return [
        FriendRequestUser(
            request_id=request.id,
            user_id=sender.id,
            full_name=sender.full_name,
            email=sender.email,
            created_at=request.created_at,
        )
        for request, sender in rows.all()
    ]


@router.get("/requests/outgoing", response_model=list[FriendRequestUser])
async def list_outgoing_friend_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    rows = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.recipient_id)
        .where(
            FriendRequest.sender_id == current_user.id,
            FriendRequest.status == "pending",
        )
        .order_by(FriendRequest.created_at.desc())
    )
    return [
        FriendRequestUser(
            request_id=request.id,
            user_id=recipient.id,
            full_name=recipient.full_name,
            email=recipient.email,
            created_at=request.created_at,
        )
        for request, recipient in rows.all()
    ]


@router.post("", response_model=FriendUser, status_code=status.HTTP_201_CREATED)
async def add_friend(
    payload: AddFriendRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    friend = await db.scalar(
        select(User).where(
            User.email == str(payload.email).strip().lower(),
            User.id != current_user.id,
            User.is_active.is_(True),
            User.is_verified.is_(True),
        )
    )
    if friend is None:
        raise HTTPException(status_code=404, detail="No verified user found for that email.")

    already_friends = await db.scalar(
        select(UserFriend.id).where(
            UserFriend.user_id == current_user.id,
            UserFriend.friend_id == friend.id,
        )
    )
    if already_friends is not None:
        raise HTTPException(status_code=409, detail="You are already friends.")

    pending = await db.scalar(
        select(FriendRequest).where(
            FriendRequest.sender_id == current_user.id,
            FriendRequest.recipient_id == friend.id,
            FriendRequest.status == "pending",
        )
    )
    if pending is not None:
        raise HTTPException(status_code=409, detail="Friend request already sent.")

    incoming = await db.scalar(
        select(FriendRequest).where(
            FriendRequest.sender_id == friend.id,
            FriendRequest.recipient_id == current_user.id,
            FriendRequest.status == "pending",
        )
    )
    if incoming is not None:
        raise HTTPException(
            status_code=409,
            detail="This person already sent you a request. Check your notifications.",
        )

    request = FriendRequest(sender_id=current_user.id, recipient_id=friend.id)
    db.add(request)
    await db.flush()
    db.add(
        Notification(
            user_id=friend.id,
            actor_id=current_user.id,
            friend_request_id=request.id,
            type="friend_request",
            title="Friend request",
            message=f"{current_user.full_name} wants to be your friend.",
        )
    )
    await db.commit()

    return _friend_user(friend)


async def _respond_to_request(
    request_id: uuid.UUID,
    response_status: str,
    db: AsyncSession,
    current_user: User,
) -> dict[str, str]:
    request = await db.scalar(
        select(FriendRequest).where(
            FriendRequest.id == request_id,
            FriendRequest.recipient_id == current_user.id,
        )
    )
    if request is None:
        raise HTTPException(status_code=404, detail="Friend request not found.")
    if request.status != "pending":
        raise HTTPException(status_code=409, detail="This friend request was already handled.")

    request.status = response_status
    request.resolved_at = datetime.now(timezone.utc)
    if response_status == "accepted":
        db.add_all(
            [
                UserFriend(user_id=current_user.id, friend_id=request.sender_id),
                UserFriend(user_id=request.sender_id, friend_id=current_user.id),
            ]
        )

    await db.commit()
    return {"status": response_status}


@router.post("/requests/{request_id}/accept")
async def accept_friend_request(
    request_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await _respond_to_request(request_id, "accepted", db, current_user)


@router.post("/requests/{request_id}/decline")
async def decline_friend_request(
    request_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return await _respond_to_request(request_id, "declined", db, current_user)


@router.delete("/{friend_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_friend(
    friend_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    friend = await db.scalar(select(User.id).where(User.id == friend_id))
    if friend is None:
        raise HTTPException(status_code=404, detail="Friend not found.")

    await db.execute(
        delete(UserFriend).where(
            or_(
                (UserFriend.user_id == current_user.id)
                & (UserFriend.friend_id == friend),
                (UserFriend.user_id == friend)
                & (UserFriend.friend_id == current_user.id),
            )
        )
    )
    await db.commit()
