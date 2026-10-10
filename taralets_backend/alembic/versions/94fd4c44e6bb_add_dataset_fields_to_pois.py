"""add_dataset_fields_to_pois

Revision ID: 94fd4c44e6bb
Revises: 3b124c976e4e
Create Date: 2026-10-10 18:00:40.242754

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '94fd4c44e6bb'
down_revision: Union[str, Sequence[str], None] = '3b124c976e4e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('places', sa.Column('latitude', sa.Float(), nullable=True))
    op.add_column('places', sa.Column('longitude', sa.Float(), nullable=True))
    op.alter_column('places', 'image_url',
               existing_type=sa.TEXT(),
               type_=sa.String(),
               existing_nullable=True)
               
    op.alter_column('places', 'activity_tags',
               existing_type=sa.TEXT(),
               type_=postgresql.ARRAY(sa.String()),
               existing_nullable=True,
               postgresql_using="string_to_array(activity_tags, ',')")
               
    op.alter_column('places', 'dietary_options',
               existing_type=sa.TEXT(),
               type_=postgresql.ARRAY(sa.String()),
               existing_nullable=True,
               postgresql_using="string_to_array(dietary_options, ',')")
               
    op.alter_column('places', 'accessibility_pets',
               existing_type=sa.TEXT(),
               type_=postgresql.ARRAY(sa.String()),
               existing_nullable=True,
               postgresql_using="string_to_array(accessibility_pets, ',')")
               
    op.alter_column('places', 'days_open',
               existing_type=sa.TEXT(),
               type_=sa.String(),
               existing_nullable=True)
               
    op.alter_column('places', 'open_time',
               existing_type=sa.VARCHAR(),
               type_=sa.Time(),
               existing_nullable=True,
               postgresql_using="open_time::time")
               
    op.alter_column('places', 'close_time',
               existing_type=sa.VARCHAR(),
               type_=sa.Time(),
               existing_nullable=True,
               postgresql_using="close_time::time")

    op.create_index(op.f('ix_places_category'), 'places', ['category'], unique=False)
    op.create_index(op.f('ix_places_district_id'), 'places', ['district_id'], unique=False)
    op.create_index(op.f('ix_places_master_id'), 'places', ['master_id'], unique=True)
    op.drop_column('places', 'avg_visit_minutes')
    op.drop_column('places', 'opening_hours')
    op.drop_column('places', 'lng')
    op.drop_column('places', 'is_dot_accredited')
    op.drop_column('places', 'tags')
    op.drop_column('places', 'entrance_fee_text')
    op.drop_column('places', 'lat')


def downgrade() -> None:
    """Downgrade schema."""
    op.add_column('places', sa.Column('lat', sa.DOUBLE_PRECISION(precision=53), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('entrance_fee_text', sa.VARCHAR(), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('tags', sa.VARCHAR(), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('is_dot_accredited', sa.BOOLEAN(), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('lng', sa.DOUBLE_PRECISION(precision=53), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('opening_hours', sa.VARCHAR(), autoincrement=False, nullable=True))
    op.add_column('places', sa.Column('avg_visit_minutes', sa.INTEGER(), autoincrement=False, nullable=True))
    op.drop_index(op.f('ix_places_master_id'), table_name='places')
    op.drop_index(op.f('ix_places_district_id'), table_name='places')
    op.drop_index(op.f('ix_places_category'), table_name='places')
    op.alter_column('places', 'close_time',
               existing_type=sa.Time(),
               type_=sa.VARCHAR(),
               existing_nullable=True)
    op.alter_column('places', 'open_time',
               existing_type=sa.Time(),
               type_=sa.VARCHAR(),
               existing_nullable=True)
    op.alter_column('places', 'days_open',
               existing_type=sa.String(),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.alter_column('places', 'accessibility_pets',
               existing_type=postgresql.ARRAY(sa.String()),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.alter_column('places', 'dietary_options',
               existing_type=postgresql.ARRAY(sa.String()),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.alter_column('places', 'activity_tags',
               existing_type=postgresql.ARRAY(sa.String()),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.alter_column('places', 'image_url',
               existing_type=sa.String(),
               type_=sa.TEXT(),
               existing_nullable=True)
    op.drop_column('places', 'longitude')
    op.drop_column('places', 'latitude')