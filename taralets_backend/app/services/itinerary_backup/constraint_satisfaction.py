
from collections import Counter
from typing import Any

from app.services.itinerary.preference_vector import (
    build_group_preference_vectors,
)


def solve_group_consensus(
    profiles: list[dict[str, Any]],
    member_weights: list[float] | None = None,
    budget_scale: float = 5000.0,
) -> dict[str, Any]:
    """
    Build a deterministic group consensus from member preferences.

    Budget is treated as a strict group ceiling: the smallest member
    budget is used. Categorical preferences are aggregated by support,
    and pace uses the weighted average of normalized member values.
    """
    if not profiles:
        raise ValueError("At least one member profile is required")

    vectors = build_group_preference_vectors(
        profiles,
        budget_scale=budget_scale,
    )

    if member_weights is None:
        weights = [1.0] * len(vectors)
    else:
        if len(member_weights) != len(vectors):
            raise ValueError(
                "member_weights must match the number of profiles"
            )

        weights = [float(weight) for weight in member_weights]

        if any(weight < 0 for weight in weights):
            raise ValueError("Member weights cannot be negative")

        if sum(weights) <= 0:
            raise ValueError("At least one member weight must be positive")

    total_weight = sum(weights)

    def weighted_tag_support(key: str) -> dict[str, float]:
        support: dict[str, float] = {}

        for vector, weight in zip(vectors, weights):
            for tag in set(vector[key]):
                support[tag] = support.get(tag, 0.0) + weight

        return {
            tag: round(value / total_weight, 4)
            for tag, value in sorted(support.items())
        }

    pace = sum(
        vector["pace_normalized"] * weight
        for vector, weight in zip(vectors, weights)
    ) / total_weight

    budget_ceiling = min(
        vector["max_budget"] for vector in vectors
    )

    return {
        "member_count": len(vectors),
        "consensus": {
            "budget_ceiling": budget_ceiling,
            "budget_normalized": min(
                budget_ceiling / budget_scale, 1.0
            ),
            "pace_normalized": round(pace, 4),
            "activity_support": weighted_tag_support("activities"),
            "dietary_support": weighted_tag_support("dietary"),
            "accessibility_support": weighted_tag_support(
                "accessibility"
            ),
        },
        "member_vectors": vectors,
        "method": "weighted_preference_aggregation",
    }


def calculate_constraint_penalty(
    place: dict[str, Any],
    consensus: dict[str, Any],
) -> dict[str, Any]:
    """
    Check a candidate POI against available group constraints.

    This checks only fields supplied by the caller. Missing POI data
    is not assumed to prove accessibility or dietary compatibility.
    """
    reasons: list[str] = []
    ceiling = float(consensus["budget_ceiling"])

    raw_fee = place.get("entrance_fee")
    if raw_fee is None:
        raw_fee = place.get("entrance_fee_php")

    if raw_fee is not None:
        try:
            fee = float(raw_fee)
        except (TypeError, ValueError):
            fee = None

        if fee is not None and fee > ceiling:
            reasons.append("entrance_fee_exceeds_group_budget")

    is_open = place.get("is_open")
    if is_open is False:
        reasons.append("place_is_closed")

    return {
        "feasible": not reasons,
        "penalty": float(len(reasons)),
        "reasons": reasons,
    }
