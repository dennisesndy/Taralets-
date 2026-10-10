
import random

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.trip import Trip, TripMember
from app.models.trip_member_preference import TripMemberPreference
from app.models.user import User
from app.schemas.profile import PreferenceSetupRequest
from app.schemas.trip import (
    CreateTripRequest,
    UpdateTripRequest,
    InviteMemberRequest,
    GroupPreferencesSchema,
)

router = APIRouter()



async def _serialize_trip(db: AsyncSession, trip: Trip) -> dict:
    members_result = await db.execute(
        select(TripMember, User)
        .join(User, TripMember.user_id == User.id)
        .where(TripMember.trip_id == trip.id)
    )

    member_rows = members_result.all()
    members_data = []

    # Get all member IDs first
    member_ids = [member.id for member, user in member_rows]

    # Fetch all member preferences in one query
    preferences_by_member_id = {}

    if member_ids:
        preferences_result = await db.execute(
            select(TripMemberPreference).where(
                TripMemberPreference.trip_member_id.in_(member_ids)
            )
        )

        preferences_by_member_id = {
            preference.trip_member_id: preference
            for preference in preferences_result.scalars().all()
        }

    # Build member data using the fetched preferences
    for member, user in member_rows:
        email_prefix = (
            user.email.split("@")[0]
            if user.email
            else "user"
        )
        display_name = user.full_name or email_prefix

        preference = preferences_by_member_id.get(member.id)

        preferences = []

        if preference:
            preferences.extend(preference.activity_tags or [])
            preferences.extend(preference.dietary_preferences or [])

            if preference.preferred_pace:
                preferences.append(preference.preferred_pace)

            preferences.extend(
                preference.accessibility_preferences or []
            )

            if preference.max_budget is not None:
                preferences.append(
                    f"₱{preference.max_budget:,.0f}"
                )

        members_data.append({
            "user_id": str(member.user_id),
            "username": email_prefix,
            "name": display_name,
            "is_leader": member.is_leader,
            "status": member.status,
            "preferences": preferences,
            "trip_preferences": {
                "activity_tags": (
                    preference.activity_tags or []
                    if preference else []
                ),
                "dietary_preferences": (
                    preference.dietary_preferences or []
                    if preference else []
                ),
                "max_budget": (
                    float(preference.max_budget)
                    if (
                        preference
                        and preference.max_budget is not None
                    )
                    else None
                ),
                "preferred_pace": (
                    preference.preferred_pace
                    if preference else None
                ),
                "accessibility_preferences": (
                    preference.accessibility_preferences or []
                    if preference else []
                ),
            },
        })

    return {
        "id": str(trip.id),
        "code": trip.code,
        "title": trip.title,
        "description": trip.description,
        "date": (
            trip.date.isoformat()
            if hasattr(trip.date, "isoformat")
            else str(trip.date)
        ),
        "date_label": trip.date_label,
        "long_date": trip.long_date,
        "meetup": trip.meetup,
        "meetup_full": trip.meetup_full,
        "arrival_target": trip.arrival_target,
        "wrap_up": trip.wrap_up,
        "latitude": trip.latitude,
        "longitude": trip.longitude,
        "status": trip.status,
        "spots_open": trip.spots_open,
        "on_way_count": trip.on_way_count,
        "leader_id": str(trip.leader_id),
        "group_preferences": trip.group_preferences or {},
        "members": members_data,
    }

@router.get("/me")
async def get_my_trips(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(TripMember).where(
            TripMember.user_id == current_user.id
        )
    )
    memberships = result.scalars().all()
    trip_ids = [membership.trip_id for membership in memberships]

    if not trip_ids:
        return []

    trips_result = await db.execute(
        select(Trip).where(Trip.id.in_(trip_ids))
    )
    trips = trips_result.scalars().all()

    return [
        await _serialize_trip(db, trip)
        for trip in trips
    ]


@router.get("/code/{code}")
async def find_trip_by_code(
    code: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Trip).where(Trip.code == code)
    )
    trip = result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Invalid room code",
        )

    if trip.status in ["completed", "cancelled"]:
        raise HTTPException(
            status_code=410,
            detail="Room code expired",
        )

    return await _serialize_trip(db, trip)


