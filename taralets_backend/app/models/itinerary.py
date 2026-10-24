from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.trip import generate_uuid


class TripItinerary(Base):
    __tablename__ = "trip_itineraries"

    id = Column(
        String,
        primary_key=True,
        default=generate_uuid,
        index=True,
    )

    trip_id = Column(
        String,
        ForeignKey("trips.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    status = Column(
        String(20),
        nullable=False,
        default="draft",
        server_default="draft",
    )

    version = Column(
        Integer,
        nullable=False,
        default=1,
        server_default="1",
    )

    generated_by_member_id = Column(
        String,
        ForeignKey("trip_members.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    preference_snapshot = Column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )

    algorithm_metadata = Column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )

    total_distance_km = Column(Float, nullable=True)
    objective_score = Column(Float, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    finalized_at = Column(
        DateTime(timezone=True),
        nullable=True,
    )

    trip = relationship("Trip", back_populates="itineraries")
    generated_by_member = relationship(
        "TripMember",
        foreign_keys=[generated_by_member_id],
    )
    stops = relationship(
        "TripItineraryStop",
        back_populates="itinerary",
        cascade="all, delete-orphan",
        order_by="TripItineraryStop.order_index",
    )
    confirmations = relationship(
        "TripConfirmation",
        back_populates="itinerary",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('draft', 'review', 'finalized', 'archived')",
            name="ck_trip_itineraries_status",
        ),
        UniqueConstraint(
            "trip_id",
            "version",
            name="uq_trip_itineraries_trip_version",
        ),
    )
