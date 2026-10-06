from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.models.preference_profile import PreferenceProfile
from app.schemas.profile import PreferenceSetupRequest

router = APIRouter(prefix="/profile", tags=["Profile"])

@router.post("/preferences", status_code=status.HTTP_201_CREATED)
async def save_preferences(payload: PreferenceSetupRequest, db: AsyncSession = Depends(get_db)):
    # I-check kung may existing profile na
    existing = await db.scalar(select(PreferenceProfile).where(PreferenceProfile.email == payload.email))
    
    if existing:
        existing.activity_tags = payload.activity_tags
        existing.dietary_preferences = payload.dietary_preferences
        existing.max_budget = payload.max_budget
        existing.preferred_pace = payload.preferred_pace
        existing.passenger_type = payload.passenger_type
    else:
        new_profile = PreferenceProfile(
            email=payload.email,
            activity_tags=payload.activity_tags,
            dietary_preferences=payload.dietary_preferences,
            max_budget=payload.max_budget,
            preferred_pace=payload.preferred_pace,
            passenger_type=payload.passenger_type
        )
        db.add(new_profile)
        
    await db.commit()
    return {"message": "Travel Preferences Successfully Saved"}