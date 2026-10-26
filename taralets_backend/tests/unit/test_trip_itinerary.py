from datetime import date

from app.services.itinerary.trip_itinerary import (
    _unique_strings,
    build_trip_itinerary,
    summarize_group_preferences,
)


def _place(**overrides):
    place = {
        "id": 1,
        "master_id": "MNL-TEST",
        "name": "Test Museum",
        "category": "Museums",
        "district": "Manila",
        "address": "Test address",
        "description": "",
        "image_url": "",
        "latitude": 14.59,
        "longitude": 120.98,
        "activity_tags": ["Museums"],
        "dietary_options": [],
        "entrance_fee": None,
        "min_cost": 0,
        "max_cost": 0,
        "days_open": ["Monday"],
        "open_time": "10:00:00",
        "close_time": "17:00:00",
        "rating": 4.5,
        "reviews": 100,
    }
    place.update(overrides)
    return place


def _profiles():
    return [
        {
            "activity_tags": ["Museums"],
            "dietary_preferences": [],
            "max_budget": 1000.0,
            "desired_places_per_day": 4,
            "accessibility_preferences": [],
            "has_preferences": True,
        }
    ]


def test_schedule_waits_for_opening_time():
    result = build_trip_itinerary(
        _profiles(),
        [_place()],
        trip_date=date(2026, 10, 26),
        start_time="09:00",
    )

    stop = result["stops"][0]

    assert stop["start_time"] == "10:00"
    assert stop["feasible"] is True
    assert "Opens at 10:00" in (stop["warning"] or "")


def test_group_target_averages_only_saved_member_values():
    profiles = [
        {"activity_tags": [], "has_preferences": True, "desired_places_per_day": 2},
        {"activity_tags": [], "has_preferences": False, "desired_places_per_day": None},
        {"activity_tags": [], "has_preferences": True, "desired_places_per_day": 5},
    ]
    _, target = summarize_group_preferences(profiles)
    assert target == 4


def test_itinerary_caps_stops_at_derived_target():
    profiles = [{
        "activity_tags": ["Museums"], "has_preferences": True,
        "desired_places_per_day": 2,
    }]
    places = [_place(id=index, master_id=f"TEST-{index}") for index in range(1, 5)]
    result = build_trip_itinerary(profiles, places)
    assert result["summary"]["total_stops"] == 2


def test_dataset_array_tags_are_displayed_without_serialization_wrappers():
    assert _unique_strings([
        '{"Filipino Restaurant"}',
        '{"Standard Food"}',
    ]) == ["Filipino Restaurant", "Standard Food"]


def test_full_week_range_is_not_treated_as_closed():
    result = build_trip_itinerary(
        _profiles(),
        [_place(days_open=["Monday - Sunday"])],
        trip_date=date(2026, 10, 26),
        start_time="10:00",
    )

    stop = result["stops"][0]

    assert stop["feasible"] is True


def test_closed_day_is_marked_infeasible():
    result = build_trip_itinerary(
        _profiles(),
        [_place(days_open=["Tuesday"])],
        trip_date=date(2026, 10, 26),
        start_time="10:00",
    )

    stop = result["stops"][0]

    assert stop["feasible"] is False
    assert "Closed on Monday" in (stop["warning"] or "")


def test_summary_uses_real_stop_fields():
    result = build_trip_itinerary(
        _profiles(),
        [_place(open_time="08:00:00", close_time="18:00:00")],
        trip_date=date(2026, 10, 26),
        start_time="09:00",
    )

    stop = result["stops"][0]
    summary = result["summary"]

    assert stop["duration_minutes"] == 75
    assert stop["group_score"] > 0
    assert summary["total_stops"] == 1
    assert summary["total_duration_minutes"] == 75
    assert summary["total_budget"] == 0
