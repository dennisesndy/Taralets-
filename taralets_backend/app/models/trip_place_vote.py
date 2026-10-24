from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.trip import generate_uuid


class TripPlaceVote(Base):
    __tablename__ = "trip_place_votes"

    id = Column(
        String,
        primary_key=True,
        default=generate_uuid,
        index=True,
    )

    selection_id = Column(
        String,
        ForeignKey("trip_place_selections.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    trip_member_id = Column(
        String,
        ForeignKey("trip_members.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    vote = Column(
        String(10),
        nullable=False,
        default="ok",
        server_default="ok",
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

    selection = relationship(
        "TripPlaceSelection",
        back_populates="votes",
    )
    trip_member = relationship(
        "TripMember",
        back_populates="place_votes",
    )

    __table_args__ = (
        CheckConstraint(
            "vote IN ('must', 'ok', 'skip')",
            name="ck_trip_place_votes_vote",
        ),
        UniqueConstraint(
            "selection_id",
            "trip_member_id",
            name="uq_trip_place_votes_selection_member",
        ),
    )
