
from typing import Any


PACE_VALUES = {
    "leisure": 0.0,
    "moderate": 0.5,
    "fast": 1.0,
}


def _normalize_tags(values: Any) -> list[str]:
    """Normalize tags and remove duplicates while preserving order."""
    if not isinstance(values, (list, tuple, set)):
        return []

    result = []
    seen = set()

    for value in values:
        if not isinstance(value, str):
            continue

        tag = value.strip().casefold()

        if not tag or tag in {"none", "not applicable"}:
            continue

        if tag not in seen:
            seen.add(tag)
            result.append(tag)

    return result


def build_preference_vector(
    profile: dict[str, Any],
    budget_scale: float = 5000.0,
) -> dict[str, Any]:
    """
    Convert one member's preferences into a normalized vector.

    Budget is normalized to [0, 1] using budget_scale.
    Categorical preferences are represented as normalized tag lists.
    """
    if budget_scale <= 0:
        raise ValueError("budget_scale must be greater than zero")

    raw_budget = profile.get("max_budget", 2500.0)

    try:
        budget = float(raw_budget)
    except (TypeError, ValueError):
        budget = 2500.0

    if budget < 0:
        raise ValueError("max_budget cannot be negative")

    raw_pace = str(
        profile.get("preferred_pace", "Moderate")
    ).strip().casefold()

    pace = PACE_VALUES.get(raw_pace, PACE_VALUES["moderate"])

    return {
        "activities": _normalize_tags(
            profile.get("activity_tags", profile.get("activities", []))
        ),
        "dietary": _normalize_tags(
            profile.get("dietary_preferences", profile.get("dietary", []))
        ),
        "accessibility": _normalize_tags(
            profile.get("accessibility_preferences", [])
        ),
        "max_budget": budget,
        "budget_normalized": min(budget / budget_scale, 1.0),
        "pace_normalized": pace,
    }


def build_group_preference_vectors(
    profiles: list[dict[str, Any]],
    budget_scale: float = 5000.0,
) -> list[dict[str, Any]]:
    """Normalize the preferences of all group members."""
    return [
        build_preference_vector(profile, budget_scale)
        for profile in profiles
    ]
