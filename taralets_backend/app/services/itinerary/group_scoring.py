from math import radians, sin, cos, sqrt, atan2
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


def _distance_km(
    lat1: float | None,
    lon1: float | None,
    lat2: float | None,
    lon2: float | None,
) -> float | None:

    if None in (lat1, lon1, lat2, lon2):
        return None

    try:
        lat1 = float(lat1)
        lon1 = float(lon1)
        lat2 = float(lat2)
        lon2 = float(lon2)
    except (TypeError, ValueError):
        return None

    earth_radius = 6371.0

    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)

    a = (
        sin(d_lat / 2) ** 2
        + cos(radians(lat1))
        * cos(radians(lat2))
        * sin(d_lon / 2) ** 2
    )

    return earth_radius * 2 * atan2(
        sqrt(a),
        sqrt(max(0.0, 1 - a)),
    )



ACTIVITY_ALIASES = {
    "restaurant / eatery": {
        "restaurant / eatery", "restaurant", "restaurants",
        "eatery", "eateries", "carinderia", "carinderias",
        "fast food", "fast foods", "pizza restaurant",
        "pizza restaurants", "burger restaurant",
        "burger restaurants", "food stall", "food stalls",
        "filipino restaurant", "chinese restaurant",
        "seafood restaurant", "rice meals",
    },
    "cafe": {
        "cafe", "cafes", "coffee shop", "coffee shops",
        "tea house", "tea houses", "coffee bar",
    },
    "park / plaza": {
        "park / plaza", "park", "parks", "plaza", "plazas",
        "garden", "gardens",
    },
    "museum": {
        "museum", "museums", "art gallery", "art galleries",
        "art museum", "cultural center", "cultural centers",
    },
    "church / religious site": {
        "church / religious site", "church", "churches",
        "temple", "temples", "shrine", "shrines",
        "religious site", "religious sites", "place of worship",
        "mosque", "mosques", "buddhist temple",
    },
    "historical / tourist site": {
        "historical / tourist site", "historical",
        "historical place", "historical landmark",
        "historical landmarks", "heritage site", "heritage sites",
        "monument", "monuments", "tourist attraction",
        "tourist attractions", "tourist spot", "tourist spots",
    },
    "shop / retail": {
        "shop / retail", "shop", "shops", "retail",
        "shopping center", "shopping centers",
        "shopping mall", "shopping malls", "mall", "malls",
        "souvenir shop", "souvenir shops", "department store",
        "department stores", "market", "markets",
    },
    "accommodation": {
        "accommodation", "hotel", "hotels", "inn", "inns",
        "lodging", "guest house", "guest houses",
    },
}

GENERIC_ACTIVITY_TAGS = {
    "establishment",
    "point of interest",
    "premise",
    "store",
    "food",
    "food store",
    "service",
    "association or organization",
}


def _clean_activity(value) -> str:
    return " ".join(
        str(value)
        .strip()
        .casefold()
        .replace("_", " ")
        .split()
    )


def _canonical_activity(value) -> str | None:
    token = _clean_activity(value)

    if not token or token in GENERIC_ACTIVITY_TAGS:
        return None

    for canonical, aliases in ACTIVITY_ALIASES.items():
        normalized_aliases = {
            _clean_activity(alias)
            for alias in aliases
        }

        if token == _clean_activity(canonical):
            return canonical

        if token in normalized_aliases:
            return canonical

    return None


def _activity_values(values) -> set[str]:
    if values is None:
        return set()

    if isinstance(values, str):
        values = [values]

    if not isinstance(values, (list, tuple, set)):
        return set()

    result = set()

    for value in values:
        if not value:
            continue

        for part in str(value).split(","):
            token = _clean_activity(part)

            if token and token not in GENERIC_ACTIVITY_TAGS:
                result.add(token)

    return result


def _expand_activity_preferences(member_tags) -> set[str]:
    selected = set()

    for value in _activity_values(member_tags):
        canonical = _canonical_activity(value)

        if canonical:
            selected.add(canonical)

    return selected


def _place_activity_values(place) -> set[str]:
    # Category is the primary classification.
    category_values = _activity_values(
        getattr(place, "category", None)
    )

    category_activities = {
        canonical
        for value in category_values
        if (canonical := _canonical_activity(value))
    }

    # If the category already identifies the place, do not let
    # conflicting tags such as "restaurant" reclassify a Cafe.
    if category_activities:
        return category_activities

    # Use meaningful activity tags only if the category is
    # missing or does not identify a supported activity.
    tag_values = _activity_values(
        getattr(place, "activity_tags", None)
    )

    return {
        canonical
        for value in tag_values
        if (canonical := _canonical_activity(value))
    }


def place_matches_activity_preferences(place, member_tags) -> bool:
    selected = _expand_activity_preferences(member_tags)

    # No activity preference means no activity-based restriction.
    if not selected:
        return True

    place_activities = _place_activity_values(place)

    return bool(selected.intersection(place_activities))


def calculate_activity_score(
    member_tags: list[str],
    place,
) -> float:
    selected = _expand_activity_preferences(member_tags)

    if not selected:
        return 0.50

    place_activities = _place_activity_values(place)
    matched = selected.intersection(place_activities)

    if not matched:
        return 0.0

    return min(
        1.0,
        len(matched) / len(selected)
        + min(len(matched) * 0.05, 0.15),
    )



