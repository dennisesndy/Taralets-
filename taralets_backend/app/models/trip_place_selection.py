from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.trip import generate_uuid


class TripPlaceSelection(Base):
    __tablename__ = "trip_place_selections"

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

    place_id = Column(
        Integer,
        ForeignKey("places.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    selected_by_member_id = Column(
        String,
        ForeignKey("trip_members.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
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

    trip = relationship("Trip", back_populates="place_selections")
    place = relationship("Place")
    selected_by_member = relationship(
        "TripMember",
        back_populates="place_selections",
        foreign_keys=[selected_by_member_id],
    )
    votes = relationship(
        "TripPlaceVote",
        back_populates="selection",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        UniqueConstraint(
            "trip_id",
            "place_id",
            name="uq_trip_place_selections_trip_place",
        ),
    )
