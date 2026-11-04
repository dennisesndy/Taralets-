import random
import math
from datetime import datetime, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.poi import Place
from app.models.trip import Trip, TripMember
from app.models.trip_member_preference import TripMemberPreference
from app.models.preference_profile import PreferenceProfile
from app.models.user import User
from app.models.user_friend import UserFriend
from app.models.trip_join_request import TripJoinRequest
from app.models.notification import Notification
from app.models.trip_place_selection import TripPlaceSelection
from app.models.trip_place_vote import TripPlaceVote
from app.models.itinerary import TripItinerary
from app.models.itinerary_stop import TripItineraryStop
from app.models.trip_confirmation import TripConfirmation
from app.schemas.profile import TripPreferenceSetupRequest
from app.schemas.trip import (
    CreateTripRequest,
    GenerateTripItineraryRequest,
    UpdateTripRequest,
    InviteMemberRequest,
    GroupPreferencesSchema,
    TripPlaceVoteRequest,
    ItineraryReviewRequest,
    ItineraryReorderRequest,
    ItineraryAddPlaceRequest,
    ItinerarySharingRequest,
)
from app.services.itinerary.trip_itinerary import (
    build_trip_itinerary,
    summarize_group_preferences,
)
from app.services.trip_service import build_group_profiles
from app.services.recommendation import get_group_recommendations

router = APIRouter()


async def _trip_member_for_user(db: AsyncSession, trip_id: str, user_id) -> TripMember:
    result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == user_id,
        )
    )
    member = result.scalars().first()
    if member is None:
        raise HTTPException(status_code=403, detail="You are not a member of this trip")
    return member


async def _are_friends(db: AsyncSession, first_user_id, second_user_id) -> bool:
    friendship = await db.scalar(
        select(UserFriend.id).where(
            UserFriend.user_id == first_user_id,
            UserFriend.friend_id == second_user_id,
        )
    )
    return friendship is not None


async def _is_trip_member(db: AsyncSession, trip_id: str, user_id) -> bool:
    return await db.scalar(
        select(TripMember.id).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == user_id,
        )
    ) is not None


async def _seed_member_preferences(db: AsyncSession, member: TripMember, user: User):
    profile = await db.scalar(
        select(PreferenceProfile).where(PreferenceProfile.email == user.email)
    )
    if profile is None:
        return
    db.add(
        TripMemberPreference(
            trip_member_id=member.id,
            activity_tags=list(profile.activity_tags or []),
            dietary_preferences=list(profile.dietary_preferences or ["None"]),
            max_budget=float(profile.max_budget or 2500),
            desired_places_per_day=None,
            accessibility_preferences=list(
                profile.accessibility_preferences or []
            ),
        )
    )


def _distance_km(lat_a: float, lng_a: float, lat_b: float, lng_b: float) -> float:
    radius_km = 6371.0
    phi_a, phi_b = math.radians(lat_a), math.radians(lat_b)
    delta_phi = math.radians(lat_b - lat_a)
    delta_lambda = math.radians(lng_b - lng_a)
    value = (
        math.sin(delta_phi / 2) ** 2
        + math.cos(phi_a) * math.cos(phi_b) * math.sin(delta_lambda / 2) ** 2
    )
    return 2 * radius_km * math.asin(math.sqrt(value))


async def _latest_itinerary(db: AsyncSession, trip_id: str):
    result = await db.execute(
        select(TripItinerary)
        .where(TripItinerary.trip_id == trip_id)
        .order_by(TripItinerary.version.desc())
        .limit(1)
    )
    return result.scalars().first()


def _parse_optional_time(value):
    if not value:
        return None
    try:
        return datetime.strptime(str(value), "%H:%M").time()
    except ValueError:
        return None


async def _itinerary_response(db: AsyncSession, itinerary: TripItinerary, current_user_id) -> dict:
    metadata = dict(itinerary.algorithm_metadata or {})
    trip = await db.get(Trip, itinerary.trip_id)
    confirmations_result = await db.execute(
        select(TripConfirmation, TripMember, User)
        .join(TripMember, TripConfirmation.trip_member_id == TripMember.id)
        .join(User, TripMember.user_id == User.id)
        .where(TripConfirmation.itinerary_id == itinerary.id)
    )
    confirmations = {confirmation.trip_member_id: confirmation for confirmation, _, _ in confirmations_result.all()}
    members_result = await db.execute(
        select(TripMember, User)
        .join(User, TripMember.user_id == User.id)
        .where(TripMember.trip_id == itinerary.trip_id)
        .order_by(TripMember.is_leader.desc(), TripMember.id)
    )
    members = []
    for member, user in members_result.all():
        confirmation = confirmations.get(member.id)
        name = user.full_name or (user.email.split("@")[0] if user.email else "Member")
        members.append({
            "member_id": member.id,
            "user_id": str(member.user_id),
            "name": name,
            "username": user.email.split("@")[0] if user.email else "member",
            "is_current_user": str(member.user_id) == str(current_user_id),
            "is_leader": bool(member.is_leader),
            "reviewed": bool(confirmation and confirmation.status == "confirmed"),
        })
    metadata.update({
        "trip_id": itinerary.trip_id,
        "itinerary_id": itinerary.id,
        "status": itinerary.status,
        "members": members,
    })
    if trip is not None:
        metadata.update({
            "title": trip.title,
            "date": trip.date.isoformat() if trip.date else None,
            "date_label": trip.date_label,
            "duration_days": trip.duration_days,
            "group_preferences": trip.group_preferences or {},
            "source_itinerary_id": trip.source_itinerary_id,
        })
    return metadata


