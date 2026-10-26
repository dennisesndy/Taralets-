from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from datetime import datetime
from enum import Enum

class TripStatus(str, Enum):
    lobby = "lobby"
    active = "active"
    completed = "completed"
    cancelled = "cancelled"

class GroupPreferencesSchema(BaseModel):
    categories: List[str]
    budget: str
    walking: str

class CreateTripRequest(BaseModel):
    code: str
    title: str
    description: Optional[str] = ""
    date: datetime
    meetup_time: str 
    wrap_up_time: str 
    meetup_name: str
    latitude: float
    longitude: float
    member_names: List[str]
    preferences: GroupPreferencesSchema

class InviteMemberRequest(BaseModel):
    username: str

class UpdateTripRequest(BaseModel):
    title: str
    description: Optional[str] = ""
    date: Optional[datetime] = None
    date_label: str
    long_date: str
    arrival_target: str
    wrap_up: str
    meetup: str
    meetup_full: str
    latitude: float
    longitude: float


class GenerateTripItineraryRequest(BaseModel):
    place_ids: List[str] = Field(min_length=1, max_length=50)
    date: Optional[datetime] = None
    start_time: Optional[str] = None
    start_location: Optional[Dict[str, float]] = None