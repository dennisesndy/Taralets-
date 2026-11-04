"""merge trip duration and preference migration branches

Revision ID: c4d5e6f7a890
Revises: 6a9c3f2d1b77, b31d2e8f4c6a
Create Date: 2026-11-05
"""

from typing import Sequence, Union


revision: str = "c4d5e6f7a890"
down_revision: Union[str, Sequence[str], None] = (
    "6a9c3f2d1b77",
    "b31d2e8f4c6a",
)
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
