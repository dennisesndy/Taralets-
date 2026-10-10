from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from app.services.itinerary.group_scoring import aggregate_group_scores

router = APIRouter()

class UserProfileSchema(BaseModel):
    id: str
    activities: List[str]

class PlaceSchema(BaseModel):
    id: str
    name: str
    tags: List[str]

class GroupRecommendPayload(BaseModel):
    group_profiles: List[UserProfileSchema]
    candidate_places: List[PlaceSchema]

@router.post("/group-recommend")
def get_group_recommendations(payload: GroupRecommendPayload):
    try:
        profiles = [p.model_dump() for p in payload.group_profiles]
        places = [p.model_dump() for p in payload.candidate_places]
        
        recommendations = aggregate_group_scores(profiles, places)
        return {"status": "success", "data": recommendations}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))