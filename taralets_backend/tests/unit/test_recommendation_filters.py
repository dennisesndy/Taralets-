from app.services.itinerary.group_scoring import matched_activity_categories
from app.services.recommendation import filter_by_group_activities


def test_activity_preferences_do_not_fall_back_to_unrelated_places():
    places = [
        {"id": 1, "category": "Restaurant / Eatery"},
        {"id": 2, "category": "Cafes"},
    ]

    results = filter_by_group_activities(
        places,
        [{"activity_tags": ["Museums"]}],
    )

    assert results == []


def test_group_activity_filter_keeps_places_matching_any_member_activity():
    places = [
        {"id": 1, "category": "Restaurant / Eatery"},
        {"id": 2, "category": "Cafes"},
        {"id": 3, "category": "Desserts / Bakeries"},
    ]

    results = filter_by_group_activities(
        places,
        [
            {"activity_tags": ["Cafes"]},
            {"activity_tags": ["Desserts / Bakeries"]},
        ],
    )

    assert [place["id"] for place in results] == [2, 3]


def test_place_with_selected_subcategory_is_listed_under_that_preference():
    places = [
        {
            "id": 1,
            "category": "Desserts / Bakeries",
            "sub_category_1": "Cafes",
        },
        {
            "id": 2,
            "category": "Cafes",
            "sub_category_1": "Desserts / Bakeries",
        },
    ]

    results = filter_by_group_activities(
        places,
        [{"activity_tags": ["Cafes"]}],
    )

    assert [place["id"] for place in results] == [1, 2]
    assert matched_activity_categories(
        results[0], [{"activity_tags": ["Cafes"]}]
    ) == ["cafes"]
    assert matched_activity_categories(
        results[1], [{"activity_tags": ["Cafes"]}]
    ) == ["cafes"]


def test_no_activity_preferences_preserves_normal_candidate_list():
    places = [{"id": 1, "category": "Restaurant / Eatery"}]
    assert filter_by_group_activities(places, [{"activity_tags": []}]) == places
