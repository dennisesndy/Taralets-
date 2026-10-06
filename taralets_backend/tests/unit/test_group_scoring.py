import pytest
from app.services.itinerary.group_scoring import calculate_cbf_score, aggregate_group_scores

def test_calculate_cbf_score():
    user_tags = ["Heritage", "Photography"]
    place_tags = ["Heritage", "Food"]
    # Intersection = 1, Union = 3 -> 1/3 = 0.3333
    score = calculate_cbf_score(user_tags, place_tags)
    assert round(score, 2) == 0.33

def test_aggregate_group_scores_least_misery():
    profiles = [
        {"id": "u1", "activities": ["Heritage", "Café"]},
        {"id": "u2", "activities": ["Bar", "Nightlife"]}
    ]
    places = [
        {"id": "p1", "name": "Museum", "tags": ["Heritage"]},
        {"id": "p2", "name": "Pub", "tags": ["Bar", "Nightlife"]}
    ]
    
    results = aggregate_group_scores(profiles, places, alpha=0.5)
    assert len(results) == 2
    assert "group_score" in results[0]
    assert results[0]["group_score"] >= results[1]["group_score"]