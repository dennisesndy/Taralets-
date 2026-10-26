"""add desired places per day

Revision ID: 6a9c3f2d1b77
Revises: 1655d85a6d1d
"""
from alembic import op
import sqlalchemy as sa

revision = "6a9c3f2d1b77"
down_revision = "1655d85a6d1d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Retain historical values, while allowing new preference rows to omit pace.
    op.alter_column("preference_profiles", "preferred_pace", nullable=True)
    op.alter_column("trip_member_preferences", "preferred_pace", nullable=True)
    op.add_column("trip_member_preferences", sa.Column("desired_places_per_day", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("trip_member_preferences", "desired_places_per_day")
