"""add friend itinerary sharing and leader-approved trip join requests

Revision ID: f1a2b3c4d5e6
Revises: e8f9a0b1c2d3
Create Date: 2026-11-05
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "e8f9a0b1c2d3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trips",
        sa.Column(
            "itinerary_visibility",
            sa.String(length=24),
            nullable=False,
            server_default="private",
        ),
    )
    op.add_column(
        "trips",
        sa.Column("source_itinerary_id", sa.String(), nullable=True),
    )
    op.create_index(
        "ix_trips_source_itinerary_id", "trips", ["source_itinerary_id"]
    )
    op.create_table(
        "trip_join_requests",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("trip_id", sa.String(), nullable=False),
        sa.Column("requester_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=16), server_default="pending", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["requester_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["trip_id"], ["trips.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("trip_id", "requester_id", name="uq_trip_join_request_trip_user"),
    )
    op.create_index("ix_trip_join_requests_trip_id", "trip_join_requests", ["trip_id"])
    op.create_index("ix_trip_join_requests_requester_id", "trip_join_requests", ["requester_id"])
    op.add_column(
        "notifications",
        sa.Column("trip_join_request_id", sa.Uuid(), nullable=True),
    )
    op.create_index(
        "ix_notifications_trip_join_request_id",
        "notifications",
        ["trip_join_request_id"],
    )
    op.create_foreign_key(
        "fk_notifications_trip_join_request_id",
        "notifications",
        "trip_join_requests",
        ["trip_join_request_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_notifications_trip_join_request_id", "notifications", type_="foreignkey"
    )
    op.drop_index("ix_notifications_trip_join_request_id", table_name="notifications")
    op.drop_column("notifications", "trip_join_request_id")
    op.drop_index("ix_trip_join_requests_requester_id", table_name="trip_join_requests")
    op.drop_index("ix_trip_join_requests_trip_id", table_name="trip_join_requests")
    op.drop_table("trip_join_requests")
    op.drop_index("ix_trips_source_itinerary_id", table_name="trips")
    op.drop_column("trips", "source_itinerary_id")
    op.drop_column("trips", "itinerary_visibility")