@router.get("/{trip_id}/itinerary")
async def get_trip_itinerary(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    is_member = await _is_trip_member(db, trip_id, current_user.id)
    if not is_member:
        trip = await db.get(Trip, trip_id)
        if (
            trip is None
            or trip.itinerary_visibility != "friends"
            or not await _are_friends(db, current_user.id, trip.leader_id)
        ):
            raise HTTPException(status_code=403, detail="This itinerary is private")
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}


@router.put("/{trip_id}/itinerary/review")
async def review_trip_itinerary(
    trip_id: str,
    payload: ItineraryReviewRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await _trip_member_for_user(db, trip_id, current_user.id)
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    confirmation_result = await db.execute(select(TripConfirmation).where(
        TripConfirmation.itinerary_id == itinerary.id,
        TripConfirmation.trip_member_id == member.id,
    ))
    confirmation = confirmation_result.scalars().first()
    if confirmation is None:
        confirmation = TripConfirmation(
            itinerary_id=itinerary.id,
            trip_member_id=member.id,
            status="pending",
        )
        db.add(confirmation)
    if itinerary.status == "finalized" and not payload.reviewed:
        raise HTTPException(status_code=409, detail="The itinerary is already locked")
    confirmation.status = "confirmed" if payload.reviewed else "pending"
    confirmation.confirmed_at = datetime.utcnow() if payload.reviewed else None
    await db.commit()
    await db.refresh(itinerary)
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}


@router.post("/{trip_id}/itinerary/lock")
async def lock_trip_itinerary(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_member = await _trip_member_for_user(db, trip_id, current_user.id)
    if not current_member.is_leader:
        raise HTTPException(status_code=403, detail="Only the trip leader can lock the itinerary")
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    if itinerary.status == "finalized":
        return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}
    confirmed_count = (await db.execute(
        select(func.count(TripConfirmation.id)).where(
            TripConfirmation.itinerary_id == itinerary.id,
            TripConfirmation.status == "confirmed",
        )
    )).scalar_one()
    member_count = (await db.execute(
        select(func.count(TripMember.id)).where(TripMember.trip_id == trip_id)
    )).scalar_one()
    if member_count == 0 or confirmed_count != member_count:
        raise HTTPException(status_code=409, detail="Every trip member must review the itinerary before it can be locked")
    itinerary.status = "finalized"
    itinerary.finalized_at = datetime.utcnow()
    await db.commit()
    await db.refresh(itinerary)
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}


@router.post("/{trip_id}/itinerary/unlock")
async def unlock_trip_itinerary(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_member = await _trip_member_for_user(db, trip_id, current_user.id)
    if not current_member.is_leader:
        raise HTTPException(status_code=403, detail="Only the trip leader can reopen the itinerary for editing")
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    if itinerary.status != "finalized":
        raise HTTPException(status_code=409, detail="The itinerary is not locked")

    itinerary.status = "review"
    itinerary.finalized_at = None
    confirmations = (await db.execute(
        select(TripConfirmation).where(TripConfirmation.itinerary_id == itinerary.id)
    )).scalars().all()
    for confirmation in confirmations:
        confirmation.status = "pending"
        confirmation.confirmed_at = None
        confirmation.note = None

    await db.commit()
    await db.refresh(itinerary)
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}


@router.put("/{trip_id}/itinerary/order")
async def reorder_trip_itinerary(
    trip_id: str,
    payload: ItineraryReorderRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    await _trip_member_for_user(db, trip_id, current_user.id)
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    if itinerary.status == "finalized":
        raise HTTPException(status_code=409, detail="The itinerary is already locked")

    stops = (await db.execute(
        select(TripItineraryStop)
        .where(TripItineraryStop.itinerary_id == itinerary.id)
        .order_by(TripItineraryStop.order_index)
    )).scalars().all()
    requested = payload.place_ids
    current_ids = [stop.place_id for stop in stops]
    if len(set(requested)) != len(requested) or set(requested) != set(current_ids):
        raise HTTPException(status_code=422, detail="The order must include every itinerary place exactly once")

    metadata = dict(itinerary.algorithm_metadata or {})
    metadata_stops = metadata.get("stops") or []
    by_place_id = {}
    for stop in metadata_stops:
        try:
            by_place_id[int(stop.get("id") or stop.get("place_id"))] = stop
        except (AttributeError, TypeError, ValueError):
            continue
    reordered = [by_place_id[place_id] for place_id in requested if place_id in by_place_id]
    if len(reordered) == len(requested):
        metadata["stops"] = reordered
        itinerary.algorithm_metadata = metadata

    stop_by_place_id = {stop.place_id: stop for stop in stops}
    # Move indices out of the unique range before assigning the new order.
    for index, stop in enumerate(stops):
        stop.order_index = len(stops) + index
    await db.flush()
    for index, place_id in enumerate(requested):
        stop_by_place_id[place_id].order_index = index
    await db.commit()
    await db.refresh(itinerary)
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}


