
from sqlalchemy import (
    Boolean,
    Column,
    Float,
    Integer,
    Numeric,
    String,
    Text,
    Time,
)
from sqlalchemy.dialects.postgresql import ARRAY

from app.core.database import Base


class Place(Base):
    __tablename__ = "places"

    # Keep the existing primary key for database relationships
    id = Column(Integer, primary_key=True, index=True)

    master_id = Column(String(50), unique=True, index=True, nullable=False)
    district_id = Column(String(50), index=True)
    district = Column(String(100))
    name = Column(String(255), index=True)
    category = Column(String(100), index=True)

    sub_category_1 = Column(String(150), nullable=True)
    sub_category_2 = Column(String(150), nullable=True)
    sub_category_3 = Column(String(150), nullable=True)

    description = Column(Text)
    image_url = Column(Text)
    address = Column(Text)

    latitude = Column(Float)
    longitude = Column(Float)

    activity_tags = Column(ARRAY(String), default=list)
    dietary_options = Column(ARRAY(String), default=list)

    entrance_fee = Column(Text)
    min_cost = Column(Numeric(10, 2), default=0.0)
    max_cost = Column(Numeric(10, 2), default=0.0)

    pet_friendly = Column(Boolean, nullable=True)
    wheelchair_accessible = Column(Boolean, nullable=True)
    good_for_children = Column(Boolean, nullable=True)

    days_open = Column(ARRAY(String))
    open_time = Column(Time, nullable=True)
    close_time = Column(Time, nullable=True)

    rating = Column(Numeric(3, 2), default=0.0)
    reviews = Column(Integer, default=0)

    # Temporary compatibility for existing recommendation code
    @property
    def accessibility_pets(self):
        options = []

        if self.wheelchair_accessible:
            options.append("Wheelchair Accessible")

        if self.pet_friendly:
            options.append("Pet Friendly")

        if self.good_for_children:
            options.append("Good for Children")

        return options
