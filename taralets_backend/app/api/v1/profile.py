from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.preference_profile import PreferenceProfile
from app.schemas.profile import PreferenceSetupRequest

router = APIRouter(prefix="/profile", tags=["Profile"])

@router.get("/preferences")
async def get_preferences(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    existing = await db.scalar(select(PreferenceProfile).where(PreferenceProfile.email == current_user.email))
    if not existing:
        raise HTTPException(status_code=404, detail="Preferences not found")
    return existing

@router.post("/preferences", status_code=status.HTTP_201_CREATED)
async def save_preferences(payload: PreferenceSetupRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Hindi na kailangan ang email sa payload kung authenticate naman
    existing = await db.scalar(select(PreferenceProfile).where(PreferenceProfile.email == current_user.email))
    
    if existing:
        existing.activity_tags = payload.activity_tags
        existing.dietary_preferences = payload.dietary_preferences
        existing.max_budget = payload.max_budget
        existing.preferred_pace = payload.preferred_pace
        existing.passenger_type = payload.passenger_type
        existing.accessibility_preferences = payload.accessibility_preferences
    else:
        new_profile = PreferenceProfile(
            email=current_user.email,
            activity_tags=payload.activity_tags,
            dietary_preferences=payload.dietary_preferences,
            max_budget=payload.max_budget,
            preferred_pace=payload.preferred_pace,
            passenger_type=payload.passenger_type,
            accessibility_preferences=payload.accessibility_preferences
        )
        db.add(new_profile)
        
    await db.commit()
    return {"message": "Travel Preferences Successfully Saved"}