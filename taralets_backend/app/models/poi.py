from sqlalchemy import Column, Integer, String, Float, Boolean
from app.core.database import Base

class Place(Base):
    __tablename__ = "places"

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