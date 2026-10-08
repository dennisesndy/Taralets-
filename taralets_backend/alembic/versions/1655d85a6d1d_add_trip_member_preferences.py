"""add trip member preferences

Revision ID: 1655d85a6d1d
Revises: 94c912dca474
Create Date: 2026-10-09 05:06:52.574969

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '1655d85a6d1d'
down_revision: Union[str, Sequence[str], None] = '94c912dca474'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "trip_member_preferences",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("trip_member_id", sa.String(), nullable=False),
        sa.Column(
            "activity_tags",
            postgresql.ARRAY(sa.String()),
            nullable=False,
        ),
        sa.Column(
            "dietary_preferences",
            postgresql.ARRAY(sa.String()),
            nullable=False,
        ),
        sa.Column("max_budget", sa.Float(), nullable=False),
        sa.Column(
            "preferred_pace",
            sa.String(length=50),
            nullable=False,
        ),
        sa.Column(
            "accessibility_preferences",
            postgresql.ARRAY(sa.String()),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["trip_member_id"],
            ["trip_members.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("trip_member_id"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table("trip_member_preferences")