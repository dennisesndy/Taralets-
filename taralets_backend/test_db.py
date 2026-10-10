import asyncio

from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import settings


async def main():
    print("DATABASE URL:")
    print(settings.DATABASE_URL)

    engine = create_async_engine(settings.DATABASE_URL)

    try:
        async with engine.connect():
            print("SQLALCHEMY CONNECTED")
    finally:
        await engine.dispose()


asyncio.run(main())