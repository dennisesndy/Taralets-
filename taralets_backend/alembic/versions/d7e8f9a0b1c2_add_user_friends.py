"""add mutual user friendships

Revision ID: d7e8f9a0b1c2
Revises: c4d5e6f7a890
Create Date: 2026-11-05
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d7e8f9a0b1c2"
down_revision: Union[str, Sequence[str], None] = "c4d5e6f7a890"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_friends",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("friend_id", sa.Uuid(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
        sa.ForeignKeyConstraint(["friend_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "friend_id", name="uq_user_friends_pair"),
    )
    op.create_index("ix_user_friends_user_id", "user_friends", ["user_id"])
    op.create_index("ix_user_friends_friend_id", "user_friends", ["friend_id"])


def downgrade() -> None:
    op.drop_index("ix_user_friends_friend_id", table_name="user_friends")
    op.drop_index("ix_user_friends_user_id", table_name="user_friends")
    op.drop_table("user_friends")