@router.post("/{code}/join")
async def join_trip(
    code: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Trip).where(Trip.code == code)
    )
    trip = result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Invalid room code",
        )

    member_result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip.id,
            TripMember.user_id == current_user.id,
        )
    )
    existing_member = member_result.scalars().first()

    if not existing_member:
        new_member = TripMember(
            trip_id=trip.id,
            user_id=current_user.id,
            status="notReady",
            is_leader=False,
        )
        db.add(new_member)
        await db.commit()

    return await _serialize_trip(db, trip)


@router.post("/{trip_id}/member-preferences")
async def save_member_preferences(
    trip_id: str,
    payload: PreferenceSetupRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await db.scalar(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == current_user.id,
        )
    )

    if not member:
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this trip",
        )

    existing = await db.scalar(
        select(TripMemberPreference).where(
            TripMemberPreference.trip_member_id == member.id
        )
    )

    if existing:
        existing.activity_tags = payload.activity_tags
        existing.dietary_preferences = payload.dietary_preferences
        existing.max_budget = payload.max_budget
        existing.preferred_pace = payload.preferred_pace
        existing.accessibility_preferences = (
            payload.accessibility_preferences
        )
    else:
        new_preferences = TripMemberPreference(
            trip_member_id=member.id,
            activity_tags=payload.activity_tags,
            dietary_preferences=payload.dietary_preferences,
            max_budget=payload.max_budget,
            preferred_pace=payload.preferred_pace,
            accessibility_preferences=(
                payload.accessibility_preferences
            ),
        )
        db.add(new_preferences)

    await db.commit()

    return {
        "message": "Trip preferences successfully saved",
    }


@router.post("")
async def create_trip(
    payload: CreateTripRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    code = payload.code

    existing = await db.execute(
        select(Trip).where(Trip.code == code)
    )

    if existing.scalars().first():
        letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"

        while True:
            head = "".join(
                random.choice(letters)
                for _ in range(4)
            )
            digits = str(random.randint(10, 99))
            code = f"{head}-{digits}"

            existing = await db.execute(
                select(Trip).where(Trip.code == code)
            )

            if not existing.scalars().first():
                break

    new_trip = Trip(
        code=code,
        title=payload.title,
        description=payload.description,
        date=payload.date,
        meetup=payload.meetup_name.split(",")[0],
        meetup_full=payload.meetup_name,
        arrival_target=payload.meetup_time,
        wrap_up=payload.wrap_up_time,
        latitude=payload.latitude,
        longitude=payload.longitude,
        status="lobby",
        leader_id=current_user.id,
        group_preferences={
            "categories": payload.preferences.categories,
            "budget": payload.preferences.budget,
            "walking": payload.preferences.walking,
        },
    )

    db.add(new_trip)
    await db.commit()
    await db.refresh(new_trip)

    leader_member = TripMember(
        trip_id=new_trip.id,
        user_id=current_user.id,
        is_leader=True,
        status="ready",
    )

    db.add(leader_member)
    await db.commit()

    return await _serialize_trip(db, new_trip)


@router.get("/{trip_id}")
async def get_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    return await _serialize_trip(db, trip)


@router.put("/{trip_id}")
async def update_trip(
    trip_id: str,
    payload: UpdateTripRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    if str(trip.leader_id) != str(current_user.id):
        raise HTTPException(
            status_code=403,
            detail="Only the leader can edit this trip",
        )

    for key, value in payload.dict(exclude_unset=True).items():
        setattr(trip, key, value)

    await db.commit()

    return await _serialize_trip(db, trip)


@router.post("/{trip_id}/members/{user_id}/toggle-ready")
async def toggle_member_status(
    trip_id: str,
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if str(current_user.id) != str(user_id):
        raise HTTPException(
            status_code=403,
            detail="Cannot toggle another user's status",
        )

    result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == user_id,
        )
    )
    member = result.scalars().first()

    if not member:
        raise HTTPException(
            status_code=404,
            detail="Member not found",
        )

    if not member.is_leader:
        member.status = (
            "notReady"
            if member.status == "ready"
            else "ready"
        )
        await db.commit()

    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    return await _serialize_trip(db, trip)


@router.post("/{trip_id}/invite")
async def invite_member(
    trip_id: str,
    payload: InviteMemberRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip or str(trip.leader_id) != str(current_user.id):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader can invite members",
        )

    term = payload.username.lower()

    user_result = await db.execute(
        select(User).where(
            (User.email == term)
            | (func.lower(User.full_name) == term)
        )
    )
    user_to_invite = user_result.scalars().first()

    if not user_to_invite:
        raise HTTPException(
            status_code=404,
            detail="User not found",
        )

    existing_result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == user_to_invite.id,
        )
    )

    if existing_result.scalars().first():
        raise HTTPException(
            status_code=400,
            detail="User is already in this trip",
        )

    new_member = TripMember(
        trip_id=trip_id,
        user_id=user_to_invite.id,
        status="notReady",
        is_leader=False,
    )
    db.add(new_member)
    await db.commit()

    return await _serialize_trip(db, trip)


