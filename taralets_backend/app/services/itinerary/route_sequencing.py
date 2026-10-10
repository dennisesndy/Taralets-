import math
import random
from typing import Any

from app.services.itinerary.group_scoring import aggregate_group_scores


def _distance_km(a: dict[str, Any], b: dict[str, Any]) -> float:
    """Calculate straight-line distance between two POIs."""
    lat1 = a.get("lat", a.get("latitude"))
    lon1 = a.get("lng", a.get("longitude"))
    lat2 = b.get("lat", b.get("latitude"))
    lon2 = b.get("lng", b.get("longitude"))

    if None in (lat1, lon1, lat2, lon2):
        return 0.0

    lat1, lon1, lat2, lon2 = map(
        float, (lat1, lon1, lat2, lon2)
    )

    earth_radius = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    value = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )

    value = max(0.0, min(1.0, value))
    return 2 * earth_radius * math.asin(math.sqrt(value))


def generate_group_acs_itinerary(
    group_profiles: list[dict[str, Any]],
    candidate_places: list[dict[str, Any]],
    start_location: dict[str, float] | None = None,
    ant_count: int = 20,
    iterations: int = 30,
    alpha: float = 1.0,
    beta: float = 2.0,
    evaporation_rate: float = 0.3,
    q: float = 1.0,
    seed: int = 42,
) -> dict[str, Any]:
    """
    Generate a group itinerary using Ant Colony System principles.

    POIs are ranked by group preference compatibility. Ants then
    construct ordered routes using pheromone and heuristic scores.
    """
    if not group_profiles:
        raise ValueError("At least one group member is required")

    if not candidate_places:
        return {
            "total_stops": 0,
            "itinerary": [],
            "total_distance_km": 0.0,
            "algorithm": "group_acs",
        }

    if ant_count < 1 or iterations < 1:
        raise ValueError("ant_count and iterations must be positive")

    if not 0.0 < evaporation_rate < 1.0:
        raise ValueError("evaporation_rate must be between 0 and 1")

    rng = random.Random(seed)

    ranked_places = aggregate_group_scores(
        group_profiles,
        candidate_places,
    )

    if not ranked_places:
        return {
            "total_stops": 0,
            "itinerary": [],
            "total_distance_km": 0.0,
            "algorithm": "group_acs",
        }

    places = [
        place for place in ranked_places
        if place.get("id") is not None
    ]

    if not places:
        return {
            "total_stops": 0,
            "itinerary": [],
            "total_distance_km": 0.0,
            "algorithm": "group_acs",
        }

    # Normalize group scores into positive heuristic values.
    scores = [
        max(0.001, float(place.get("group_score", 0.0)))
        for place in places
    ]

    score_min = min(scores)
    score_max = max(scores)

    heuristics = {}
    for place, score in zip(places, scores):
        if score_max == score_min:
            heuristics[str(place["id"])] = 1.0
        else:
            heuristics[str(place["id"])] = (
                0.1 + (score - score_min) / (score_max - score_min)
            )

    ids = [str(place["id"]) for place in places]
    place_by_id = {str(place["id"]): place for place in places}

    # Initialize pheromone on every directed POI transition.
    pheromone = {
        (a, b): 1.0
        for a in ids
        for b in ids
        if a != b
    }

    def build_route() -> list[str]:
        remaining = set(ids)
        route = []

        if start_location:
            current = {
                "lat": start_location.get("lat"),
                "lng": start_location.get("lng"),
            }
        else:
            current = None

        while remaining:
            choices = []
            weights = []

            for candidate_id in remaining:
                place = place_by_id[candidate_id]
                heuristic = heuristics[candidate_id]

                if route:
                    transition = (
                        route[-1],
                        candidate_id,
                    )
                    trail = pheromone.get(transition, 1.0)
                    distance = _distance_km(
                        place_by_id[route[-1]],
                        place,
                    )
                elif current:
                    trail = 1.0
                    distance = _distance_km(current, place)
                else:
                    trail = 1.0
                    distance = 0.0

                distance_heuristic = 1.0 / (1.0 + distance)

                weight = (
                    max(trail, 0.001) ** alpha
                    * max(heuristic, 0.001) ** beta
                    * distance_heuristic
                )

                choices.append(candidate_id)
                weights.append(max(weight, 1e-12))

            # Roulette-wheel selection balances exploration and exploitation.
            total_weight = sum(weights)
            threshold = rng.random() * total_weight
            cumulative = 0.0
            selected = choices[-1]

            for candidate_id, weight in zip(choices, weights):
                cumulative += weight
                if cumulative >= threshold:
                    selected = candidate_id
                    break

            route.append(selected)
            remaining.remove(selected)

        return route

    def route_metrics(route: list[str]) -> tuple[float, float]:
        if not route:
            return 0.0, 0.0

        preference_score = sum(
            float(place_by_id[place_id].get("group_score", 0.0))
            for place_id in route
        )

        total_distance = 0.0

        if start_location:
            first = place_by_id[route[0]]
            total_distance += _distance_km(start_location, first)

        for index in range(1, len(route)):
            total_distance += _distance_km(
                place_by_id[route[index - 1]],
                place_by_id[route[index]],
            )

        # Preference remains the primary objective; distance is a penalty.
        objective = preference_score / (1.0 + total_distance / 10.0)
        return objective, total_distance

    best_route = []
    best_objective = -1.0
    best_distance = 0.0

    for _ in range(iterations):
        iteration_best_route = []
        iteration_best_objective = -1.0
        iteration_best_distance = 0.0

        for _ in range(ant_count):
            route = build_route()
            objective, distance = route_metrics(route)

            if objective > iteration_best_objective:
                iteration_best_route = route
                iteration_best_objective = objective
                iteration_best_distance = distance

            if objective > best_objective:
                best_route = route
                best_objective = objective
                best_distance = distance

        # Evaporate existing pheromone.
        for edge in pheromone:
            pheromone[edge] *= 1.0 - evaporation_rate

        # Reinforce the best route from this iteration.
        if iteration_best_route:
            deposit = q * max(iteration_best_objective, 0.001)

            for index in range(1, len(iteration_best_route)):
                edge = (
                    iteration_best_route[index - 1],
                    iteration_best_route[index],
                )
                pheromone[edge] += deposit

    itinerary = []

    for index, place_id in enumerate(best_route, start=1):
        place = place_by_id[place_id]
        itinerary.append({
            "sequence": index,
            "place": place,
            "group_score": place.get("group_score", 0.0),
            "constraint_check": place.get("constraint_check", {}),
        })

    return {
        "total_stops": len(itinerary),
        "itinerary": itinerary,
        "total_distance_km": round(best_distance, 2),
        "objective_score": round(max(best_objective, 0.0), 4),
        "algorithm": "group_acs",
        "parameters": {
            "ant_count": ant_count,
            "iterations": iterations,
            "alpha": alpha,
            "beta": beta,
            "evaporation_rate": evaporation_rate,
            "seed": seed,
        },
    }