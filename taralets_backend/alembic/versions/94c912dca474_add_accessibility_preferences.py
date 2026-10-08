"""add accessibility preferences

Revision ID: 94c912dca474
Revises: 59144bd47c6a
Create Date: 2026-10-09 04:47:33.418471

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "94c912dca474"
down_revision: Union[str, Sequence[str], None] = "59144bd47c6a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "preference_profiles",
        sa.Column(
            "accessibility_preferences",
            postgresql.ARRAY(sa.String()),
            nullable=True,
        ),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column(
        "preference_profiles",
        "accessibility_preferences",
    )