@router.post("/{trip_id}/start")
async def start_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip or str(trip.leader_id) != str(current_user.id):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader can start the trip",
        )

    not_ready_result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.status != "ready",
        )
    )

    if not_ready_result.scalars().all():
        raise HTTPException(
            status_code=400,
            detail="Not all members are ready",
        )

    trip.status = "active"
    await db.commit()

    return await _serialize_trip(db, trip)


@router.post("/{trip_id}/complete")
async def complete_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip or str(trip.leader_id) != str(current_user.id):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader can complete the trip",
        )

    trip.status = "completed"
    await db.commit()

    return await _serialize_trip(db, trip)


@router.get("/{trip_id}/preferences")
async def get_group_preferences(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip = await db.scalar(
        select(Trip).where(Trip.id == trip_id)
    )

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    member = await db.scalar(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == current_user.id,
        )
    )

    if not member:
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this trip",
        )

    return trip.group_preferences or {
        "categories": [],
        "budget": "₱0",
        "walking": "Not specified",
    }


@router.put("/{trip_id}/preferences")
async def update_group_preferences(
    trip_id: str,
    payload: GroupPreferencesSchema,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip = await db.scalar(
        select(Trip).where(Trip.id == trip_id)
    )

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    member = await db.scalar(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == current_user.id,
        )
    )

    if not member:
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this trip",
        )

    trip.group_preferences = {
        "categories": payload.categories,
        "budget": payload.budget,
        "walking": payload.walking,
    }

    activity_options = {
        "Accommodation",
        "Cafe",
        "Restaurant / Eatery",
        "Museum",
        "Church / Religious Site",
        "Park / Plaza",
        "Historical / Tourist Site",
        "Shop / Retail",
        "Health & Wellness",
        "Entertainment",
        "Recreation & Arts",
        "Community & Events",
    }

    dietary_options = {
        "None",
        "Halal",
        "Vegan",
        "Budget-Friendly",
    }

    accessibility_options = {
        "Good for children",
        "Pet friendly",
        "Wheelchair accessible",
    }

    activity_tags = [
        tag for tag in payload.categories
        if tag in activity_options
    ]

    dietary_preferences = [
        tag for tag in payload.categories
        if tag in dietary_options
    ]

    accessibility_preferences = [
        tag for tag in payload.categories
        if tag in accessibility_options
    ]

    if not dietary_preferences:
        dietary_preferences = ["None"]

    budget_text = (
        str(payload.budget)
        .replace("₱", "")
        .replace(",", "")
        .strip()
    )

    try:
        max_budget = float(budget_text)
    except (ValueError, TypeError):
        max_budget = 2500.0

    preferred_pace = payload.walking

    if preferred_pace not in {"Fast", "Moderate", "Leisure"}:
        preferred_pace = "Moderate"

    existing_preferences = await db.scalar(
        select(TripMemberPreference).where(
            TripMemberPreference.trip_member_id == member.id
        )
    )

    if existing_preferences:
        existing_preferences.activity_tags = activity_tags
        existing_preferences.dietary_preferences = dietary_preferences
        existing_preferences.max_budget = max_budget
        existing_preferences.preferred_pace = preferred_pace
        existing_preferences.accessibility_preferences = (
            accessibility_preferences
        )
    else:
        leader_preferences = TripMemberPreference(
            trip_member_id=member.id,
            activity_tags=activity_tags,
            dietary_preferences=dietary_preferences,
            max_budget=max_budget,
            preferred_pace=preferred_pace,
            accessibility_preferences=accessibility_preferences,
        )
        db.add(leader_preferences)

    await db.commit()

    return trip.group_preferences
