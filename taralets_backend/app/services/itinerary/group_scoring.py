from math import radians, sin, cos, sqrt, atan2
from typing import Any
from types import SimpleNamespace
import math


def safe_cost(value, default=0.0):
    if value is None:
        return default

    text = str(value).strip()

    if not text or text.lower() in {
        "free", "none", "n/a", "na", "-"
    }:
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


def _get(place, key, default=None):
    if isinstance(place, dict):
        return place.get(key, default)
    return getattr(place, key, default)


def _as_iso_time(value):
    if value is None:
        return None

    isoformat = getattr(value, "isoformat", None)

    if callable(isoformat):
        return isoformat()

    return str(value)


def _accessibility_values(place) -> list[str]:
    """Return accessibility labels for ORM objects or plain dicts."""
    values = _get(place, "accessibility_pets", None)

    if isinstance(values, str):
        return [values]

    if values:
        return list(values)

    labels = []

    if _get(place, "wheelchair_accessible", False):
        labels.append("Wheelchair Accessible")

    if _get(place, "pet_friendly", False):
        labels.append("Pet Friendly")

    if _get(place, "good_for_children", False):
        labels.append("Good for Children")

    return labels


ACCESSIBILITY_FIELDS = {
    "wheelchair accessible": "wheelchair_accessible",
    "pet friendly": "pet_friendly",
    "good for children": "good_for_children",
}


def accessibility_match_status(place, group_profiles: list[dict]) -> str:
    required = set().union(*(
        _normalize(profile.get("accessibility_preferences", []))
        for profile in group_profiles
    )) if group_profiles else set()
    if not required:
        return "not_requested"

    states = []
    available = _normalize(_accessibility_values(place))
    for need in required:
        field = ACCESSIBILITY_FIELDS.get(need)
        value = _get(place, field, None) if field else None
        if value is False:
            states.append(False)
        elif need in available:
            states.append(True)
        elif field is None:
            states.append(None)
        else:
            states.append(value)
    if any(value is False for value in states):
        return "does_not_meet"
    if all(value is True for value in states):
        return "verified"
    return "unknown"


def _calculate_accessibility_score(
    place,
    required: set[str],
) -> float:
    if not required:
        return 1.0

    available = _normalize(_accessibility_values(place))
    scores = []

    for preference in required:
        if preference in available:
            scores.append(1.0)
            continue

        field = ACCESSIBILITY_FIELDS.get(preference)

        if field is None:
            scores.append(0.0)
            continue

        value = _get(place, field, None)

        if value is None:
            # Missing accessibility data is neutral, not a hard no.
            scores.append(0.5)
        else:
            scores.append(1.0 if value else 0.0)

    return sum(scores) / len(scores)


DIETARY_ALIASES = {
    "halal": {
        "halal",
        "halal options",
        "halal-friendly",
        "halal friendly",
    },
    "vegan": {
        "vegan",
        "vegan options",
        "vegan-friendly",
        "vegan friendly",
        "plant-based",
        "plant based",
    },
    "vegetarian": {
        "vegetarian",
        "vegetarian options",
        "vegetarian-friendly",
        "vegetarian friendly",
    },
    "budget-friendly": {
        "budget-friendly",
        "budget friendly",
        "budget",
    },
}


def _normalize_token(value: Any) -> str:
    """Clean a Postgres array token read from the legacy dataset."""
    return " ".join(
        str(value)
        .strip()
        .strip('{}[]"\'')
        .replace('"', "")
        .replace("'", "")
        .casefold()
        .split()
    )


def _normalize(values: Any) -> set[str]:
    if values is None:
        return set()

    if isinstance(values, str):
        values = [values]

    if not isinstance(values, (list, tuple, set)):
        return set()

    normalized = set()

    for value in values:
        parts = (
            str(value).split(",")
            if isinstance(value, str)
            else [value]
        )

        for part in parts:
            token = _normalize_token(part)

            if token and token not in {"none", "n/a", "not applicable"}:
                normalized.add(token)

    return normalized


