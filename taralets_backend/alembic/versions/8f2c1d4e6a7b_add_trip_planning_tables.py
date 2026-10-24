"""add trip planning tables

Revision ID: 8f2c1d4e6a7b
Revises: 8275394be1d5
Create Date: 2026-10-24 22:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "8f2c1d4e6a7b"
down_revision: Union[str, Sequence[str], None] = "8275394be1d5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create the trip planning schema."""
    op.add_column(
        "trips",
        sa.Column(
            "planning_status",
            sa.String(length=20),
            nullable=False,
            server_default="selecting",
        ),
    )
    op.create_check_constraint(
        "ck_trips_planning_status",
        "trips",
        "planning_status IN "
        "('selecting', 'voting', 'review', 'finalized')",
    )

    op.create_table(
        "trip_place_selections",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("trip_id", sa.String(), nullable=False),
        sa.Column("place_id", sa.Integer(), nullable=False),
        sa.Column(
            "selected_by_member_id",
            sa.String(),
            nullable=True,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["place_id"],
            ["places.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["selected_by_member_id"],
            ["trip_members.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "trip_id",
            "place_id",
            name="uq_trip_place_selections_trip_place",
        ),
    )
    op.create_index(
        "ix_trip_place_selections_id",
        "trip_place_selections",
        ["id"],
    )
    op.create_index(
        "ix_trip_place_selections_trip_id",
        "trip_place_selections",
        ["trip_id"],
    )
    op.create_index(
        "ix_trip_place_selections_place_id",
        "trip_place_selections",
        ["place_id"],
    )
    op.create_index(
        "ix_trip_place_selections_selected_by_member_id",
        "trip_place_selections",
        ["selected_by_member_id"],
    )

    op.create_table(
        "trip_place_votes",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("selection_id", sa.String(), nullable=False),
        sa.Column("trip_member_id", sa.String(), nullable=False),
        sa.Column(
            "vote",
            sa.String(length=10),
            nullable=False,
            server_default="ok",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "vote IN ('must', 'ok', 'skip')",
            name="ck_trip_place_votes_vote",
        ),
        sa.ForeignKeyConstraint(
            ["selection_id"],
            ["trip_place_selections.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_member_id"],
            ["trip_members.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "selection_id",
            "trip_member_id",
            name="uq_trip_place_votes_selection_member",
        ),
    )
    op.create_index(
        "ix_trip_place_votes_id",
        "trip_place_votes",
        ["id"],
    )
    op.create_index(
        "ix_trip_place_votes_selection_id",
        "trip_place_votes",
        ["selection_id"],
    )
    op.create_index(
        "ix_trip_place_votes_trip_member_id",
        "trip_place_votes",
        ["trip_member_id"],
    )

    op.create_table(
        "trip_itineraries",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("trip_id", sa.String(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="draft",
        ),
        sa.Column(
            "version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
        sa.Column(
            "generated_by_member_id",
            sa.String(),
            nullable=True,
        ),
        sa.Column(
            "preference_snapshot",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column(
            "algorithm_metadata",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column("total_distance_km", sa.Float(), nullable=True),
        sa.Column("objective_score", sa.Float(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "finalized_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.CheckConstraint(
            "status IN "
            "('draft', 'review', 'finalized', 'archived')",
            name="ck_trip_itineraries_status",
        ),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["generated_by_member_id"],
            ["trip_members.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "trip_id",
            "version",
            name="uq_trip_itineraries_trip_version",
        ),
    )
    op.create_index(
        "ix_trip_itineraries_id",
        "trip_itineraries",
        ["id"],
    )
    op.create_index(
        "ix_trip_itineraries_trip_id",
        "trip_itineraries",
        ["trip_id"],
    )
    op.create_index(
        "ix_trip_itineraries_generated_by_member_id",
        "trip_itineraries",
        ["generated_by_member_id"],
    )

    op.create_table(
        "trip_itinerary_stops",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("itinerary_id", sa.String(), nullable=False),
        sa.Column("place_id", sa.Integer(), nullable=False),
        sa.Column(
            "day_number",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column("end_time", sa.Time(), nullable=True),
        sa.Column(
            "duration_minutes",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "travel_minutes_from_previous",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column("group_score", sa.Float(), nullable=True),
        sa.Column(
            "constraint_check",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["itinerary_id"],
            ["trip_itineraries.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["place_id"],
            ["places.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "itinerary_id",
            "day_number",
            "order_index",
            name="uq_trip_itinerary_stops_order",
        ),
    )
    op.create_index(
        "ix_trip_itinerary_stops_id",
        "trip_itinerary_stops",
        ["id"],
    )
    op.create_index(
        "ix_trip_itinerary_stops_itinerary_id",
        "trip_itinerary_stops",
        ["itinerary_id"],
    )
    op.create_index(
        "ix_trip_itinerary_stops_place_id",
        "trip_itinerary_stops",
        ["place_id"],
    )

    op.create_table(
        "trip_confirmations",
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("itinerary_id", sa.String(), nullable=False),
        sa.Column("trip_member_id", sa.String(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "confirmed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'confirmed', 'declined')",
            name="ck_trip_confirmations_status",
        ),
        sa.ForeignKeyConstraint(
            ["itinerary_id"],
            ["trip_itineraries.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["trip_member_id"],
            ["trip_members.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "itinerary_id",
            "trip_member_id",
            name="uq_trip_confirmations_itinerary_member",
        ),
    )
    op.create_index(
        "ix_trip_confirmations_id",
        "trip_confirmations",
        ["id"],
    )
    op.create_index(
        "ix_trip_confirmations_itinerary_id",
        "trip_confirmations",
        ["itinerary_id"],
    )
    op.create_index(
        "ix_trip_confirmations_trip_member_id",
        "trip_confirmations",
        ["trip_member_id"],
    )


def downgrade() -> None:
    """Drop the trip planning schema."""
    op.drop_index(
        "ix_trip_confirmations_trip_member_id",
        table_name="trip_confirmations",
    )
    op.drop_index(
        "ix_trip_confirmations_itinerary_id",
        table_name="trip_confirmations",
    )
    op.drop_index(
        "ix_trip_confirmations_id",
        table_name="trip_confirmations",
    )
    op.drop_table("trip_confirmations")

    op.drop_index(
        "ix_trip_itinerary_stops_place_id",
        table_name="trip_itinerary_stops",
    )
    op.drop_index(
        "ix_trip_itinerary_stops_itinerary_id",
        table_name="trip_itinerary_stops",
    )
    op.drop_index(
        "ix_trip_itinerary_stops_id",
        table_name="trip_itinerary_stops",
    )
    op.drop_table("trip_itinerary_stops")

    op.drop_index(
        "ix_trip_itineraries_generated_by_member_id",
        table_name="trip_itineraries",
    )
    op.drop_index(
        "ix_trip_itineraries_trip_id",
        table_name="trip_itineraries",
    )
    op.drop_index(
        "ix_trip_itineraries_id",
        table_name="trip_itineraries",
    )
    op.drop_table("trip_itineraries")

    op.drop_index(
        "ix_trip_place_votes_trip_member_id",
        table_name="trip_place_votes",
    )
    op.drop_index(
        "ix_trip_place_votes_selection_id",
        table_name="trip_place_votes",
    )
    op.drop_index(
        "ix_trip_place_votes_id",
        table_name="trip_place_votes",
    )
    op.drop_table("trip_place_votes")

    op.drop_index(
        "ix_trip_place_selections_selected_by_member_id",
        table_name="trip_place_selections",
    )
    op.drop_index(
        "ix_trip_place_selections_place_id",
        table_name="trip_place_selections",
    )
    op.drop_index(
        "ix_trip_place_selections_trip_id",
        table_name="trip_place_selections",
    )
    op.drop_index(
        "ix_trip_place_selections_id",
        table_name="trip_place_selections",
    )
    op.drop_table("trip_place_selections")

    op.drop_constraint(
        "ck_trips_planning_status",
        "trips",
        type_="check",
    )
    op.drop_column("trips", "planning_status")
