from app.services.itinerary.group_scoring import aggregate_group_scores


def test_aggregate_group_scores_accepts_minimal_dict():
    """A sparse dict payload must not crash the serializer."""
    profiles = [{"activity_tags": ["Museums"]}]
    places = [{"id": 1, "name": "Test Museum", "category": "Museums"}]

    results = aggregate_group_scores(profiles, places)

    assert len(results) == 1
    place = results[0]

    assert place["id"] == 1
    assert place["place_id"] == 1
    assert place["master_id"] is None
    assert place["activity_tags"] == []
    assert place["dietary_options"] == []
    assert place["accessibility_pets"] == []
    assert place["open_time"] is None
    assert place["close_time"] is None
    assert place["is_new"] is True


def test_matching_activity_scores_higher():
    profiles = [{"activity_tags": ["Museums"]}]
    places = [
        {"id": 1, "name": "Museum", "category": "Museums"},
        {"id": 2, "name": "Cafe", "category": "Cafes"},
    ]

    results = aggregate_group_scores(profiles, places)

    assert results[0]["id"] == 1
    assert results[0]["match_score"] > results[1]["match_score"]


def test_accessibility_flags_are_derived_from_booleans():
    profiles = [
        {
            "activity_tags": [],
            "accessibility_preferences": ["Wheelchair accessible"],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Accessible Museum",
            "category": "Museums",
            "wheelchair_accessible": True,
        },
        {
            "id": 2,
            "name": "Inaccessible Museum",
            "category": "Museums",
            "wheelchair_accessible": False,
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert by_id[1]["accessibility_pets"] == ["Wheelchair Accessible"]
    assert by_id[2]["accessibility_pets"] == []
    assert by_id[1]["match_score"] > by_id[2]["match_score"]


def test_dietary_preferences_affect_score():
    profiles = [
        {
            "activity_tags": [],
            "dietary_preferences": ["Halal"],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Halal Restaurant",
            "category": "Restaurant / Eatery",
            "dietary_options": ["Halal"],
        },
        {
            "id": 2,
            "name": "Regular Restaurant",
            "category": "Restaurant / Eatery",
            "dietary_options": [],
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert by_id[1]["match_score"] > by_id[2]["match_score"]


def test_time_values_are_serialized_for_objects_and_strings():
    class PlaceStub:
        id = 1
        name = "Stub Museum"
        category = "Museums"
        master_id = "MNL-TEST"
        district = None
        description = None
        image_url = None
        address = None
        latitude = 14.59
        longitude = 120.98
        activity_tags = []
        dietary_options = []
        entrance_fee = None
        min_cost = 0
        max_cost = 0
        sub_category_1 = None
        sub_category_2 = None
        sub_category_3 = None
        pet_friendly = None
        wheelchair_accessible = None
        good_for_children = None
        days_open = []
        open_time = "09:00:00"
        close_time = "18:00:00"
        rating = 0
        reviews = 0

        @property
        def accessibility_pets(self):
            return []

    results = aggregate_group_scores(
        [{"activity_tags": []}],
        [PlaceStub()],
    )

    assert results[0]["open_time"] == "09:00:00"
    assert results[0]["close_time"] == "18:00:00"


def test_malformed_activity_tags_are_normalized():
    profiles = [{"activity_tags": ["Cafes"]}]
    places = [
        {
            "id": 1,
            "name": "Coffee Place",
            "activity_tags": [
                '{"Coffee Shop"',
                "Cafe}",
                "Establishment}",
            ],
        }
    ]

    results = aggregate_group_scores(profiles, places)

    assert results[0]["match_score"] > 0


def test_malformed_halal_option_matches_halal_preference():
    profiles = [
        {
            "activity_tags": [],
            "dietary_preferences": ["Halal"],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Halal Place",
            "dietary_options": ['{"Halal Options"}'],
        },
        {
            "id": 2,
            "name": "Regular Place",
            "dietary_options": ['{"Standard Food"}'],
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert by_id[1]["match_score"] > by_id[2]["match_score"]


def test_vegetarian_option_does_not_satisfy_vegan_preference():
    profiles = [
        {
            "activity_tags": [],
            "dietary_preferences": ["Vegan"],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Vegetarian Place",
            "dietary_options": ['{"Vegetarian Options"}'],
        },
        {
            "id": 2,
            "name": "Vegan Place",
            "dietary_options": ['{"Vegan Options"}'],
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert (
        by_id[2]["member_scores"][0]
        > by_id[1]["member_scores"][0]
    )


def test_unknown_accessibility_is_neutral():
    profiles = [
        {
            "activity_tags": [],
            "accessibility_preferences": [
                "Wheelchair accessible",
            ],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Unknown Accessibility",
        },
        {
            "id": 2,
            "name": "Known Inaccessible",
            "wheelchair_accessible": False,
        },
        {
            "id": 3,
            "name": "Known Accessible",
            "wheelchair_accessible": True,
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert (
        by_id[3]["member_scores"][0]
        > by_id[1]["member_scores"][0]
    )
    assert (
        by_id[1]["member_scores"][0]
        > by_id[2]["member_scores"][0]
    )


def test_accessibility_is_scored_per_requirement():
    profiles = [
        {
            "activity_tags": [],
            "accessibility_preferences": [
                "Wheelchair accessible",
                "Pet friendly",
            ],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "Pet Only",
            "pet_friendly": True,
        },
        {
            "id": 2,
            "name": "Both Unknown",
        },
        {
            "id": 3,
            "name": "Both Available",
            "pet_friendly": True,
            "wheelchair_accessible": True,
        },
    ]

    results = aggregate_group_scores(profiles, places)

    by_id = {place["id"]: place for place in results}

    assert (
        by_id[3]["member_scores"][0]
        > by_id[1]["member_scores"][0]
    )
    assert (
        by_id[1]["member_scores"][0]
        > by_id[2]["member_scores"][0]
    )


def test_string_accessibility_value_is_not_split_into_characters():
    profiles = [
        {
            "activity_tags": [],
            "accessibility_preferences": [
                "Wheelchair accessible",
            ],
        }
    ]
    places = [
        {
            "id": 1,
            "name": "String Accessibility",
            "accessibility_pets": "Wheelchair Accessible",
        }
    ]

    results = aggregate_group_scores(profiles, places)

    assert results[0]["accessibility_pets"] == [
        "Wheelchair Accessible",
    ]
    assert results[0]["member_scores"][0] > 0.7


def test_accessibility_status_separates_verified_unknown_and_negative():
    profiles = [{"activity_tags": ["Museums"], "accessibility_preferences": ["Wheelchair accessible"]}]
    places = [
        {"id": 1, "name": "Verified", "wheelchair_accessible": True},
        {"id": 2, "name": "Unknown", "wheelchair_accessible": None},
        {"id": 3, "name": "No", "wheelchair_accessible": False},
    ]
    results = aggregate_group_scores(profiles, places)
    by_name = {place["name"]: place["accessibility_match_status"] for place in results}
    assert by_name == {"Verified": "verified", "Unknown": "unknown", "No": "does_not_meet"}
    assert [place["name"] for place in results] == ["Verified", "Unknown", "No"]


def test_group_accessibility_requires_all_members_needs():
    profiles = [
        {"accessibility_preferences": ["Wheelchair accessible"]},
        {"accessibility_preferences": ["Pet friendly"]},
    ]
    result = aggregate_group_scores(profiles, [{
        "id": 1, "name": "Partial", "wheelchair_accessible": True,
        "pet_friendly": None,
    }])[0]
    assert result["accessibility_match_status"] == "unknown"
