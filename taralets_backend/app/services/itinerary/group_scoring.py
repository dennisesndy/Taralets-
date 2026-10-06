from typing import List, Dict, Any

def calculate_cbf_score(user_tags: List[str], place_tags: List[str]) -> float:
    """Calculates Jaccard similarity between user preferences and place tags."""
    if not user_tags or not place_tags:
        return 0.0
    set_user = set(user_tags)
    set_place = set(place_tags)
    intersection = set_user.intersection(set_place)
    union = set_user.union(set_place)
    return len(intersection) / len(union) if union else 0.0


def aggregate_group_scores(
    group_profiles: List[Dict[str, Any]], 
    candidate_places: List[Dict[str, Any]], 
    alpha: float = 0.7
) -> List[Dict[str, Any]]:
    """
    Tsai & Wang Group Aggregation:
    Combines Average Satisfaction and Least Misery Strategy (LMS).
    """
    scored_places = []

    for place in candidate_places:
        place_tags = place.get("tags", [])
        member_scores = [
            calculate_cbf_score(member.get("activities", []), place_tags)
            for member in group_profiles
        ]

        if not member_scores:
            avg_score = 0.0
            min_score = 0.0
        else:
            avg_score = sum(member_scores) / len(member_scores)
            min_score = min(member_scores)

        final_group_score = (alpha * avg_score) + ((1 - alpha) * min_score)

        scored_places.append({
            **place,
            "group_score": round(final_group_score, 4),
            "member_scores": [round(s, 2) for s in member_scores]
        })

    return sorted(scored_places, key=lambda x: x["group_score"], reverse=True)