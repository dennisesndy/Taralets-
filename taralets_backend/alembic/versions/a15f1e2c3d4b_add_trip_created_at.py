"""add trip creation timestamp

Revision ID: a15f1e2c3d4b
Revises: 8f2c1d4e6a7b
Create Date: 2026-10-26

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a15f1e2c3d4b"
down_revision: Union[str, Sequence[str], None] = "8f2c1d4e6a7b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "trips",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("trips", "created_at")
