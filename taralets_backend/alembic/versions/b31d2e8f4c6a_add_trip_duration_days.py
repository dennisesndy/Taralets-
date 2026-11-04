"""add flexible trip duration

Revision ID: b31d2e8f4c6a
Revises: a15f1e2c3d4b
Create Date: 2026-11-05
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "b31d2e8f4c6a"
down_revision: Union[str, Sequence[str], None] = "a15f1e2c3d4b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trips",
        sa.Column("duration_days", sa.Integer(), nullable=False, server_default="1"),
    )


def downgrade() -> None:
    op.drop_column("trips", "duration_days")
