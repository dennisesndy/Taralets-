
"""add dataset fields to places

Revision ID: 3b124c976e4e
Revises: 1655d85a6d1d
"""

from alembic import op
import sqlalchemy as sa

revision = "3b124c976e4e"
down_revision = "1655d85a6d1d"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("places", sa.Column("master_id", sa.String(), nullable=True))
    op.add_column("places", sa.Column("district_id", sa.String(), nullable=True))
    op.add_column("places", sa.Column("district", sa.String(), nullable=True))
    op.add_column("places", sa.Column("description", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("image_url", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("activity_tags", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("dietary_options", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("entrance_fee_text", sa.String(), nullable=True))
    op.add_column("places", sa.Column("min_cost", sa.Float(), nullable=True))
    op.add_column("places", sa.Column("max_cost", sa.Float(), nullable=True))
    op.add_column("places", sa.Column("accessibility_pets", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("days_open", sa.Text(), nullable=True))
    op.add_column("places", sa.Column("open_time", sa.String(), nullable=True))
    op.add_column("places", sa.Column("close_time", sa.String(), nullable=True))
    op.add_column("places", sa.Column("rating", sa.Float(), nullable=True))
    op.add_column("places", sa.Column("reviews", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("places", "reviews")
    op.drop_column("places", "rating")
    op.drop_column("places", "close_time")
    op.drop_column("places", "open_time")
    op.drop_column("places", "days_open")
    op.drop_column("places", "accessibility_pets")
    op.drop_column("places", "max_cost")
    op.drop_column("places", "min_cost")
    op.drop_column("places", "entrance_fee_text")
    op.drop_column("places", "dietary_options")
    op.drop_column("places", "activity_tags")
    op.drop_column("places", "image_url")
    op.drop_column("places", "description")
    op.drop_column("places", "district")
    op.drop_column("places", "district_id")
    op.drop_column("places", "master_id")
