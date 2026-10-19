from pydantic import BaseModel, Field
from typing import List, Literal

# Enforce exact matches for frontend consistency
ActivityTag = Literal[
        "Accommodations",
        "Cafes",
        "Desserts / Bakeries",
        "Restaurant / Eatery",
        "Museums",
        "Church / Religious Site",
        "Parks / Plazas",
        "Historical / Tourist Site",
        "Shopping / Retail",
        "Health / Wellness",
        "Entertainment / Leisure",
        "Nightlife / Bars",
        "Government / Services",
        "Others",
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