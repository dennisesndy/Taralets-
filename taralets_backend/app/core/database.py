from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings

# Idinagdag ang pool_size at max_overflow para makayanan ang sabay-sabay na requests
engine = create_async_engine(
    settings.DATABASE_URL, 
    echo=settings.DEBUG, 
    pool_pre_ping=True,
    pool_size=20,       
    max_overflow=30     
)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session