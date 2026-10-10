from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api import deps
from app.models.trip import Trip, TripMember
from app.services.recommendation import get_group_recommendations

router = APIRouter()


@router.get("/{group_id}/recommendations")
async def get_recommendations_for_group(
    group_id: str,
    db: AsyncSession = Depends(deps.get_db),
):
    # Retrieve the trip and its members with their preferences.
    result = await db.execute(
        select(Trip)
        .options(
            selectinload(Trip.members).selectinload(
                TripMember.preferences
            )
        )
        .where(Trip.id == group_id)
    )

    trip = result.scalars().first()

    if trip is None:
        raise HTTPException(
            status_code=404,
            detail="Trip not found",
        )

    # Build a profile for each member who has saved preferences.
    group_profiles = []

    for member in trip.members:
        pref = member.preferences

        if pref is None:
            continue

        group_profiles.append(
            {
                "activity_tags": pref.activity_tags or [],
                "dietary_preferences": pref.dietary_preferences or [],
                "max_budget": pref.max_budget,
                "preferred_pace": pref.preferred_pace,
                "accessibility_preferences": (
                    pref.accessibility_preferences or []
                ),
            }
        )

    if not group_profiles:
        return {"data": []}

    # Generate recommendations using the group's preferences.
    recommendations = await get_group_recommendations(
        db=db,
        group_profiles=group_profiles,
        origin_lat=trip.latitude,
        origin_lon=trip.longitude,
    )

    return {"data": recommendations}