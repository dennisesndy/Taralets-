from typing import Any


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

    # Category is one feature.
    category = getattr(place, "category", None)
    if category:
        features.add(str(category).strip().casefold())

    # Activity tags are multi-label features.
    features.update(
        _normalize(getattr(place, "activity_tags", None))
    )

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

    min_cost = getattr(place, "min_cost", 0) or 0
    entrance_fee = getattr(place, "entrance_fee", 0) or 0

    try:
        min_cost = float(min_cost)
        entrance_fee = float(entrance_fee)
    except (TypeError, ValueError):
        return 1.0

    required_cost = max(min_cost, entrance_fee)

    if required_cost <= budget:
        if budget <= 0:
            return 1.0

        # Better score for cheaper places.
        return max(
            0.70,
            1.0 - (required_cost / budget) * 0.30,
        )

    # Do not immediately discard the place here.
    # Hard constraints are handled separately.
    overflow = required_cost - budget

    if budget <= 0:
        return 0.0

    return max(
        0.0,
        1.0 - (overflow / budget),
    )


def filter_by_hard_constraints(
    places,
    group_prefs: dict,
):
    """
    Filter places using the group's maximum budget.
    Uses min_cost as the minimum estimated cost needed
    to visit a place.
    """

    budget_max = group_prefs.get("budget_max")
    valid_places = []

    for place in places:
        min_cost = getattr(place, "min_cost", 0) or 0

        try:
            min_cost = float(min_cost)
        except (TypeError, ValueError):
            min_cost = 0.0

        if budget_max is not None:
            try:
                if min_cost > float(budget_max):
                    continue
            except (TypeError, ValueError):
                pass

        valid_places.append(place)

    return valid_places