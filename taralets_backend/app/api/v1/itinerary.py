
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List

from app.services.itinerary.group_scoring import aggregate_group_scores
from app.services.itinerary.route_sequencing import (
    generate_group_acs_itinerary,
)

router = APIRouter()


class UserProfileSchema(BaseModel):
    id: str
    activities: List[str]
    activity_tags: List[str] = Field(default_factory=list)
    dietary_preferences: List[str] = Field(default_factory=list)
    max_budget: float = 2500.0
    preferred_pace: str = "Moderate"
    accessibility_preferences: List[str] = Field(default_factory=list)


class PlaceSchema(BaseModel):
    id: str
    name: str
    tags: List[str]
    lat: float | None = None
    lng: float | None = None
    latitude: float | None = None
    longitude: float | None = None
    entrance_fee: float | None = None
    is_open: bool | None = None


class GroupRecommendPayload(BaseModel):
    group_profiles: List[UserProfileSchema]
    candidate_places: List[PlaceSchema]


class GroupItineraryPayload(GroupRecommendPayload):
    start_location: dict[str, float] | None = None
    ant_count: int = Field(default=20, ge=1, le=100)
    iterations: int = Field(default=30, ge=1, le=200)
    seed: int = 42


@router.post("/group-recommend")
def get_group_recommendations(payload: GroupRecommendPayload):
    try:
        profiles = [p.model_dump() for p in payload.group_profiles]
        places = [p.model_dump() for p in payload.candidate_places]

        recommendations = aggregate_group_scores(profiles, places)

        return {
            "status": "success",
            "data": recommendations,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/group-itinerary")
def get_group_itinerary(payload: GroupItineraryPayload):
    try:
        profiles = [p.model_dump() for p in payload.group_profiles]
        places = [p.model_dump() for p in payload.candidate_places]

        result = generate_group_acs_itinerary(
            group_profiles=profiles,
            candidate_places=places,
            start_location=payload.start_location,
            ant_count=payload.ant_count,
            iterations=payload.iterations,
            seed=payload.seed,
        )

        return {
            "status": "success",
            "data": result,
        }
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
