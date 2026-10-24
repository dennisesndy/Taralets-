from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.trip import generate_uuid


class TripConfirmation(Base):
    __tablename__ = "trip_confirmations"

    id = Column(
        String,
        primary_key=True,
        default=generate_uuid,
        index=True,
    )

    itinerary_id = Column(
        String,
        ForeignKey("trip_itineraries.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    trip_member_id = Column(
        String,
        ForeignKey("trip_members.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    status = Column(
        String(20),
        nullable=False,
        default="pending",
        server_default="pending",
    )

    note = Column(Text, nullable=True)

    confirmed_at = Column(
        DateTime(timezone=True),
        nullable=True,
    )

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

    itinerary = relationship(
        "TripItinerary",
        back_populates="confirmations",
    )
    trip_member = relationship(
        "TripMember",
        back_populates="itinerary_confirmations",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'confirmed', 'declined')",
            name="ck_trip_confirmations_status",
        ),
        UniqueConstraint(
            "itinerary_id",
            "trip_member_id",
            name="uq_trip_confirmations_itinerary_member",
        ),
    )
