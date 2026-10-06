from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app import models  # noqa: F401
from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import Base, engine, get_db


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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