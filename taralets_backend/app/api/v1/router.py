from fastapi import APIRouter

from app.api.v1 import login_view, registration_view, profile, trips
from app.api.v1 import itinerary, discovery, groups

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(registration_view.router)
api_router.include_router(login_view.router)
api_router.include_router(profile.router)

api_router.include_router(
    trips.router,
    prefix="/trips",
    tags=["Trips"],
)

api_router.include_router(
    itinerary.router,
    prefix="/itinerary",
    tags=["Itinerary Generator"],
)

api_router.include_router(
    discovery.router,
    tags=["Discovery"],
)

api_router.include_router(
    groups.router,
    prefix="/groups",
    tags=["Group Recommendations"],
)