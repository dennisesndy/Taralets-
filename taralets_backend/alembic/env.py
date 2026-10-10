import asyncio
from logging.config import fileConfig


from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from alembic import context

# 1. Idagdag ang mga imports na ito mula sa iyong app
from app.core.config import settings
from app.core.database import Base
import app.models
import app.models.preference_profile
import app.models.trip_member_preference  # I-load ang mga tables na ginawa natin
import sys
import asyncio

# Fix for Windows async database driver compatibility
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from logging.config import fileConfig

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 2. I-override ang database URL gamit ang nasa .env mo
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

# 3. I-set ang target_metadata sa metadata ng iyong Base
target_metadata = Base.metadata

# --- PANATILIHIN ANG NATITIRANG BAHAGI NG FILE SA IBABA NITO ---
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    This configures the context with just a URL
    and not an Engine, though an Engine is acceptable
    here as well.  By skipping the Engine creation
    we don't even need a DBAPI to be available.

    Calls to context.execute() here emit the given string to the
    script output.

    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def include_object(object, name, type_, reflected, compare_to):
    if type_ == "table" and name == "spatial_ref_sys":
        return False
    return True

def do_run_migrations(connection: Connection) -> None:
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_object=include_object # <--- Idagdag itong linya
        # ... any other existing configurations
    )
    
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """In this scenario we need to create an Engine
    and associate a connection with the context.

    """

    connectable = async_engine_from_config(
        {"sqlalchemy.url": settings.DATABASE_URL},
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""

    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

def include_object(object, name, type_, reflected, compare_to):
    # Ignore PostGIS tables
    if type_ == "table" and name == "spatial_ref_sys":
        return False
    return True