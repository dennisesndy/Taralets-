from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.poi import Place

from app.services.itinerary.cbf_scoring import (
    filter_by_hard_constraints,
)

from app.services.itinerary.group_scoring import (
    aggregate_group_scores,
    place_matches_activity_preferences,
)


async def get_group_recommendations(
    db: AsyncSession,
    group_profiles: list[dict],
    origin_lat: float | None = None,
    origin_lon: float | None = None,
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

    # IMPORTANT:
    # If strict filtering removes everything, don't show
    # "No places found". Let the scoring system rank them
    # instead.
    if not candidates:
        return []

    
    # ---------------------------------------------------------
    # 4. Filter by selected group activities
    # ---------------------------------------------------------

    selected_activities = [
        tag
        for member in group_profiles
        for tag in (member.get("activity_tags") or [])
    ]

    if selected_activities:
        candidates = [
            place
            for place in candidates
            if place_matches_activity_preferences(
                place,
                selected_activities,
            )
        ]

    if not candidates:
        return []

    # ---------------------------------------------------------
    # 5. Group consensus scoring
    # ---------------------------------------------------------

    recommendations = aggregate_group_scores(
        group_profiles=group_profiles,
        candidate_places=candidates,
        origin_lat=origin_lat,
        origin_lon=origin_lon,
    )

    return recommendations[:30]