@router.post("/{trip_id}/itinerary/stops")
async def add_itinerary_stop(
    trip_id: str,
    payload: ItineraryAddPlaceRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await _trip_member_for_user(db, trip_id, current_user.id)
    itinerary = await _latest_itinerary(db, trip_id)
    if itinerary is None:
        raise HTTPException(status_code=404, detail="No itinerary has been generated for this trip")
    if itinerary.status == "finalized":
        raise HTTPException(status_code=409, detail="Reopen the itinerary before adding places")

    place = await db.get(Place, payload.place_id)
    if place is None:
        raise HTTPException(status_code=404, detail="Place not found")
    existing = await db.scalar(select(TripItineraryStop).where(
        TripItineraryStop.itinerary_id == itinerary.id,
        TripItineraryStop.place_id == place.id,
    ))
    if existing is not None:
        raise HTTPException(status_code=409, detail="This place is already in the itinerary")

    metadata = dict(itinerary.algorithm_metadata or {})
    stops = list(metadata.get("stops") or [])
    duration_days = max(1, min(int(metadata.get("duration_days", 1) or 1), 30))
    last_day_number = max(
        (int(stop.get("day_number", 1) or 1) for stop in stops),
        default=1,
    )
    day_number = min(last_day_number, duration_days)
    last_day_stops = [
        stop for stop in stops
        if int(stop.get("day_number", 1) or 1) == day_number
    ]
    last_stop = last_day_stops[-1] if last_day_stops else {}
    start_time = _parse_optional_time(last_stop.get("end_time")) or _parse_optional_time("09:00")
    duration = 60
    start_minutes = start_time.hour * 60 + start_time.minute
    end_minutes = (start_minutes + duration) % (24 * 60)
    from datetime import time as datetime_time
    end_time = datetime_time(end_minutes // 60, end_minutes % 60)
    item = {
        "sequence": len(stops) + 1,
        "day_number": day_number,
        "date": (
            (metadata.get("days") or [])[day_number - 1].get("date")
            if len(metadata.get("days") or []) >= day_number
            else None
        ),
        "id": place.id,
        "place_id": place.id,
        "master_id": place.master_id,
        "name": place.name,
        "category": place.category,
        "area": getattr(place, "district", None) or "",
        "latitude": place.latitude,
        "longitude": place.longitude,
        "start_time": start_time.strftime("%H:%M"),
        "end_time": end_time.strftime("%H:%M"),
        "duration_minutes": duration,
        "travel_minutes": 0,
        "travel_cost": 0,
        "travel_distance_km": 0,
        "budget": int(getattr(place, "min_cost", 0) or 0),
        "group_score": 0,
        "member_scores": [],
        "open_time": place.open_time.isoformat() if place.open_time else None,
        "close_time": place.close_time.isoformat() if place.close_time else None,
        "days_open": getattr(place, "days_open", []) or [],
        "feasible": True,
        "warning": None,
    }
    stops.append(item)
    metadata["stops"] = stops
    summary = dict(metadata.get("summary") or {})
    summary["total_stops"] = len(stops)
    summary["total_duration_minutes"] = int(summary.get("total_duration_minutes", 0) or 0) + duration
    summary["total_budget"] = int(summary.get("total_budget", 0) or 0) + item["budget"]
    summary["end_time"] = end_time.strftime("%H:%M")
    metadata["summary"] = summary
    itinerary.algorithm_metadata = metadata

    db.add(TripItineraryStop(
        itinerary_id=itinerary.id,
        place_id=place.id,
        day_number=day_number,
        order_index=len(stops) - 1,
        start_time=start_time,
        end_time=end_time,
        duration_minutes=duration,
        travel_minutes_from_previous=0,
        group_score=0,
    ))
    selection = await db.scalar(select(TripPlaceSelection).where(
        TripPlaceSelection.trip_id == trip_id,
        TripPlaceSelection.place_id == place.id,
    ))
    if selection is None:
        selection = TripPlaceSelection(
            trip_id=trip_id,
            place_id=place.id,
            selected_by_member_id=member.id,
            is_active=True,
        )
        db.add(selection)
    else:
        selection.is_active = True

    confirmations = (await db.execute(select(TripConfirmation).where(
        TripConfirmation.itinerary_id == itinerary.id,
    ))).scalars().all()
    for confirmation in confirmations:
        confirmation.status = "pending"
        confirmation.confirmed_at = None
        confirmation.note = None
    itinerary.status = "review"
    itinerary.finalized_at = None
    await db.commit()
    await db.refresh(itinerary)
    return {"status": "success", "data": await _itinerary_response(db, itinerary, current_user.id)}

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
                    if (preference and preference.max_budget is not None)
                    else None
                ),
                "desired_places_per_day": (
                    preference.desired_places_per_day if preference else None
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
        "created_at": (
            trip.created_at.isoformat()
            if getattr(trip, "created_at", None) is not None
            else None
        ),
        "description": trip.description,
        "date": (
            trip.date.isoformat()
            if hasattr(trip.date, "isoformat")
            else str(trip.date)
        ),
        "duration_days": int(getattr(trip, "duration_days", 1) or 1),
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
        "itinerary_visibility": trip.itinerary_visibility or "private",
        "source_itinerary_id": trip.source_itinerary_id,
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
        select(Trip)
        .where(Trip.id.in_(trip_ids))
        .order_by(Trip.created_at.desc(), Trip.id.asc())
    )
    trips = trips_result.scalars().all()

    return [
        await _serialize_trip(db, trip)
        for trip in trips
    ]


@router.get("/friends/available")
async def get_friends_available_trips(
    latitude: float,
    longitude: float,
    radius_km: float = Query(default=0.5, ge=0.1, le=5.0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    friend_ids = select(UserFriend.friend_id).where(
        UserFriend.user_id == current_user.id
    )
    memberships = select(TripMember.trip_id).where(
        TripMember.user_id == current_user.id
    )
    result = await db.execute(
        select(Trip)
        .where(
            Trip.leader_id.in_(friend_ids),
            Trip.status == "lobby",
            Trip.itinerary_visibility == "friends",
            ~Trip.id.in_(memberships),
        )
        .order_by(Trip.date.asc().nullslast(), Trip.created_at.desc())
    )
    today = datetime.now().date()
    nearby_trips = []
    for trip in result.scalars().all():
        distance = _distance_km(
            latitude,
            longitude,
            float(trip.latitude),
            float(trip.longitude),
        )
        if distance > radius_km:
            continue
        if trip.date is not None:
            final_day = trip.date.date() + timedelta(
                days=max(int(trip.duration_days or 1), 1) - 1
            )
            if final_day < today:
                continue
        nearby_trips.append(await _serialize_trip(db, trip))
    return nearby_trips


@router.get("/friends/available-itineraries")
async def get_friends_available_itineraries(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    friend_ids = select(UserFriend.friend_id).where(
        UserFriend.user_id == current_user.id
    )
    result = await db.execute(
        select(Trip, User)
        .join(User, Trip.leader_id == User.id)
        .where(
            Trip.leader_id.in_(friend_ids),
            Trip.itinerary_visibility == "friends",
            Trip.status != "cancelled",
        )
        .order_by(Trip.created_at.desc())
    )
    available = []
    for trip, owner in result.all():
        itinerary = await _latest_itinerary(db, trip.id)
        if itinerary is None:
            continue
        trip_date = trip.date.date() if isinstance(trip.date, datetime) else trip.date
        final_day = (
            trip_date + timedelta(days=max(int(trip.duration_days or 1), 1) - 1)
            if trip_date is not None else None
        )
        accepting = trip.status == "lobby" and (
            final_day is None or final_day >= datetime.now().date()
        )
        available.append({
            "trip": await _serialize_trip(db, trip),
            "itinerary": await _itinerary_response(db, itinerary, current_user.id),
            "owner_name": owner.full_name or (owner.email.split("@")[0] if owner.email else "Friend"),
            "can_join_existing": accepting,
        })
    return available


@router.put("/{trip_id}/sharing")
async def update_itinerary_sharing(
    trip_id: str,
    payload: ItinerarySharingRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip = await db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    if str(trip.leader_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the trip leader can change itinerary sharing")
    if await _latest_itinerary(db, trip_id) is None:
        raise HTTPException(status_code=409, detail="Generate an itinerary before sharing it")
    trip.itinerary_visibility = payload.visibility
    await db.commit()
    return {"status": "success", "visibility": trip.itinerary_visibility}


async def _create_trip_join_request(db: AsyncSession, trip: Trip, requester: User):
    if trip.status != "lobby":
        raise HTTPException(status_code=410, detail="This trip is no longer accepting requests")
    if not await _are_friends(db, requester.id, trip.leader_id):
        raise HTTPException(status_code=403, detail="Only the trip leader's friends may request to join")
    if await _is_trip_member(db, trip.id, requester.id):
        raise HTTPException(status_code=409, detail="You are already a member of this trip")

    existing = await db.scalar(select(TripJoinRequest).where(
        TripJoinRequest.trip_id == trip.id,
        TripJoinRequest.requester_id == requester.id,
    ))
    if existing is not None and existing.status == "pending":
        return existing
    if existing is not None:
        existing.status = "pending"
        existing.created_at = datetime.utcnow()
        existing.resolved_at = None
        join_request = existing
    else:
        join_request = TripJoinRequest(trip_id=trip.id, requester_id=requester.id)
        db.add(join_request)
        await db.flush()

    db.add(Notification(
        user_id=trip.leader_id,
        actor_id=requester.id,
        trip_join_request_id=join_request.id,
        type="trip_join_request",
        title="Trip join request",
        message=f"{requester.full_name or requester.email} wants to join {trip.title}.",
    ))
    await db.commit()
    return join_request


@router.post("/{trip_id}/join-request")
async def request_to_join_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip = await db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    request = await _create_trip_join_request(db, trip, current_user)
    return {"status": request.status, "request_id": str(request.id)}


@router.get("/{trip_id}/join-request-status")
async def get_own_trip_join_request_status(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    request = await db.scalar(
        select(TripJoinRequest).where(
            TripJoinRequest.trip_id == trip_id,
            TripJoinRequest.requester_id == current_user.id,
        )
    )
    if request is None:
        raise HTTPException(status_code=404, detail="Join request not found")
    return {"trip_id": trip_id, "status": request.status}


@router.get("/{trip_id}/join-requests")
async def list_trip_join_requests(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip = await db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    if str(trip.leader_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the trip leader can review join requests")
    rows = await db.execute(
        select(TripJoinRequest, User)
        .join(User, TripJoinRequest.requester_id == User.id)
        .where(TripJoinRequest.trip_id == trip_id, TripJoinRequest.status == "pending")
        .order_by(TripJoinRequest.created_at.asc())
    )
    return [
        {"id": str(request.id), "trip_id": trip_id,
         "requester_id": str(request.requester_id),
         "requester_name": user.full_name or (user.email.split("@")[0] if user.email else "Friend"),
         "created_at": request.created_at.isoformat(), "status": request.status}
        for request, user in rows.all()
    ]


@router.post("/{trip_id}/join-requests/{request_id}/{action}")
async def resolve_trip_join_request(
    trip_id: str,
    request_id: str,
    action: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if action not in {"approve", "reject"}:
        raise HTTPException(status_code=422, detail="Action must be approve or reject")
    trip = await db.get(Trip, trip_id)
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    if str(trip.leader_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the trip leader can review join requests")
    try:
        request_uuid = UUID(request_id)
    except ValueError:
        raise HTTPException(status_code=404, detail="Join request not found")
    request = await db.scalar(select(TripJoinRequest).where(
        TripJoinRequest.id == request_uuid,
        TripJoinRequest.trip_id == trip_id,
    ))
    if request is None:
        raise HTTPException(status_code=404, detail="Join request not found")
    if request.status != "pending":
        raise HTTPException(status_code=409, detail="This request was already reviewed")

    request.status = "accepted" if action == "approve" else "rejected"
    request.resolved_at = datetime.utcnow()
    if action == "approve":
        if not await _is_trip_member(db, trip_id, request.requester_id):
            member = TripMember(
                trip_id=trip_id, user_id=request.requester_id,
                status="notReady", is_leader=False,
            )
            db.add(member)
            await db.flush()
            requester = await db.get(User, request.requester_id)
            if requester is not None:
                await _seed_member_preferences(db, member, requester)

    db.add(Notification(
        user_id=request.requester_id,
        actor_id=current_user.id,
        trip_join_request_id=request.id,
        type="trip_join_request_resolved",
        title="Trip join request update",
        message=f"Your request to join {trip.title} was {request.status}.",
    ))
    await db.commit()
    return {"status": request.status, "trip_id": trip_id}

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

    if not await _is_trip_member(db, trip.id, current_user.id) and not await _are_friends(
        db, current_user.id, trip.leader_id
    ):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader's friends can view this trip.",
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
        raise HTTPException(status_code=404, detail="Invalid room code")
    request = await _create_trip_join_request(db, trip, current_user)
    return {"status": request.status, "request_id": str(request.id)}

@router.post("/{trip_id}/member-preferences")
async def save_member_preferences(
    trip_id: str,
    payload: TripPreferenceSetupRequest,
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
        existing.desired_places_per_day = payload.desired_places_per_day
        existing.accessibility_preferences = payload.accessibility_preferences
    else:
        new_preferences = TripMemberPreference(
            trip_member_id=member.id,
            activity_tags=payload.activity_tags,
            dietary_preferences=payload.dietary_preferences,
            max_budget=payload.max_budget,
            desired_places_per_day=payload.desired_places_per_day,
            accessibility_preferences=payload.accessibility_preferences,
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
    source_itinerary = None
    source_trip = None
    if payload.source_itinerary_id:
        source_itinerary = await db.get(TripItinerary, payload.source_itinerary_id)
        if source_itinerary is None:
            raise HTTPException(status_code=404, detail="Shared itinerary not found")
        source_trip = await db.get(Trip, source_itinerary.trip_id)
        if (
            source_trip is None
            or source_trip.itinerary_visibility != "friends"
            or not await _are_friends(db, current_user.id, source_trip.leader_id)
        ):
            raise HTTPException(status_code=403, detail="This itinerary is not shared with you")

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
        duration_days=payload.duration_days,
        meetup=payload.meetup_name.split(",")[0],
        meetup_full=payload.meetup_name,
        arrival_target=payload.meetup_time,
        wrap_up=payload.wrap_up_time,
        latitude=payload.latitude,
        longitude=payload.longitude,
        status="lobby",
        leader_id=current_user.id,
        source_itinerary_id=payload.source_itinerary_id,
        group_preferences={
            "categories": payload.preferences.categories,
            "budget": payload.preferences.budget,
            "desired_places_per_day": payload.preferences.desired_places_per_day,
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
    await db.flush()

    if source_itinerary is not None:
        cloned_metadata = dict(source_itinerary.algorithm_metadata or {})
        cloned_metadata.update({
            "trip_id": new_trip.id,
            "title": new_trip.title,
            "date": new_trip.date.isoformat() if new_trip.date else None,
            "duration_days": new_trip.duration_days,
            "status": "review",
            "source_trip_id": source_trip.id if source_trip else None,
            "source_trip_title": source_trip.title if source_trip else None,
        })
        cloned = TripItinerary(
            trip_id=new_trip.id,
            status="review",
            version=1,
            generated_by_member_id=leader_member.id,
            preference_snapshot={"copied_from_itinerary_id": source_itinerary.id},
            algorithm_metadata=cloned_metadata,
        )
        db.add(cloned)
        await db.flush()
        source_stops = (await db.execute(
            select(TripItineraryStop)
            .where(TripItineraryStop.itinerary_id == source_itinerary.id)
            .order_by(TripItineraryStop.day_number, TripItineraryStop.order_index)
        )).scalars().all()
        for stop in source_stops:
            db.add(TripItineraryStop(
                itinerary_id=cloned.id,
                place_id=stop.place_id,
                day_number=stop.day_number,
                order_index=stop.order_index,
                start_time=stop.start_time,
                end_time=stop.end_time,
                duration_minutes=stop.duration_minutes,
                travel_minutes_from_previous=stop.travel_minutes_from_previous,
                group_score=stop.group_score,
                constraint_check=dict(stop.constraint_check or {}),
                notes=stop.notes,
            ))
        db.add(TripConfirmation(
            itinerary_id=cloned.id,
            trip_member_id=leader_member.id,
            status="pending",
        ))

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

    if not await _is_trip_member(db, trip.id, current_user.id) and not await _are_friends(
        db, current_user.id, trip.leader_id
    ):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader's friends can view this trip.",
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

    if user_to_invite.id == current_user.id or not await _are_friends(
        db, current_user.id, user_to_invite.id
    ):
        raise HTTPException(
            status_code=403,
            detail="You can invite friends only.",
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
    await db.flush()
    await _seed_member_preferences(db, new_member, user_to_invite)
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

@router.post("/{trip_id}/cancel")
async def cancel_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    if str(trip.leader_id) != str(current_user.id):
        raise HTTPException(
            status_code=403,
            detail="Only the trip leader can cancel the trip",
        )

    trip.status = "cancelled"
    await db.commit()

    return await _serialize_trip(db, trip)

@router.post("/{trip_id}/leave")
async def leave_trip(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip).where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    if str(trip.leader_id) == str(current_user.id):
        raise HTTPException(
            status_code=400,
            detail="The leader cannot leave the trip. Cancel it instead.",
        )

    member_result = await db.execute(
        select(TripMember).where(
            TripMember.trip_id == trip_id,
            TripMember.user_id == current_user.id,
        )
    )
    member = member_result.scalars().first()

    if not member:
        raise HTTPException(
            status_code=404,
            detail="You are not a member of this trip",
        )

    # Delete member preferences to maintain referential integrity
    pref_result = await db.execute(
        select(TripMemberPreference).where(TripMemberPreference.trip_member_id == member.id)
    )
    pref = pref_result.scalars().first()
    
    if pref:
        await db.delete(pref)

    await db.delete(member)
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
        "desired_places_per_day": None,
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
        "desired_places_per_day": payload.desired_places_per_day,
    }

    activity_options = {
        "Accommodations",
        "Cafes",
        "Desserts / Bakeries",
        "Restaurant / Eatery",
        "Museums",
        "Church / Religious Site",
        "Parks / Plazas",
        "Historical / Tourist Site",
        "Shopping / Retail",
        "Health / Wellness",
        "Entertainment / Leisure",
        "Nightlife / Bars",
        "Government / Services",
        "Others",
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

    desired_places_per_day = payload.desired_places_per_day

    existing_preferences = await db.scalar(
        select(TripMemberPreference).where(
            TripMemberPreference.trip_member_id == member.id
        )
    )

    if existing_preferences:
        existing_preferences.activity_tags = activity_tags
        existing_preferences.dietary_preferences = dietary_preferences
        existing_preferences.max_budget = max_budget
        existing_preferences.desired_places_per_day = desired_places_per_day
        existing_preferences.accessibility_preferences = (
            accessibility_preferences
        )
    else:
        leader_preferences = TripMemberPreference(
            trip_member_id=member.id,
            activity_tags=activity_tags,
            dietary_preferences=dietary_preferences,
            max_budget=max_budget,
            desired_places_per_day=desired_places_per_day,
            accessibility_preferences=accessibility_preferences,
        )
        db.add(leader_preferences)

    await db.commit()

    return trip.group_preferences


@router.post("/{trip_id}/itinerary/selections")
async def add_itinerary_selections(
    trip_id: str,
    payload: TripPlaceVoteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await _trip_member_for_user(db, trip_id, current_user.id)
    ids = list(dict.fromkeys(str(value).strip() for value in payload.place_ids if str(value).strip()))
    if not ids:
        return {"selections": []}
    numeric_ids = [int(value) for value in ids if value.isdigit()]
    conditions = [Place.master_id.in_(ids)]
    if numeric_ids:
        conditions.append(Place.id.in_(numeric_ids))
    places = (await db.execute(select(Place).where(or_(*conditions)))).scalars().all()
    places_by_key = {key: place for place in places for key in (str(place.id), str(place.master_id))}
    missing = [value for value in ids if value not in places_by_key]
    if missing:
        raise HTTPException(status_code=422, detail="Some selected places could not be found: " + ", ".join(missing))
    for place in places:
        result = await db.execute(select(TripPlaceSelection).where(
            TripPlaceSelection.trip_id == trip_id,
            TripPlaceSelection.place_id == place.id,
        ))
        selection = result.scalars().first()
        if selection is None:
            db.add(TripPlaceSelection(
                trip_id=trip_id,
                place_id=place.id,
                selected_by_member_id=member.id,
                is_active=True,
            ))
        else:
            selection.is_active = True
    await db.commit()
    return {"selections": ids}


@router.get("/{trip_id}/itinerary/selections")
async def get_itinerary_selections(
    trip_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_member = await _trip_member_for_user(db, trip_id, current_user.id)
    members = (await db.execute(
        select(TripMember, User).join(User, TripMember.user_id == User.id)
        .where(TripMember.trip_id == trip_id)
    )).all()
    rows = (await db.execute(
        select(TripPlaceSelection, Place)
        .join(Place, TripPlaceSelection.place_id == Place.id)
        .where(TripPlaceSelection.trip_id == trip_id, TripPlaceSelection.is_active.is_(True))
        .order_by(TripPlaceSelection.created_at, TripPlaceSelection.id)
    )).all()
    selection_ids = [selection.id for selection, _ in rows]
    vote_rows = (await db.execute(
        select(TripPlaceVote, TripMember, User)
        .join(TripMember, TripPlaceVote.trip_member_id == TripMember.id)
        .join(User, TripMember.user_id == User.id)
        .where(TripPlaceVote.selection_id.in_(selection_ids))
    )).all() if selection_ids else []
    votes_by_selection = {}
    voted_members = set()
    for vote, member, user in vote_rows:
        name = user.full_name or (user.email.split("@")[0] if user.email else "Member")
        votes_by_selection.setdefault(vote.selection_id, []).append({
            "member_id": member.id,
            "name": name,
            "vote": vote.vote,
            "is_current_user": str(member.user_id) == str(current_user.id),
        })
        if vote.vote != "skip":
            voted_members.add(member.id)
    return {
        "members": [
            {"member_id": member.id,
             "name": user.full_name or (user.email.split("@")[0] if user.email else "Member"),
             "is_current_user": str(member.user_id) == str(current_user.id),
             "has_voted": member.id in voted_members}
            for member, user in members
        ],
        "selections": [
            {
                "id": selection.id,
                "selected_by_current_user": selection.selected_by_member_id == current_member.id,
                "place_id": place.id,
                "master_id": place.master_id,
                "name": place.name,
                "category": place.category,
                "district": place.district,
                "address": place.address,
                "description": place.description,
                "image_url": place.image_url,
                "activity_tags": place.activity_tags or [],
                "dietary_options": place.dietary_options or [],
                "wheelchair_accessible": place.wheelchair_accessible,
                "pet_friendly": place.pet_friendly,
                "good_for_children": place.good_for_children,
                "min_cost": float(place.min_cost or 0),
                "max_cost": float(place.max_cost or 0),
                "rating": float(place.rating or 0),
                "reviews": place.reviews,
                "votes": votes_by_selection.get(selection.id, []),
            }
            for selection, place in rows
        ],
    }


@router.put("/{trip_id}/itinerary/votes")
async def save_itinerary_votes(
    trip_id: str,
    payload: TripPlaceVoteRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    member = await _trip_member_for_user(db, trip_id, current_user.id)
    ids = list(dict.fromkeys(str(value).strip() for value in payload.place_ids if str(value).strip()))
    selections = (await db.execute(
        select(TripPlaceSelection).where(
            TripPlaceSelection.trip_id == trip_id,
            TripPlaceSelection.is_active.is_(True),
        )
    )).scalars().all()
    places = []
    if ids:
        numeric_ids = [int(value) for value in ids if value.isdigit()]
        conditions = [Place.master_id.in_(ids)]
        if numeric_ids:
            conditions.append(Place.id.in_(numeric_ids))
        places = (await db.execute(select(Place).where(or_(*conditions)))).scalars().all()
        places_by_key = {key: place for place in places for key in (str(place.id), str(place.master_id))}
        missing = [value for value in ids if value not in places_by_key]
        if missing:
            raise HTTPException(status_code=422, detail="Some voted places could not be found: " + ", ".join(missing))
        existing_by_place = {selection.place_id: selection for selection in selections}
        for place in places:
            selection = existing_by_place.get(place.id)
            if selection is None:
                selection = TripPlaceSelection(trip_id=trip_id, place_id=place.id, selected_by_member_id=member.id)
                db.add(selection)
                await db.flush()
                selections.append(selection)
            selection.is_active = True
    desired_ids = {places_by_key[value].id for value in ids} if ids else set()
    for selection in selections:
        existing = (await db.execute(select(TripPlaceVote).where(
            TripPlaceVote.selection_id == selection.id,
            TripPlaceVote.trip_member_id == member.id,
        ))).scalars().first()
        if selection.place_id in desired_ids:
            if existing is None:
                db.add(TripPlaceVote(selection_id=selection.id, trip_member_id=member.id, vote="ok"))
            else:
                existing.vote = "ok"
        elif existing is not None:
            await db.delete(existing)
    await db.commit()
    return await get_itinerary_selections(trip_id, db, current_user)


@router.post("/{trip_id}/itinerary/generate")
async def generate_trip_itinerary(
    trip_id: str,
    payload: GenerateTripItineraryRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    trip_result = await db.execute(
        select(Trip)
        .options(
            selectinload(Trip.members).selectinload(
                TripMember.preferences
            ),
            selectinload(Trip.members).selectinload(TripMember.user),
        )
        .where(Trip.id == trip_id)
    )
    trip = trip_result.scalars().first()

    if not trip:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    if not any(
        str(member.user_id) == str(current_user.id)
        for member in trip.members
    ):
        raise HTTPException(
            status_code=403,
            detail="You are not a member of this trip",
        )

    latest = await _latest_itinerary(db, trip_id)
    if latest is not None:
        return {"status": "success", "data": await _itinerary_response(db, latest, current_user.id)}

    member_ids = [member.id for member in trip.members]
    selections = (await db.execute(select(TripPlaceSelection).where(
        TripPlaceSelection.trip_id == trip_id,
        TripPlaceSelection.is_active.is_(True),
    ))).scalars().all()
    selection_ids = [selection.id for selection in selections]
    voted_member_ids = set()
    if selection_ids:
        vote_rows = (await db.execute(select(TripPlaceVote).where(
            TripPlaceVote.selection_id.in_(selection_ids),
            TripPlaceVote.vote != "skip",
        ))).scalars().all()
        voted_member_ids = {vote.trip_member_id for vote in vote_rows}
    remaining_voters = len(set(member_ids) - voted_member_ids)
    if remaining_voters:
        raise HTTPException(
            status_code=409,
            detail=f"Waiting for {remaining_voters} more {('member' if remaining_voters == 1 else 'members')} to vote before generating the itinerary",
        )

    group_profiles = build_group_profiles(trip)

    if not group_profiles:
        raise HTTPException(
            status_code=400,
            detail="This trip has no members to plan for",
        )

    positive_vote_result = await db.execute(
        select(TripPlaceSelection.place_id)
        .join(TripPlaceVote, TripPlaceVote.selection_id == TripPlaceSelection.id)
        .where(
            TripPlaceSelection.trip_id == trip_id,
            TripPlaceSelection.is_active.is_(True),
            TripPlaceVote.vote != "skip",
        )
        .distinct()
    )
    raw_ids = [str(value) for value in positive_vote_result.scalars().all()]

    if not raw_ids:
        raise HTTPException(
            status_code=422,
            detail="Select at least one place",
        )

    numeric_ids = [
        int(place_id)
        for place_id in raw_ids
        if place_id.isdigit()
    ]

    conditions = [Place.master_id.in_(raw_ids)]

    if numeric_ids:
        conditions.append(Place.id.in_(numeric_ids))

    places_result = await db.execute(
        select(Place).where(or_(*conditions))
    )
    places = list(places_result.scalars().all())

    if not places:
        raise HTTPException(
            status_code=404,
            detail="None of the selected places were found",
        )

    found_ids = {
        value
        for place in places
        for value in (str(place.master_id), str(place.id))
    }
    missing_place_ids = [
        place_id
        for place_id in raw_ids
        if place_id not in found_ids
    ]

    if missing_place_ids:
        raise HTTPException(
            status_code=422,
            detail=(
                "Some selected places could not be found: "
                + ", ".join(sorted(set(missing_place_ids)))
            ),
        )

    group_preferences, desired_places_per_day = summarize_group_preferences(
        group_profiles
    )
    fallback_stop_count = 0
    if desired_places_per_day and len(places) < desired_places_per_day:
        missing_stop_count = desired_places_per_day - len(places)
        ranked_fallbacks = await get_group_recommendations(
            db=db,
            group_profiles=group_profiles,
            origin_lat=trip.latitude,
            origin_lon=trip.longitude,
            max_radius=10000,
            limit=min(100, max(desired_places_per_day * 3, missing_stop_count * 4)),
            offset=0,
        )
        chosen_ids = {str(place.id) for place in places}
        fallback_places = [
            item
            for item in ranked_fallbacks
            if item.get("id") is not None
            and str(item["id"]) not in chosen_ids
        ][:missing_stop_count]
        places.extend(fallback_places)
        fallback_stop_count = len(fallback_places)

    trip_date = (
        payload.date.date()
        if payload.date
        else (
            trip.date.date()
            if isinstance(trip.date, datetime)
            else None
        )
    )

    start_location = payload.start_location

    if start_location is None and (
        trip.latitude is not None and trip.longitude is not None
    ):
        start_location = {
            "lat": trip.latitude,
            "lng": trip.longitude,
        }

    itinerary = build_trip_itinerary(
        group_profiles=group_profiles,
        candidate_places=places,
        trip_date=trip_date,
        start_time=payload.start_time or trip.arrival_target,
        start_location=start_location,
        origin_lat=trip.latitude,
        origin_lon=trip.longitude,
        duration_days=getattr(trip, "duration_days", 1),
    )

    members = []

    current_member = next(
        (member for member in trip.members if str(member.user_id) == str(current_user.id)),
        None,
    )

    for member in sorted(
        trip.members or [],
        key=lambda item: (
            not bool(item.is_leader),
            str(item.id),
        ),
    ):
        user = getattr(member, "user", None)
        email = str(getattr(user, "email", "") or "")
        email_prefix = email.split("@")[0] if email else "user"
        full_name = str(getattr(user, "full_name", "") or "").strip()
        display_name = full_name or email_prefix

        members.append(
            {
                "member_id": str(member.id),
                "user_id": str(member.user_id),
                "username": email_prefix,
                "name": display_name,
                "is_leader": bool(member.is_leader),
                "is_current_user": (
                    str(member.user_id) == str(current_user.id)
                ),
                "reviewed": False,
            }
        )

    duration_days = max(1, min(int(getattr(trip, "duration_days", 1) or 1), 30))
    if trip_date is not None and duration_days > 1:
        final_date = trip_date + timedelta(days=duration_days - 1)
        date_label = f"{trip_date.strftime('%b %d')} – {final_date.strftime('%b %d, %Y')}"
    else:
        date_label = trip.long_date or trip.date_label or (trip_date.strftime("%a, %b %d") if trip_date else "Trip day")

    response_data = {
        "trip_id": str(trip.id),
        "title": trip.title,
        "date": trip_date.isoformat() if trip_date else None,
        "date_label": date_label,
        "status": "review",
        "desired_places_per_day": desired_places_per_day,
        "duration_days": duration_days,
        "fallback_stop_count": fallback_stop_count,
        "group_preferences": group_preferences,
        "members": members,
        "missing_place_ids": missing_place_ids,
        **itinerary,
    }

    saved = TripItinerary(
        trip_id=trip_id,
        status="review",
        version=1,
        generated_by_member_id=current_member.id if current_member else None,
        preference_snapshot={"group_preferences": group_preferences},
        algorithm_metadata=response_data,
    )
    db.add(saved)
    await db.flush()
    for index, stop in enumerate(itinerary.get("stops") or []):
        place_id = stop.get("id") or stop.get("place_id")
        if place_id is None:
            continue
        try:
            place_id = int(place_id)
        except (TypeError, ValueError):
            continue
        db.add(TripItineraryStop(
            itinerary_id=saved.id,
            place_id=place_id,
            day_number=int(stop.get("day_number", 1) or 1),
            order_index=index,
            start_time=_parse_optional_time(stop.get("start_time")),
            end_time=_parse_optional_time(stop.get("end_time")),
            duration_minutes=stop.get("duration_minutes"),
            travel_minutes_from_previous=stop.get("travel_minutes"),
            group_score=stop.get("group_score"),
            constraint_check={"warning": stop.get("warning")},
            notes=stop.get("warning"),
        ))
    for trip_member in trip.members:
        db.add(TripConfirmation(itinerary_id=saved.id, trip_member_id=trip_member.id, status="pending"))
    await db.commit()
    await db.refresh(saved)

    return {
        "status": "success",
        "data": await _itinerary_response(db, saved, current_user.id),
    }
