from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.trip import generate_uuid


class TripItineraryStop(Base):
    __tablename__ = "trip_itinerary_stops"

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

    place_id = Column(
        Integer,
        ForeignKey("places.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    day_number = Column(
        Integer,
        nullable=False,
        default=1,
        server_default="1",
    )

    order_index = Column(Integer, nullable=False)

    start_time = Column(Time, nullable=True)
    end_time = Column(Time, nullable=True)

    duration_minutes = Column(Integer, nullable=True)
    travel_minutes_from_previous = Column(
        Integer,
        nullable=True,
    )

    group_score = Column(Float, nullable=True)

    constraint_check = Column(
        JSONB,
        nullable=False,
        default=dict,
        server_default=text("'{}'::jsonb"),
    )

    notes = Column(Text, nullable=True)

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
        back_populates="stops",
    )
    place = relationship("Place")

    __table_args__ = (
        UniqueConstraint(
            "itinerary_id",
            "day_number",
            "order_index",
            name="uq_trip_itinerary_stops_order",
        ),
    )
