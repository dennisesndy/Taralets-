from fastapi import APIRouter

from app.api.v1 import login_view, registration_view
from app.api.v1 import login_view, registration_view, profile # Idinagdag ang profile
from app.api.v1 import itinerary
from app.api.v1 import discovery



api_router = APIRouter(prefix="/api/v1")
api_router.include_router(registration_view.router)
api_router.include_router(login_view.router)
api_router.include_router(profile.router) # Idinagdag
api_router.include_router(
    itinerary.router, prefix="/itinerary", tags=["Itinerary Generator"]
)
api_router.include_router(discovery.router, tags=["Discovery"])