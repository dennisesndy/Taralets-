from app.schemas.profile import PreferenceSetupRequest, TripPreferenceSetupRequest


def test_signup_and_profile_preferences_do_not_include_place_count():
    payload = PreferenceSetupRequest(
        activity_tags=["Museums", "Cafes"],
        dietary_preferences=["None"],
        max_budget=2500,
        passenger_type="Regular",
    )

    assert payload.accessibility_preferences == []
    assert "desired_places_per_day" not in payload.model_dump()


def test_trip_preferences_can_include_place_count():
    payload = TripPreferenceSetupRequest(
        activity_tags=["Museums", "Cafes"],
        dietary_preferences=["None"],
        max_budget=2500,
        passenger_type="Regular",
        desired_places_per_day=4,
    )

    assert payload.desired_places_per_day == 4
