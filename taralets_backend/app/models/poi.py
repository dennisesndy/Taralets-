from sqlalchemy import Column, Integer, String, Float, Text, Time
from sqlalchemy.dialects.postgresql import ARRAY
from app.core.database import Base

class Place(Base):
    __tablename__ = "places"

    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(String, unique=True, index=True)
    district_id = Column(String, index=True)
    district = Column(String)
    name = Column(String, index=True)
    category = Column(String, index=True)
    description = Column(Text)
    image_url = Column(String)
    address = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    
    # New Columns from Dataset
    activity_tags = Column(ARRAY(String), default=[])
    dietary_options = Column(ARRAY(String), default=[])
    entrance_fee = Column(Float, default=0.0)
    min_cost = Column(Float, default=0.0)
    max_cost = Column(Float, default=0.0)
    accessibility_pets = Column(ARRAY(String), default=[])
    days_open = Column(String) # e.g., "Mon-Sun"
    open_time = Column(Time, nullable=True)
    close_time = Column(Time, nullable=True)
    
    rating = Column(Float, default=0.0)
    reviews = Column(Integer, default=0)