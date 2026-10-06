from fastapi import APIRouter
from app.api.v1.endpoints import itinerary

api_router = APIRouter(prefix="/api/v1")

# Include Itinerary Endpoints
api_router.include_router(
    itinerary.router,
    prefix="/itinerary",
    tags=["Itinerary Generator"]
)