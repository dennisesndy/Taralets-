from math import atan2, cos, radians, sin, sqrt

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.poi import Place

from app.services.itinerary.cbf_scoring import (
    filter_by_hard_constraints,
)

from app.services.itinerary.group_scoring import (
    aggregate_group_scores,
    _canonical_activity,
    place_matches_activity_preferences,
)


def rank_group_activities(group_profiles: list[dict]) -> list[str]:
    """Rank group activities by number of members who selected each one."""
    support: dict[str, int] = {}
    first_seen: dict[str, int] = {}
    sequence = 0
    for member in group_profiles:
        member_tags = []
        seen = set()
        for tag in member.get("activity_tags") or []:
            activity = _canonical_activity(tag)
            if activity and activity not in seen:
                seen.add(activity)
                member_tags.append(activity)
        for activity in member_tags:
            first_seen.setdefault(activity, sequence)
            support[activity] = support.get(activity, 0) + 1
            sequence += 1
    return sorted(
        support,
        key=lambda activity: (-support[activity], first_seen[activity]),
    )


def _distance_km(a: dict, b: dict) -> float | None:
    try:
        lat1, lon1 = float(a["latitude"]), float(a["longitude"])
        lat2, lon2 = float(b["latitude"]), float(b["longitude"])
    except (KeyError, TypeError, ValueError):
        return None
    d_lat, d_lon = radians(lat2 - lat1), radians(lon2 - lon1)
    value = (
        sin(d_lat / 2) ** 2
        + cos(radians(lat1))
        * cos(radians(lat2))
        * sin(d_lon / 2) ** 2
    )
    return 6371 * 2 * atan2(sqrt(value), sqrt(max(0.0, 1 - value)))


def _order_nearby_recommendations(
    recommendations: list[dict],
    activity_order: list[str],
    origin_lat: float | None,
    origin_lon: float | None,
    places_per_day: int,
) -> list[dict]:
    """Start each day-sized nearby group with the group's top activity."""
    remaining = list(recommendations)
    ordered = []
    try:
        origin = {"latitude": float(origin_lat), "longitude": float(origin_lon)}
    except (TypeError, ValueError):
        origin = None
    top_activity = activity_order[0] if activity_order else None
    day_size = max(1, places_per_day)
    while remaining:
        current = origin
        day_places = []
        # Each group/day starts with the highest-ranked group activity when
        # a matching candidate is available.
        if top_activity:
            top_candidates = [
                place for place in remaining
                if top_activity in (place.get("matched_activity_categories") or [])
            ]
            if top_candidates:
                top = max(top_candidates, key=lambda place: place.get("match_score", 0))
                remaining.remove(top)
                day_places.append(top)
                current = top
        while remaining and len(day_places) < day_size:
            if current is None:
                next_place = remaining[0]
            else:
                def distance_key(place):
                    distance = _distance_km(current, place)
                    return distance if distance is not None else float("inf")

                next_place = min(
                    remaining,
                    key=distance_key,
                )
            remaining.remove(next_place)
            day_places.append(next_place)
            current = next_place
        ordered.extend(day_places)
    return ordered


def filter_by_group_activities(places, group_profiles):
    selected_activities = [
        tag
        for member in group_profiles
        for tag in (member.get("activity_tags") or [])
    ]
    if not selected_activities:
        return list(places)
    return [
        place for place in places
        if place_matches_activity_preferences(place, selected_activities)
    ]


async def get_group_recommendations(
    db: AsyncSession,
    group_profiles: list[dict],
    origin_lat: float | None = None,
    origin_lon: float | None = None,
    max_radius: int = 3000,
    limit: int = 30,
    offset: int = 0,
):
    """
    Generate group recommendations using all member preferences.

    Pipeline:
    1. Load places from the dataset
    2. Apply basic hard constraints
    3. Score each place for every member
    4. Aggregate member scores into group consensus
    5. Include spatial relevance
    6. Return ranked recommendations
    """

    if not group_profiles:
        return []

    # ---------------------------------------------------------
    # 1. Load all places
    # ---------------------------------------------------------

    result = await db.execute(
        select(Place)
    )

    all_places = result.scalars().all()

    if not all_places:
        return []

    # ---------------------------------------------------------
    # 2. Determine group budget
    # ---------------------------------------------------------

    budgets = []

    for member in group_profiles:
        budget = member.get("max_budget")

        if budget is not None:
            try:
                budgets.append(float(budget))
            except (TypeError, ValueError):
                pass

    # The lowest member budget is used as the conservative
    # group budget for hard candidate filtering.
    group_budget = (
        min(budgets)
        if budgets
        else None
    )

    # ---------------------------------------------------------
    # 3. Apply basic hard constraints
    # ---------------------------------------------------------

    candidates = filter_by_hard_constraints(
        all_places,
        {
            "budget_max": group_budget,
        },
    )

    if not candidates:
        candidates = list(all_places)

    # IMPORTANT:
    # If strict filtering removes everything, don't show
    # "No places found". Let the scoring system rank them
    # instead.
    if not candidates:
        return []

    
    # ---------------------------------------------------------
    # 4. Filter by selected group activities
    # ---------------------------------------------------------

    # Don't silently fall back to unrelated places when saved activity
    # preferences have no matching dataset rows.
    candidates = filter_by_group_activities(candidates, group_profiles)

    if not candidates:
        return []

    # A confirmed failure for any participating member's selected need is
    # never presented as a suitable recommendation. Unknown data stays eligible.
    from app.services.itinerary.group_scoring import accessibility_match_status
    with_accessibility_needs = any(
        member.get("accessibility_preferences")
        for member in group_profiles
    )
    if with_accessibility_needs:
        candidates = [
            place for place in candidates
            if accessibility_match_status(place, group_profiles) != "does_not_meet"
        ]
    # ---------------------------------------------------------
    # 5. Group consensus scoring
    # ---------------------------------------------------------

    recommendations = aggregate_group_scores(
        group_profiles=group_profiles,
        candidate_places=candidates,
        origin_lat=origin_lat,
        origin_lon=origin_lon,
        max_radius=max_radius,
    )

    activity_order = rank_group_activities(group_profiles)
    place_targets = [
        member.get("desired_places_per_day")
        for member in group_profiles
        if isinstance(member.get("desired_places_per_day"), (int, float))
        and member.get("desired_places_per_day") > 0
    ]
    average_places_per_day = (
        int(sum(place_targets) / len(place_targets) + 0.5)
        if place_targets else 3
    )
    # Nearby ordering uses a greedy nearest-place search. Limit that extra
    # pass to the top ten pages so large groups remain responsive while
    # pagination below keeps a stable, fully ranked tail.
    cluster_window = min(len(recommendations), 300)
    nearby_recommendations = _order_nearby_recommendations(
        recommendations[:cluster_window],
        activity_order,
        origin_lat,
        origin_lon,
        average_places_per_day,
    )
    recommendations = nearby_recommendations + recommendations[cluster_window:]

    # I-apply ang pagination
    return recommendations[offset : offset + limit]
