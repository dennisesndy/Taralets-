import math
from typing import List, Dict, Any, Optional

# Weights base sa Tsai & Wang (2025) framework
WEIGHT_POI = 0.45
WEIGHT_TIME = 0.35
WEIGHT_DIST = 0.20

TIME_SLOTS = {
    "morning": {"start": 8, "end": 12, "label": "Morning (8 AM - 12 PM)"},
    "afternoon": {"start": 13, "end": 17, "label": "Afternoon (1 PM - 5 PM)"},
    "evening": {"start": 18, "end": 22, "label": "Evening (6 PM - 10 PM)"}
}

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Kina-calculate ang distance sa kilometers sa pagitan ng dalawang lat/lng coordinates."""
    R = 6371.0  # Earth radius sa kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def calculate_poi_score(user_profile: Dict[str, Any], place: Dict[str, Any]) -> float:
    """Sinusukat ang match ng lugar sa user preferences (Activities, Budget, Accessibility)."""
    # 1. Hard Filter: Dietary Requirements
    required_dietary = [d.lower() for d in user_profile.get("dietary", []) if d != "None"]
    place_dietary = [d.lower() for d in place.get("dietary_options", [])]
    for req in required_dietary:
        if req not in place_dietary and place.get("category") in ["Food", "Café", "Restaurant"]:
            return 0.0

    # 2. Activity / Tag Match
    user_acts = [act.lower() for act in user_profile.get("activities", [])]
    place_tags = [t.lower() for t in place.get("tags", [])]
    
    if not user_acts:
        activity_score = 0.5
    else:
        matched = sum(1 for tag in place_tags if tag in user_acts)
        activity_score = min(1.0, matched / max(1, len(user_acts)))

    # 3. Budget Tier Score
    budget_score = 1.0 if place.get("budget_tier") == user_profile.get("budget", "₱₱") else 0.6

    # 4. Pace & Accessibility Score
    acc_score = 1.0 if place.get("wheelchair_accessible", True) == user_profile.get("walking_accessibility", True) else 0.7

    return (activity_score * 0.5) + (budget_score * 0.3) + (acc_score * 0.2)


def calculate_time_score(place: Dict[str, Any], slot_name: str) -> float:
    """Sinusuri kung bukas ang lugar sa partikular na time slot."""
    slot_info = TIME_SLOTS.get(slot_name)
    if not slot_info:
        return 0.0

    open_hour = place.get("open_hour", 8)
    close_hour = place.get("close_hour", 22)

    # Perfect match kung sakop ng operating hours ang buong slot
    if open_hour <= slot_info["start"] and close_hour >= slot_info["end"]:
        return 1.0
    # Partial match kung bukas sa kalagitnaan ng slot
    elif open_hour < slot_info["end"] and close_hour > slot_info["start"]:
        return 0.5
    
    return 0.0


def calculate_distance_score(dist_km: float, max_dist_km: float = 15.0) -> float:
    """Distance penalty decay score: mas malapit = mas mataas ang score."""
    if dist_km <= 0:
        return 1.0
    return max(0.0, 1.0 - (dist_km / max_dist_km))


def generate_sequential_itinerary(
    user_profile: Dict[str, Any],
    candidate_places: List[Dict[str, Any]],
    start_location: Optional[Dict[str, float]] = None
) -> Dict[str, Any]:
    """
    Tsai & Wang (2025) Sequential Itinerary Recommendation Pipeline:
    Sequential matching para sa Morning -> Afternoon -> Evening blocks.
    """
    selected_ids = set()
    itinerary_blocks = []
    
    # Starting coordinates (default sa Manila center kung walang ibinigay)
    current_lat = start_location.get("lat", 14.5995) if start_location else 14.5995
    current_lng = start_location.get("lng", 120.9842) if start_location else 120.9842

    for slot_name, slot_details in TIME_SLOTS.items():
        best_place = None
        best_combined_score = -1.0
        best_metrics = {}

        for place in candidate_places:
            if place["id"] in selected_ids:
                continue

            # 1. POI Match Score
            s_poi = calculate_poi_score(user_profile, place)
            if s_poi <= 0:  # Skip disqualified places
                continue

            # 2. Time Slot Match Score
            s_time = calculate_time_score(place, slot_name)
            if s_time == 0:  # Skip if place is closed during this time
                continue

            # 3. Distance Score
            dist_km = haversine_distance(current_lat, current_lng, place["lat"], place["lng"])
            s_dist = calculate_distance_score(dist_km)

            # Total Weighted Score
            total_score = (s_poi * WEIGHT_POI) + (s_time * WEIGHT_TIME) + (s_dist * WEIGHT_DIST)

            if total_score > best_combined_score:
                best_combined_score = total_score
                best_place = place
                best_metrics = {
                    "score_poi": round(s_poi * 100, 1),
                    "score_time": round(s_time * 100, 1),
                    "score_dist": round(s_dist * 100, 1),
                    "distance_km": round(dist_km, 2),
                    "final_score": round(total_score * 100, 1)
                }

        if best_place:
            selected_ids.add(best_place["id"])
            current_lat = best_place["lat"]
            current_lng = best_place["lng"]

            itinerary_blocks.append({
                "slot": slot_name,
                "time_label": slot_details["label"],
                "place": best_place,
                "metrics": best_metrics
            })

    return {
        "user_id": user_profile.get("id"),
        "total_stops": len(itinerary_blocks),
        "itinerary": itinerary_blocks
    }