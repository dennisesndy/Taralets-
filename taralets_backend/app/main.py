from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from sqlalchemy import text
from fastapi.middleware.cors import CORSMiddleware  # <--- 1. I-IMPORT ITO
from sqlalchemy.ext.asyncio import AsyncSession

from app import models  # noqa: F401  (para ma-register ang lahat ng tables)
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

# <--- 2. IDAGDAG ANG CORS CONFIGURATION NA ITO --->
app = FastAPI(title=settings.APP_NAME, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health", tags=["System"])
async def health(db: AsyncSession = Depends(get_db)):
    version = await db.scalar(text("SELECT PostGIS_Version()"))
    return {"status": "ok", "postgis": version}