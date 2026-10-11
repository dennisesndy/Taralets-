from typing import Any


def safe_cost(value, default=0.0):
    if value is None:
        return default

    text = str(value).strip()
    if not text or text.lower() in {"free", "none", "n/a", "na", "-"}:
        return 0.0

    text = (
        text.replace("₱", "")
        .replace(",", "")
        .replace("PHP", "")
        .replace("php", "")
        .strip()
    )

    try:
        return float(text)
    except (TypeError, ValueError):
        return default

def _normalize(values: Any) -> set[str]:
    if values is None:
        return set()

    if isinstance(values, str):
        values = values.split(",")

    if not isinstance(values, (list, tuple, set)):
        return set()

    return {
        str(value).strip().casefold()
        for value in values
        if str(value).strip()
        and str(value).strip().casefold()
        not in {"none", "n/a", "not applicable"}
    }



def _place_features(place) -> set[str]:
    features = set()

    for field in (
        "category",
        "sub_category_1",
        "sub_category_2",
        "sub_category_3",
    ):
        value = (
            place.get(field)
            if isinstance(place, dict)
            else getattr(place, field, None)
        )

        if value:
            features.update(_normalize(value))

    activity_tags = (
        place.get("activity_tags")
        if isinstance(place, dict)
        else getattr(place, "activity_tags", None)
    )

    features.update(_normalize(activity_tags))

    return features



def calculate_member_score(
    member_tags: list[str],
    place,
) -> float:
    """
    Content-based score for one member.

    Uses both the establishment category and all activity tags.
    Multiple matching tags contribute to the score.
    """

    member_features = _normalize(member_tags)
    place_features = _place_features(place)

    if not member_features:
        return 0.50

    if not place_features:
        return 0.0

    intersection = member_features.intersection(place_features)

    # Instead of pure Jaccard, use recall-style matching so that
    # a place with several tags is not unfairly penalized.
    tag_match = len(intersection) / len(member_features)

    # Small bonus when several preferences are matched.
    multi_match_bonus = min(len(intersection) * 0.05, 0.15)

    return min(tag_match + multi_match_bonus, 1.0)


def calculate_dietary_score(
    member_preferences: list[str],
    place,
) -> float:
    required = _normalize(member_preferences)

    if not required:
        return 1.0

    available = _normalize(
        getattr(place, "dietary_options", None)
    )

    if not available:
        return 0.0

    matches = required.intersection(available)

    return len(matches) / len(required)


def calculate_accessibility_score(
    member_preferences: list[str],
    place,
) -> float:
    required = _normalize(member_preferences)

    if not required:
        return 1.0

    available = _normalize(
        getattr(place, "accessibility_pets", None)
    )

    if not available:
        return 0.0

    matches = required.intersection(available)

    return len(matches) / len(required)



def calculate_budget_score(
    max_budget: float | None,
    place,
) -> float:
    if max_budget is None:
        return 1.0

    try:
        budget = float(max_budget)
    except (TypeError, ValueError):
        return 1.0

    min_cost = safe_cost(getattr(place, "min_cost", 0))
    max_cost = safe_cost(getattr(place, "max_cost", 0))
    entrance_fee = safe_cost(getattr(place, "entrance_fee", 0))

    estimated_cost = max(min_cost, max_cost)
    required_cost = max(estimated_cost, entrance_fee)

    if required_cost <= budget:
        if budget <= 0:
            return 1.0

        return max(
            0.70,
            1.0 - (required_cost / budget) * 0.30,
        )

    overflow = required_cost - budget

    if budget <= 0:
        return 0.0

    return max(
        0.0,
        1.0 - (overflow / budget),
    )






def filter_by_hard_constraints(places, group_prefs: dict):
    """
    Excludes places exceeding the specified group budget.
    Supports dictionaries and objects.
    """
    budget_max = group_prefs.get("budget_max")

    if budget_max is None:
        return list(places)

    try:
        budget = float(budget_max)
    except (TypeError, ValueError):
        return list(places)

    if budget < 0:
        return []

    valid_places = []

    for place in places:
        def get_value(field):
            if isinstance(place, dict):
                return place.get(field)
            return getattr(place, field, None)

        min_cost = get_value("min_cost")
        max_cost = get_value("max_cost")
        entrance_fee = get_value("entrance_fee")

        if min_cost is None and max_cost is None:
            continue

        estimated_min = (
            safe_cost(min_cost)
            if min_cost is not None
            else 0.0
        )
        estimated_max = (
            safe_cost(max_cost)
            if max_cost is not None
            else estimated_min
        )
        fee = safe_cost(entrance_fee)

        if min(estimated_min, estimated_max, fee) < 0:
            continue

        required_cost = max(estimated_max, fee)

        if required_cost <= budget:
            valid_places.append(place)

    return valid_places