def calculate_member_score(
    member: dict,
    place,
) -> float:

    activity_score = calculate_activity_score(
        member.get("activity_tags", []),
        place,
    )

    dietary_required = _normalize(
        member.get("dietary_preferences", [])
    )

    dietary_available = _normalize(
        getattr(place, "dietary_options", None)
    )

    if not dietary_required:
        dietary_score = 1.0
    elif dietary_available:
        dietary_score = (
            len(dietary_required.intersection(dietary_available))
            / len(dietary_required)
        )
    else:
        dietary_score = 0.0

    accessibility_required = _normalize(
        member.get("accessibility_preferences", [])
    )

    accessibility_available = _normalize(
        getattr(place, "accessibility_pets", None)
    )

    if not accessibility_required:
        accessibility_score = 1.0
    elif accessibility_available:
        accessibility_score = (
            len(
                accessibility_required.intersection(
                    accessibility_available
                )
            )
            / len(accessibility_required)
        )
    else:
        accessibility_score = 0.0

    max_budget = member.get("max_budget")

    try:
        max_budget = float(max_budget)
    except (TypeError, ValueError):
        max_budget = None

    min_cost = float(
        getattr(place, "min_cost", 0) or 0
    )

    entrance_fee = float(
        getattr(place, "entrance_fee", 0) or 0
    )

    estimated_cost = max(min_cost, entrance_fee)

    if max_budget is None or max_budget <= 0:
        budget_score = 1.0
    elif estimated_cost <= max_budget:
        budget_score = 1.0
    else:
        budget_score = max(
            0.0,
            1.0 - (
                (estimated_cost - max_budget)
                / max_budget
            ),
        )

    # Activity is the main preference signal.
    # Dietary/accessibility/budget support the match.
    return (
        0.55 * activity_score
        + 0.20 * dietary_score
        + 0.15 * accessibility_score
        + 0.10 * budget_score
    )


def calculate_group_score(
    member_scores: list[float],
) -> dict[str, float]:

    if not member_scores:
        return {
            "average": 0.0,
            "least_misery": 0.0,
            "support": 0.0,
            "consensus": 0.0,
        }

    average = sum(member_scores) / len(member_scores)

    least_misery = min(member_scores)

    support = sum(
        score >= 0.50
        for score in member_scores
    ) / len(member_scores)

    # Average satisfaction + protection for the least satisfied member.
    consensus = (
        0.50 * average
        + 0.30 * least_misery
        + 0.20 * support
    )

    return {
        "average": average,
        "least_misery": least_misery,
        "support": support,
        "consensus": consensus,
    }


def calculate_rating_score(place) -> float:
    """
    Rating is secondary evidence only.

    New/no-review places are not penalized to zero.
    """

    rating = getattr(place, "rating", 0) or 0
    reviews = getattr(place, "reviews", 0) or 0

    try:
        rating = float(rating)
        reviews = int(reviews)
    except (TypeError, ValueError):
        return 0.50

    if rating <= 0 or reviews <= 0:
        return 0.50

    normalized = max(
        0.0,
        min(1.0, rating / 5.0),
    )

    # Reliability increases with review count.
    reliability = min(
        1.0,
        reviews / 100.0,
    )

    return (
        normalized * reliability
        + 0.50 * (1.0 - reliability)
    )


def calculate_spatial_score(
    place,
    origin_lat: float | None,
    origin_lon: float | None,
) -> float:

    distance = _distance_km(
        origin_lat,
        origin_lon,
        getattr(place, "latitude", None),
        getattr(place, "longitude", None),
    )

    if distance is None:
        return 0.50

    # Smooth decay rather than a hard cutoff.
    return max(
        0.0,
        min(
            1.0,
            1.0 / (1.0 + distance / 5.0),
        ),
    )


def aggregate_group_scores(
    group_profiles: list[dict[str, Any]],
    candidate_places: list[Any],
    origin_lat: float | None = None,
    origin_lon: float | None = None,
) -> list[dict[str, Any]]:

    if not group_profiles:
        return []

    scored = []

    for place in candidate_places:

        member_scores = [
            calculate_member_score(
                member,
                place,
            )
            for member in group_profiles
        ]

        group = calculate_group_score(
            member_scores
        )

        rating_score = calculate_rating_score(
            place
        )

        spatial_score = calculate_spatial_score(
            place,
            origin_lat,
            origin_lon,
        )

        # Content/group consensus is dominant.
        final_score = (
            0.65 * group["consensus"]
            + 0.15 * rating_score
            + 0.20 * spatial_score
        )

        scored.append({
            "id": place.id,
            "master_id": place.master_id,
            "name": place.name,
            "district": place.district,
            "category": place.category,
            "description": place.description,
            "image_url": place.image_url,
            "address": place.address,
            "latitude": place.latitude,
            "longitude": place.longitude,
            "activity_tags": place.activity_tags or [],
            "dietary_options": place.dietary_options or [],
            "entrance_fee": place.entrance_fee,
            "min_cost": place.min_cost,
            "max_cost": place.max_cost,
            "accessibility_pets": (
                place.accessibility_pets or []
            ),
            "days_open": place.days_open,
            "open_time": (
                place.open_time.isoformat()
                if place.open_time
                else None
            ),
            "close_time": (
                place.close_time.isoformat()
                if place.close_time
                else None
            ),
            "rating": place.rating or 0,
            "reviews": place.reviews or 0,

            "match_score": round(
                final_score,
                4,
            ),

            "group_score": round(
                group["consensus"],
                4,
            ),

            "average_satisfaction": round(
                group["average"],
                4,
            ),

            "least_misery_score": round(
                group["least_misery"],
                4,
            ),

            "group_support": round(
                group["support"],
                4,
            ),

            "rating_score": round(
                rating_score,
                4,
            ),

            "spatial_score": round(
                spatial_score,
                4,
            ),

            "member_scores": [
                round(score, 4)
                for score in member_scores
            ],

            "is_new": (
                (place.reviews or 0) == 0
            ),
        })

    scored.sort(
        key=lambda item: item["match_score"],
        reverse=True,
    )

    return scored