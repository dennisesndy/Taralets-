from types import SimpleNamespace

from app.services.trip_service import (
    DEFAULT_MAX_BUDGET,
    DEFAULT_PREFERRED_PACE,
    build_group_profiles,
)


def make_preference(**overrides):
    values = {
        "activity_tags": ["Museums"],
        "dietary_preferences": ["Halal"],
        "max_budget": 1800.0,
        "preferred_pace": "Fast",
        "accessibility_preferences": ["Wheelchair accessible"],
    }
    values.update(overrides)
    return SimpleNamespace(**values)


def make_member(
    member_id,
    user_id=None,
    is_leader=False,
    status="notReady",
    preferences=None,
):
    return SimpleNamespace(
        id=member_id,
        user_id=user_id or f"user-{member_id}",
        is_leader=is_leader,
        status=status,
        preferences=preferences,
    )


def make_trip(*members):
    return SimpleNamespace(members=list(members))


def test_maps_saved_preferences():
    trip = make_trip(
        make_member("m1", preferences=make_preference())
    )

    profiles = build_group_profiles(trip)

    assert len(profiles) == 1

    profile = profiles[0]

    assert profile["member_id"] == "m1"
    assert profile["user_id"] == "user-m1"
    assert profile["has_preferences"] is True
    assert profile["source"] == "member"
    assert profile["activity_tags"] == ["Museums"]
    assert profile["activities"] == ["Museums"]
    assert profile["dietary_preferences"] == ["Halal"]
    assert profile["max_budget"] == 1800.0
    assert profile["preferred_pace"] == "Fast"
    assert profile["accessibility_preferences"] == [
        "Wheelchair accessible",
    ]


def test_includes_member_without_preferences():
    trip = make_trip(
        make_member("m1", preferences=make_preference()),
        make_member("m2"),
    )

    profiles = build_group_profiles(trip)

    assert len(profiles) == 2

    default = next(
        profile
        for profile in profiles
        if profile["member_id"] == "m2"
    )

    assert default["has_preferences"] is False
    assert default["source"] == "default"
    assert default["activity_tags"] == []
    assert default["dietary_preferences"] == []
    assert default["max_budget"] == DEFAULT_MAX_BUDGET
    assert default["preferred_pace"] == DEFAULT_PREFERRED_PACE
    assert default["accessibility_preferences"] == []


def test_leader_is_first():
    trip = make_trip(
        make_member("m2"),
        make_member("m1", is_leader=True),
    )

    profiles = build_group_profiles(trip)

    assert [profile["member_id"] for profile in profiles] == [
        "m1",
        "m2",
    ]
    assert profiles[0]["is_leader"] is True


def test_invalid_values_fall_back():
    preference = make_preference(
        max_budget=None,
        preferred_pace="warp",
    )
    trip = make_trip(
        make_member("m1", preferences=preference)
    )

    profile = build_group_profiles(trip)[0]

    assert profile["max_budget"] == DEFAULT_MAX_BUDGET
    assert profile["preferred_pace"] == DEFAULT_PREFERRED_PACE


def test_negative_budget_falls_back():
    preference = make_preference(max_budget=-100)
    trip = make_trip(
        make_member("m1", preferences=preference)
    )

    profile = build_group_profiles(trip)[0]

    assert profile["max_budget"] == DEFAULT_MAX_BUDGET


def test_tags_are_cleaned_and_deduplicated():
    preference = make_preference(
        activity_tags=[
            "Museums",
            " museums ",
            "None",
            None,
            "Cafes",
        ],
        dietary_preferences=["None", "Halal", "Halal"],
        accessibility_preferences=["Pet friendly", "none"],
    )
    trip = make_trip(
        make_member("m1", preferences=preference)
    )

    profile = build_group_profiles(trip)[0]

    assert profile["activity_tags"] == ["Museums", "Cafes"]
    assert profile["dietary_preferences"] == ["Halal"]
    assert profile["accessibility_preferences"] == ["Pet friendly"]


def test_pace_is_case_insensitive():
    preference = make_preference(preferred_pace="leisure")
    trip = make_trip(
        make_member("m1", preferences=preference)
    )

    profile = build_group_profiles(trip)[0]

    assert profile["preferred_pace"] == "Leisure"


def test_empty_or_missing_trip():
    assert build_group_profiles(None) == []
    assert build_group_profiles(make_trip()) == []
