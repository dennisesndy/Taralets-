
from sqlalchemy import Column, Integer, String, Float, Boolean, Text
from app.core.database import Base


class Place(Base):
    __tablename__ = "places"

    # Existing fields - preserve for compatibility
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    category = Column(String)
    tags = Column(String)
    address = Column(String)
    lat = Column(Float)
    lng = Column(Float)
    opening_hours = Column(String, nullable=True)
    avg_visit_minutes = Column(Integer, nullable=True)
    entrance_fee = Column(Float, nullable=True)
    is_dot_accredited = Column(Boolean, default=False)

    # Dataset fields
    master_id = Column(String, nullable=True)
    district_id = Column(String, nullable=True)
    district = Column(String, nullable=True)
    description = Column(Text, nullable=True)
    image_url = Column(Text, nullable=True)
    activity_tags = Column(Text, nullable=True)
    dietary_options = Column(Text, nullable=True)
    entrance_fee_text = Column(String, nullable=True)
    min_cost = Column(Float, nullable=True)
    max_cost = Column(Float, nullable=True)
    accessibility_pets = Column(Text, nullable=True)
    days_open = Column(Text, nullable=True)
    open_time = Column(String, nullable=True)
    close_time = Column(String, nullable=True)
    rating = Column(Float, nullable=True)
    reviews = Column(Integer, nullable=True)