def _canonical_dietary(token: str) -> str:
    for canonical, aliases in DIETARY_ALIASES.items():
        if token in aliases:
            return canonical

    return token


def _normalize_dietary(values: Any) -> set[str]:
    return {
        _canonical_dietary(token)
        for token in _normalize(values)
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
    # Canonical categories from the updated PostgreSQL dataset.
    "accommodations": {
        "accommodations", "accommodation", "hotel", "hotels", "inn", "inns",
        "lodging", "guest house", "guest houses", "guesthouse", "hostel",
        "hostels", "hotel/hostel", "budget hotels", "resort", "resorts",
    },
    "cafes": {
        "cafes", "cafe", "coffee shop", "coffee shops", "tea house",
        "tea houses", "coffee bar", "milk tea shop", "milk tea shops",
        "tea shop", "tea shops",
    },
    "desserts / bakeries": {
        "desserts / bakeries", "dessert", "desserts", "bakery", "bakeries",
        "dessert shop", "dessert shops", "cake shop", "cake shops",
        "pastry shop", "pastry shops", "confectionery", "confectioneries",
        "ice cream shop", "ice cream shops", "donut shop", "donut shops",
        "cookie shop", "cookie shops", "patisserie",
    },
    "restaurant / eatery": {
        "restaurant / eatery", "restaurant", "restaurants", "eatery",
        "eateries", "carinderia", "carinderias", "fast food",
        "fast food restaurant", "fast food restaurants", "pizza restaurant",
        "pizza restaurants", "burger restaurant", "burger restaurants",
        "food stall", "food stalls", "filipino restaurant",
        "filipino restaurants", "chinese restaurant", "chinese restaurants",
        "seafood restaurant", "seafood restaurants", "rice meals",
        "food court", "food courts", "food park", "food parks",
        "meal takeaway", "family restaurant", "american restaurant",
        "korean restaurant", "japanese restaurant", "chicken restaurant",
        "noodle restaurant", "noodle restaurants", "barbecue restaurant",
        "barbecue restaurants", "street food", "local food", "food",
        "food shops", "food shop", "food store",
    },
    "museums": {
        "museums", "museum", "art gallery", "art galleries", "art museum",
        "cultural museum", "interactive museum", "religious art museum",
        "cultural center", "cultural centers", "library", "libraries",
    },
    "church / religious site": {
        "church / religious site", "church", "churches", "place of worship",
        "places of worship", "temple", "temples", "shrine", "shrines",
        "religious site", "religious sites", "mosque", "mosques",
        "buddhist temple", "buddhist temples",
    },
    "parks / plazas": {
        "parks / plazas", "park / plaza", "park", "parks", "plaza", "plazas",
        "garden", "gardens", "public garden", "public gardens",
    },
    "historical / tourist site": {
        "historical / tourist site", "historical", "historical place",
        "historical places", "historical landmark", "historical landmarks",
        "heritage site", "heritage sites", "monument", "monuments",
        "tourist attraction", "tourist attractions", "tourist spot",
        "tourist spots", "tourist information center",
        "tourist information centers", "cultural attraction",
        "cultural attractions",
    },
    "shopping / retail": {
        "shopping / retail", "shop / retail", "shop", "shops", "retail",
        "shopping retail", "shopping center", "shopping centers",
        "shopping mall", "shopping malls", "mall", "malls",
        "souvenir shop", "souvenir shops", "department store",
        "department stores", "market", "markets", "public market",
        "public markets", "grocery store", "grocery stores", "supermarket",
        "supermarkets", "convenience store", "convenience stores",
        "general store", "general merchandise store", "clothing store",
        "book store", "gift shop", "home goods store", "electronics store",
    },
    "health / wellness": {
        "health / wellness", "health and wellness", "health & wellness",
        "health", "wellness", "beauty salon", "beauty salons", "salon",
        "salons", "hair salon", "hair salons", "hair care", "nail salon",
        "nail salons", "barber shop", "barber shops", "spa", "spas",
        "massage", "massage spa", "massage spas", "fitness center",
        "fitness centers", "gym", "gyms", "medical clinic",
        "medical clinics", "pharmacy", "pharmacies",
    },
    "entertainment / leisure": {
        "entertainment / leisure", "entertainment", "leisure", "recreation",
        "recreational", "art gallery", "art galleries", "cinema", "cinemas",
        "arcade", "arcades", "amusement center", "amusement centers",
        "amusement park", "amusement parks", "sports center",
        "sports centers", "sports complex", "bowling alley", "bowling alleys",
        "event venue", "event venues", "leisure center", "leisure centers",
        "community center", "community centers",
    },
    "nightlife / bars": {
        "nightlife / bars", "nightlife", "bar", "bars", "pub", "pubs",
        "nightclub", "nightclubs", "cocktail bar", "cocktail bars",
    },
    "government / services": {
        "government / services", "government", "services", "government office",
        "government offices", "local government office",
        "local government offices", "barangay hall", "barangay halls",
        "national government agency", "national government agencies",
        "transportation service", "transportation services",
        "tourist information center", "tourist information centers",
        "association or organization", "business center", "corporate office",
        "service", "services",
    },
    "others": {
        "others", "other",
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
    "establishment",
    "food",
    "food store",
    "manufacturer",
    "wholesaler",
    "supplier",
    "premise",
    "point of interest",
    "store",
}


def _clean_activity(value) -> str:
    return " ".join(
        str(value)
        .strip()
        .strip('{}[]"\'')
        .replace('"', "")
        .replace("'", "")
        .replace("_", " ")
        .casefold()
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
    def get_value(field):
        if isinstance(place, dict):
            return place.get(field)
        return getattr(place, field, None)

    # Category remains the primary classification.
    category_values = _activity_values(get_value("category"))

    category_activities = {
        canonical
        for value in category_values
        if (canonical := _canonical_activity(value))
    }

    # A selected activity may match a primary category or a dataset
    # subcategory. Keep both so a place tagged with a selected subcategory is
    # included and can be shown under that activity's recommendation tab.
    subcategory_activities = set()
    for field in ("sub_category_1", "sub_category_2", "sub_category_3"):
        subcategory_activities.update(
            canonical
            for value in _activity_values(get_value(field))
            if (canonical := _canonical_activity(value))
        )
    place_activities = category_activities | subcategory_activities
    if place_activities:
        return place_activities

    # Use activity tags only when category and subcategories
    # do not identify a supported activity.
    tag_values = _activity_values(get_value("activity_tags"))

    return {
        canonical
        for value in tag_values
        if (canonical := _canonical_activity(value))
    }


def matched_activity_categories(place, group_profiles: list[dict]) -> list[str]:
    """Return selected activity categories this place matches, in group order."""
    place_activities = _place_activity_values(place)
    matched = []
    seen = set()
    for profile in group_profiles:
        for value in profile.get("activity_tags") or []:
            canonical = _canonical_activity(value)
            if canonical and canonical in place_activities and canonical not in seen:
                seen.add(canonical)
                matched.append(canonical)
    return matched


def place_matches_activity_preferences(place, member_tags):
    if not member_tags:
        return True

    selected = _expand_activity_preferences(member_tags)
    place_activities = _place_activity_values(place)

    if not place_activities:
        return False

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

    dietary_required = _normalize_dietary(
        member.get("dietary_preferences", [])
    )

    dietary_available = _normalize_dietary(
        _get(place, "dietary_options", None)
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

    accessibility_score = _calculate_accessibility_score(
        place,
        accessibility_required,
    )

    max_budget = member.get("max_budget")

    try:
        max_budget = float(max_budget)
    except (TypeError, ValueError):
        max_budget = None

    min_cost = safe_cost(_get(place, "min_cost", 0))
    max_cost = safe_cost(_get(place, "max_cost", 0))
    entrance_fee = safe_cost(_get(place, "entrance_fee", 0))

    # Use the higher estimated cost and numeric entrance fee.
    estimated_cost = max(min_cost, max_cost, entrance_fee)

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
    max_radius: int = 3000,
) -> float:

    distance = _distance_km(
        origin_lat,
        origin_lon,
        getattr(place, "latitude", None),
        getattr(place, "longitude", None),
    )

    if distance is None:
        return 0.50

    distance_meters = distance * 1000

    # Dynamic limit base sa choice ng user o sa default (e.g. 3000)
    if distance_meters > max_radius:
        return -1.0

    # Pasok sa target na 500m = perfect spatial score (1.0)
    if distance_meters <= 500:
        return 1.0

    # Distance-Decay: Unti-unting bababa ang score mula 500m hanggang max_radius
    decay_rate = 1000
    return math.exp(-(distance_meters - 500) / decay_rate)


def aggregate_group_scores(
    group_profiles: list[dict[str, Any]],
    candidate_places: list[Any],
    origin_lat: float | None = None,
    origin_lon: float | None = None,
    max_radius: int = 3000,
) -> list[dict[str, Any]]:

    if not group_profiles:
        return []

    scored = []

    for place in candidate_places:
        if isinstance(place, dict):
            place = SimpleNamespace(**place)

        # 1. Ipasa ang dynamic radius
        spatial_score = calculate_spatial_score(
            place,
            origin_lat,
            origin_lon,
            max_radius,
        )

        # 2. Kung nag-return ng -1, wag nang i-compute ang iba at i-skip na
        if spatial_score < 0:
            continue

        # 3. Tuloy na ang dating computation para sa mga pumasa
        member_scores = [
            calculate_member_score(member, place)
            for member in group_profiles
        ]

        group = calculate_group_score(
            member_scores
        )
        
        rating_score = calculate_rating_score(
            place
        )

        # Content/group consensus is dominant.
        final_score = (
            0.65 * group["consensus"]
            + 0.15 * rating_score
            + 0.20 * spatial_score
        )

        try:
            reviews = int(_get(place, "reviews", 0) or 0)
        except (TypeError, ValueError):
            reviews = 0

        scored.append({
            "id": _get(place, "id"),
            "place_id": _get(place, "id"),
            "master_id": _get(place, "master_id"),
            "name": _get(place, "name", ""),
            "district": _get(place, "district"),
            "category": _get(place, "category"),
            "description": _get(place, "description"),
            "image_url": _get(place, "image_url"),
            "address": _get(place, "address"),
            "latitude": _get(place, "latitude"),
            "longitude": _get(place, "longitude"),
            "activity_tags": _get(place, "activity_tags", []) or [],
            "dietary_options": _get(place, "dietary_options", []) or [],
            "entrance_fee": _get(place, "entrance_fee"),
            "min_cost": _get(place, "min_cost", 0),
            "max_cost": _get(place, "max_cost", 0),
            "sub_category_1": _get(place, "sub_category_1"),
            "sub_category_2": _get(place, "sub_category_2"),
            "sub_category_3": _get(place, "sub_category_3"),
            "pet_friendly": _get(place, "pet_friendly"),
            "wheelchair_accessible": _get(place, "wheelchair_accessible"),
            "good_for_children": _get(place, "good_for_children"),
            "accessibility_pets": _accessibility_values(place),
            "accessibility_match_status": accessibility_match_status(
                place, group_profiles
            ),
            "activity_match": any(
                place_matches_activity_preferences(
                    place, profile.get("activity_tags", [])
                )
                for profile in group_profiles
                if profile.get("activity_tags")
            ),
            "matched_activity_categories": matched_activity_categories(
                place, group_profiles
            ),
            "days_open": _get(place, "days_open", []) or [],
            "open_time": _as_iso_time(_get(place, "open_time")),
            "close_time": _as_iso_time(_get(place, "close_time")),
            "rating": _get(place, "rating", 0) or 0,
            "reviews": reviews,

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

            "is_new": reviews == 0,
        })

    scored.sort(
        key=lambda item: (
            {"verified": 0, "unknown": 1, "does_not_meet": 2,
             "not_requested": 0}[item["accessibility_match_status"]],
            -item["match_score"],
        ),
    )

    return scored
