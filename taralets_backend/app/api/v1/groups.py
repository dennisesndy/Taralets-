from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api import deps
from app.models.trip import Trip, TripMember
from app.services.recommendation import get_group_recommendations
from app.services.trip_service import build_group_profiles

router = APIRouter()


@router.get("/{group_id}/recommendations")
async def get_recommendations_for_group(
    group_id: str,
    radius: int = Query(3000, description="Max search radius in meters"),
    limit: int = Query(30, description="Number of results to return"),
    offset: int = Query(0, description="Number of results to skip"),
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

    # Build one profile per member, including members who have not
    # saved preferences yet.
    group_profiles = build_group_profiles(trip)

    if not group_profiles:
        return {"data": []}

    # Generate recommendations using the group's preferences.
    recommendations = await get_group_recommendations(
        db=db,
        group_profiles=group_profiles,
        origin_lat=trip.latitude,
        origin_lon=trip.longitude,
        max_radius=radius,
        limit=limit,
        offset=offset,
    )

    return {"data": recommendations}