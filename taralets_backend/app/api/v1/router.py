from fastapi import APIRouter

from app.api.v1 import login_view, registration_view

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(registration_view.router)
api_router.include_router(login_view.router)