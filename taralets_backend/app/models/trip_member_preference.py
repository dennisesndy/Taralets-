import uuid

from sqlalchemy import Column, Float, ForeignKey, String
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class TripMemberPreference(Base):
    __tablename__ = "trip_member_preferences"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    trip_member_id = Column(
        String,
        ForeignKey("trip_members.id"),
        unique=True,
        nullable=False,
    )

    activity_tags = Column(ARRAY(String), nullable=False, default=list)
    dietary_preferences = Column(ARRAY(String), nullable=False, default=list)
    max_budget = Column(Float, nullable=False, default=2500.0)
    preferred_pace = Column(String(50), nullable=False, default="Moderate")
    accessibility_preferences = Column(
        ARRAY(String),
        nullable=False,
        default=list,
    )

    trip_member = relationship(
        "TripMember",
        back_populates="preferences",
    )