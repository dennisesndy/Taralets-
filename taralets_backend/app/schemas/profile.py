from pydantic import BaseModel, Field, EmailStr

class PreferenceSetupRequest(BaseModel):
    email: EmailStr
    activity_tags: list[str] = Field(min_length=2, description="Minimum of 2 tags required")
    dietary_preferences: list[str]
    max_budget: float
    preferred_pace: str
    passenger_type: str