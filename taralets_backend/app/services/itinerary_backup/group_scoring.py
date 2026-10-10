from typing import List, Dict, Any

from app.services.itinerary.constraint_satisfaction import (
    solve_group_consensus,
    calculate_constraint_penalty,
)


def _normalize_tags(tags: Any) -> set[str]:
    """Normalize tags for consistent matching."""
    if not isinstance(tags, (list, tuple, set)):
        return set()

    return {
        tag.strip().casefold()
        for tag in tags
        if isinstance(tag, str)
        and tag.strip()
        and tag.strip().casefold() not in {"none", "not applicable"}
    }


def calculate_cbf_score(
    user_tags: List[str],
    place_tags: List[str],
) -> float:
    """Calculate Jaccard similarity between preferences and POI tags."""
    user_set = _normalize_tags(user_tags)
    place_set = _normalize_tags(place_tags)

    if not user_set or not place_set:
        return 0.0

    intersection = user_set.intersection(place_set)
    union = user_set.union(place_set)

    return len(intersection) / len(union) if union else 0.0


def _get_member_activities(member: Dict[str, Any]) -> List[str]:
    """Support both the existing API format and preference model format."""
    activities = member.get(
        "activities",
        member.get("activity_tags", []),
    )

    return activities if isinstance(activities, list) else []


def _get_place_tags(place: Dict[str, Any]) -> List[str]:
    """Support list-based tags and the current database string format."""
    tags = place.get("tags", [])

    if isinstance(tags, list):
        return tags

    if isinstance(tags, str):
        return [
            tag.strip()
            for tag in tags.split(",")
            if tag.strip()
        ]

    return []


def aggregate_group_scores(
    group_profiles: List[Dict[str, Any]],
    candidate_places: List[Dict[str, Any]],
    alpha: float = 0.7,
) -> List[Dict[str, Any]]:
    """
    Rank POIs using Average Satisfaction, Least Misery,
    group preference support, and available hard constraints.

    Existing API fields are preserved.
    """
    if not group_profiles:
        return []

    if not 0.0 <= alpha <= 1.0:
        raise ValueError("alpha must be between 0 and 1")

    # Build ACS consensus only when profiles contain preference data.
    has_full_preferences = any(
        any(
            key in member
            for key in (
                "activity_tags",
                "dietary_preferences",
                "max_budget",
                "preferred_pace",
                "accessibility_preferences",
            )
        )
        for member in group_profiles
    )

    consensus_result = None

    if has_full_preferences:
        consensus_result = solve_group_consensus(group_profiles)

    scored_places = []

    for place in candidate_places:
        place_tags = _get_place_tags(place)

        member_scores = [
            calculate_cbf_score(
                _get_member_activities(member),
                place_tags,
            )
            for member in group_profiles
        ]

        avg_score = sum(member_scores) / len(member_scores)
        min_score = min(member_scores)

        # Existing Average Satisfaction + Least Misery formula.
        base_group_score = (
            alpha * avg_score
            + (1 - alpha) * min_score
        )

        group_support = sum(
            score > 0 for score in member_scores
        ) / len(member_scores)

        constraint_result = {
            "feasible": True,
            "penalty": 0.0,
            "reasons": [],
        }

        if consensus_result is not None:
            constraint_result = calculate_constraint_penalty(
                place,
                consensus_result["consensus"],
            )

        # Do not recommend a POI that violates a known hard constraint.
        if not constraint_result["feasible"]:
            continue

        # Give additional credit to places relevant to more members.
        final_group_score = (
            0.8 * base_group_score
            + 0.2 * group_support
        )

        scored_places.append({
            **place,
            "group_score": round(final_group_score, 4),
            "average_satisfaction": round(avg_score, 4),
            "least_misery_score": round(min_score, 4),
            "group_support": round(group_support, 4),
            "member_scores": [
                round(score, 4)
                for score in member_scores
            ],
            "constraint_check": constraint_result,
        })

    return sorted(
        scored_places,
        key=lambda item: item["group_score"],
        reverse=True,
    )