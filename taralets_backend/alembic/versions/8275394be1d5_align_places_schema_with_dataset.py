"""align places schema with dataset

Revision ID: 8275394be1d5
Revises: 94fd4c44e6bb
Create Date: 2026-10-11 15:26:01.534352

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '8275394be1d5'
down_revision: Union[str, Sequence[str], None] = '94fd4c44e6bb'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade():
    # Add the new dataset fields.
    op.add_column(
        "places",
        sa.Column("sub_category_1", sa.String(150), nullable=True),
    )
    op.add_column(
        "places",
        sa.Column("sub_category_2", sa.String(150), nullable=True),
    )
    op.add_column(
        "places",
        sa.Column("sub_category_3", sa.String(150), nullable=True),
    )
    op.alter_column(
        "places",
        "entrance_fee",
        existing_type=sa.String(),
        type_=sa.Text(),
        existing_nullable=True,
        postgresql_using="entrance_fee::text",
    )
    op.add_column(
        "places",
        sa.Column("pet_friendly", sa.Boolean(), nullable=True),
    )
    op.add_column(
        "places",
        sa.Column("wheelchair_accessible", sa.Boolean(), nullable=True),
    )
    op.add_column(
        "places",
        sa.Column("good_for_children", sa.Boolean(), nullable=True),
    )

    # Match the model's numeric column types.
    op.alter_column(
        "places",
        "min_cost",
        existing_type=sa.Float(),
        type_=sa.Numeric(10, 2),
        existing_nullable=True,
        postgresql_using="min_cost::numeric(10,2)",
    )
    op.alter_column(
        "places",
        "max_cost",
        existing_type=sa.Float(),
        type_=sa.Numeric(10, 2),
        existing_nullable=True,
        postgresql_using="max_cost::numeric(10,2)",
    )
    op.alter_column(
        "places",
        "rating",
        existing_type=sa.Float(),
        type_=sa.Numeric(3, 2),
        existing_nullable=True,
        postgresql_using="rating::numeric(3,2)",
    )

    # Use text for image URLs and entrance-related descriptions.
    op.alter_column(
        "places",
        "image_url",
        existing_type=sa.String(),
        type_=sa.Text(),
        existing_nullable=True,
        postgresql_using="image_url::text",
    )

    # Convert days_open from a string to an array.
    op.alter_column(
        "places",
        "days_open",
        existing_type=sa.String(),
        type_=postgresql.ARRAY(sa.String()),
        existing_nullable=True,
        postgresql_using=(
            "CASE "
            "WHEN days_open IS NULL OR btrim(days_open) = '' "
            "THEN ARRAY[]::varchar[] "
            "ELSE string_to_array(days_open, ',') "
            "END"
        ),
    )


def downgrade():
    # Restore the previous days_open representation.
    op.alter_column(
        "places",
        "days_open",
        existing_type=postgresql.ARRAY(sa.String()),
        type_=sa.String(),
        existing_nullable=True,
        postgresql_using="array_to_string(days_open, ',')",
    )

    op.alter_column(
        "places",
        "image_url",
        existing_type=sa.Text(),
        type_=sa.String(),
        existing_nullable=True,
        postgresql_using="image_url::varchar",
    )

    op.alter_column(
        "places",
        "rating",
        existing_type=sa.Numeric(3, 2),
        type_=sa.Float(),
        existing_nullable=True,
        postgresql_using="rating::double precision",
    )
    op.alter_column(
        "places",
        "max_cost",
        existing_type=sa.Numeric(10, 2),
        type_=sa.Float(),
        existing_nullable=True,
        postgresql_using="max_cost::double precision",
    )
    op.alter_column(
        "places",
        "min_cost",
        existing_type=sa.Numeric(10, 2),
        type_=sa.Float(),
        existing_nullable=True,
        postgresql_using="min_cost::double precision",
    )

    op.drop_column("places", "good_for_children")
    op.drop_column("places", "wheelchair_accessible")
    op.drop_column("places", "pet_friendly")
    op.drop_column("places", "entrance_fee")
    op.drop_column("places", "sub_category_3")
    op.drop_column("places", "sub_category_2")
    op.drop_column("places", "sub_category_1")