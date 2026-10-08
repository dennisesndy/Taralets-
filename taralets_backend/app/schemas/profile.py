from pydantic import BaseModel, Field
from typing import List, Literal

# Enforce exact matches for frontend consistency
ActivityTag = Literal[
    "Accommodation", "Cafe", "Restaurant / Eatery", "Museum", 
    "Church / Religious Site", "Park / Plaza", "Historical / Tourist Site", 
    "Shop / Retail", "Health & Wellness", "Entertainment", 
    "Recreation & Arts", "Community & Events"
]

DietaryTag = Literal['None', 'Halal', 'Vegan', 'Budget-Friendly']
PaceTag = Literal['Fast', 'Moderate', 'Leisure']
AccessibilityTag = Literal['Good for children', 'Pet friendly', 'Wheelchair accessible']

class PreferenceSetupRequest(BaseModel):
    activity_tags: List[ActivityTag] = Field(
        min_length=2,
        description="Minimum of 2 tags required"
    )
    dietary_preferences: List[DietaryTag]
    max_budget: float
    preferred_pace: PaceTag
    passenger_type: str
    accessibility_preferences: List[AccessibilityTag] = []