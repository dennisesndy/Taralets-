import uuid

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base


def generate_uuid():
    return str(uuid.uuid4())


class Trip(Base):
    __tablename__ = "trips"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    code = Column(String, unique=True, index=True, nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, default="")
    status = Column(String, default="lobby")

    date = Column(DateTime, nullable=True)
    date_label = Column(String, default="Today")
    long_date = Column(String, default="Today")

    meetup = Column(String, nullable=False)
    meetup_full = Column(String, nullable=False)
    arrival_target = Column(String, nullable=False)
    wrap_up = Column(String, default="8:00 PM")

    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)

    spots_open = Column(Integer, default=0)
    on_way_count = Column(Integer, default=0)

    group_preferences = Column(
        JSONB,
        nullable=False,
        default=dict,
    )

    # User.id is UUID, so this must also be UUID
    leader_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))

    # Relationships
    leader = relationship("User", foreign_keys=[leader_id])
    members = relationship(
        "TripMember",
        back_populates="trip",
        cascade="all, delete-orphan",
    )


class TripMember(Base):
    __tablename__ = "trip_members"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)

    trip_id = Column(String, ForeignKey("trips.id"), nullable=False)

    # User.id is UUID, so this must also be UUID
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    status = Column(String, default="notReady")
    is_leader = Column(Boolean, default=False)

    # Relationships
    trip = relationship("Trip", back_populates="members")
    user = relationship("User")

    preferences = relationship(
        "TripMemberPreference",
        back_populates="trip_member",
        uselist=False,
        cascade="all, delete-orphan",
    )