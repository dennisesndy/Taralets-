import uuid
from sqlalchemy import String, Float, ForeignKey
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from app.core.database import Base

class PreferenceProfile(Base):
    __tablename__ = "preference_profiles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    activity_tags: Mapped[list[str]] = mapped_column(ARRAY(String))
    dietary_preferences: Mapped[list[str]] = mapped_column(ARRAY(String))
    max_budget: Mapped[float] = mapped_column(Float)
    preferred_pace: Mapped[str] = mapped_column(String(50))
    passenger_type: Mapped[str] = mapped_column(String(50))
    accessibility_preferences: Mapped[list[str]] = mapped_column(ARRAY(String))