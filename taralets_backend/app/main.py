from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app import models  # noqa: F401
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import engine, get_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Schema changes are managed by Alembic. Do not create or alter tables
    # automatically on startup.
    yield
    await engine.dispose()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)

# CORS Configuration
# CORS Configuration


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)



# Central API Router
app.include_router(api_router)


@app.get("/health", tags=["System"])
async def health(db: AsyncSession = Depends(get_db)):
    version = await db.scalar(text("SELECT PostGIS_Version()"))
    return {"status": "ok", "postgis": version}