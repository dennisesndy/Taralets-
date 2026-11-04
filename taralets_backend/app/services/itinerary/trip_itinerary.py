from __future__ import annotations

import csv
import json
import math
import re
from datetime import date as Date, datetime, time, timedelta
from io import StringIO
from typing import Any

from app.services.itinerary.route_sequencing import (
    generate_group_acs_itinerary,
)


DAY_NAMES = (
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
)

DAY_ALIASES = {name[:3]: name for name in DAY_NAMES}
DAY_ALIASES.update({name[:2]: name for name in DAY_NAMES})
DAY_INDEX = {name: index for index, name in enumerate(DAY_NAMES)}


def _day_key(value: Any) -> str | None:
    text = str(value).strip().casefold()
    if not text:
        return None

    return (
        DAY_ALIASES.get(text)
        or DAY_ALIASES.get(text[:3])
        or DAY_ALIASES.get(text[:2])
    )


def _get(place: Any, key: str, default=None):
    if isinstance(place, dict):
        return place.get(key, default)
    return getattr(place, key, default)


def _parse_clock(value: Any) -> time | None:
    if value is None:
        return None

    if isinstance(value, datetime):
        return value.time()

    if isinstance(value, time):
        return value

    text = str(value).strip()

    if not text or text.casefold() in {"none", "n/a", "na", "-"}:
        return None

    for pattern in ("%H:%M:%S", "%H:%M", "%I:%M %p", "%I:%M%p"):
        try:
            return datetime.strptime(text, pattern).time()
        except ValueError:
            continue

    return None


def _format_clock(value: time | None) -> str | None:
    if value is None:
        return None
    return value.strftime("%H:%M")


def _parse_days(value: Any) -> set[str]:
    if value is None:
        return set()

    if isinstance(value, str):
        raw_values = [value]
    elif isinstance(value, (list, tuple, set)):
        raw_values = list(value)
    else:
        raw_values = [value]

    days: set[str] = set()

    for item in raw_values:
        text = str(item).strip().casefold()
        if not text:
            continue

        if any(token in text for token in ("daily", "every day", "everyday")):
            return set(DAY_NAMES)

        if "weekday" in text:
            days.update(DAY_NAMES[:5])
            continue

        if "weekend" in text:
            days.update(DAY_NAMES[5:])
            continue

        for segment in re.split(r"[,;/]", text):
            segment = segment.strip()
            if not segment:
                continue

            endpoints = re.split(
                r"\s*(?:-|–|—|\bto\b)\s*",
                segment,
            )

            if len(endpoints) >= 2:
                start = _day_key(endpoints[0])
                end = _day_key(endpoints[-1])

                if start is not None and end is not None:
                    start_index = DAY_INDEX[start]
                    end_index = DAY_INDEX[end]

                    if start_index <= end_index:
                        days.update(DAY_NAMES[start_index:end_index + 1])
                    else:
                        days.update(DAY_NAMES[start_index:])
                        days.update(DAY_NAMES[:end_index + 1])
                    continue

            for token in re.split(r"[^a-z]+", segment):
                key = _day_key(token)
                if key is not None:
                    days.add(key)

    return days


def _closed_on(place: Any, trip_date: Date | None) -> bool:
    if trip_date is None:
        return False

    days = _parse_days(_get(place, "days_open"))
    if not days:
        return False

    return DAY_NAMES[trip_date.weekday()] not in days


def _safe_cost(value: Any) -> float:
    if value is None:
        return 0.0

    if isinstance(value, (int, float)):
        return float(value)

    text = str(value).strip()

    if not text or text.casefold() in {"free", "none", "n/a", "na", "-"}:
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
        return 0.0


def _place_budget(place: Any) -> int:
    return int(
        round(
            max(
                _safe_cost(_get(place, "min_cost", 0)),
                _safe_cost(_get(place, "max_cost", 0)),
                _safe_cost(_get(place, "entrance_fee", 0)),
            )
        )
    )


def _estimate_duration_minutes(place: Any) -> int:
    category = str(_get(place, "category", "") or "").casefold()

    if any(
        token in category
        for token in ("food", "restaurant", "cafe", "eatery")
    ):
        return 60

    if any(token in category for token in ("museum", "gallery")):
        return 75

    if any(token in category for token in ("park", "plaza")):
        return 45

    if any(token in category for token in ("shopping", "market")):
        return 60

    if any(
        token in category
        for token in ("church", "historical", "heritage")
    ):
        return 45

    return 50


def _place_labels(place: Any) -> list[str]:
    activity_tags = _get(place, "activity_tags", []) or []
    if isinstance(activity_tags, str):
        activity_tags = [activity_tags]
    values = [
        _get(place, "category", ""),
        _get(place, "sub_category_1", ""),
        _get(place, "sub_category_2", ""),
        _get(place, "sub_category_3", ""),
        *activity_tags,
    ]
    return [str(value).casefold() for value in values if value]


def _is_restaurant(place: Any) -> bool:
    labels = _place_labels(place)
    return any(
        token in label
        for label in labels
        for token in ("restaurant", "eatery", "food court", "carinderia", "diner")
    )


def _is_cafe(place: Any) -> bool:
    return any(
        token in label
        for label in _place_labels(place)
        for token in ("cafe", "café", "coffee shop", "tea house")
    )


def _place_bucket(place: Any) -> str:
    labels = _place_labels(place)
    checks = (
        ("restaurant", ("restaurant", "eatery", "food court", "carinderia", "diner")),
        ("cafe", ("cafe", "café", "coffee shop", "tea house")),
        ("culture", ("museum", "gallery", "historical", "heritage", "church", "temple", "shrine")),
        ("outdoors", ("park", "plaza", "garden")),
        ("shopping", ("shopping", "retail", "market", "bookstore", "book store", "store")),
        ("entertainment", ("entertainment", "leisure", "cinema", "arcade", "amusement")),
        ("wellness", ("wellness", "health", "spa", "gym", "salon")),
        ("lodging", ("accommodation", "hotel", "hostel", "lodging", "guest house")),
    )
    for bucket, tokens in checks:
        if any(token in label for label in labels for token in tokens):
            return bucket
    return labels[0] if labels else "other"


def _balance_route_by_day(
    route_items: list[dict[str, Any]],
    duration_days: int,
    start_location: dict[str, float] | None,
) -> list[list[dict[str, Any]]]:
    """Balance selected places by category and spread meal stops across days."""
    daily_items: list[list[dict[str, Any]]] = [[] for _ in range(duration_days)]
    if not route_items:
        return daily_items

    base, remainder = divmod(len(route_items), duration_days)
    capacities = [base + (1 if day < remainder else 0) for day in range(duration_days)]
    meal_items = [
        item
        for item in route_items
        if _is_restaurant(item.get("place") or {})
        or _is_cafe(item.get("place") or {})
    ]
    meal_item_ids = {id(item) for item in meal_items}
    bucket_counts: list[dict[str, int]] = [dict() for _ in range(duration_days)]
    meal_counts = [0 for _ in range(duration_days)]

    def add_to_day(item: dict[str, Any], day_index: int) -> None:
        daily_items[day_index].append(item)
        bucket = _place_bucket(item.get("place") or {})
        bucket_counts[day_index][bucket] = bucket_counts[day_index].get(bucket, 0) + 1

    # Spread selected restaurants and cafes across the days before placing
    # attractions, so each day gets a dining stop when enough were selected.
    for item in meal_items:
        available = [
            index for index, day in enumerate(daily_items)
            if len(day) < capacities[index]
        ]
        if not available:
            break
        day_index = min(
            available,
            key=lambda index: (
                meal_counts[index],
                len(daily_items[index]) / max(1, capacities[index]),
                index,
            ),
        )
        add_to_day(item, day_index)
        meal_counts[day_index] += 1

    for item in route_items:
        if id(item) in meal_item_ids:
            continue
        place = item.get("place") or {}
        bucket = _place_bucket(place)
        available = [
            index for index, day in enumerate(daily_items)
            if len(day) < capacities[index]
        ]
        if not available:
            break

        def assignment_cost(index: int) -> tuple[float, float, int]:
            same_category = bucket_counts[index].get(bucket, 0)
            day_places = [entry.get("place") or {} for entry in daily_items[index]]
            if day_places:
                distance = min(_distance_km(place, other) for other in day_places)
            elif start_location:
                distance = _distance_km(start_location, place)
            else:
                distance = 0.0
            return (
                float(same_category),
                len(daily_items[index]) / max(1, capacities[index]) + distance / 1000,
                index,
            )

        add_to_day(item, min(available, key=assignment_cost))

    # Keep attraction order mostly intact while spacing selected dining stops
    # through each day's activities, where they naturally work as breaks.
    for index, day in enumerate(daily_items):
        meals = [item for item in day if id(item) in meal_item_ids]
        other_stops = [item for item in day if id(item) not in meal_item_ids]
        if meals:
            balanced = list(other_stops)
            for meal_index, meal in enumerate(meals):
                position = (
                    (meal_index + 1) * len(other_stops) // (len(meals) + 1)
                ) + meal_index
                balanced.insert(min(position, len(balanced)), meal)
            daily_items[index] = balanced
        else:
            daily_items[index] = sorted(day, key=route_items.index)

    return daily_items


def _distance_km(first: Any, second: Any) -> float:
    lat1 = _get(first, "lat", _get(first, "latitude"))
    lon1 = _get(first, "lng", _get(first, "longitude"))
    lat2 = _get(second, "lat", _get(second, "latitude"))
    lon2 = _get(second, "lng", _get(second, "longitude"))

    if None in (lat1, lon1, lat2, lon2):
        return 0.0

    try:
        lat1, lon1, lat2, lon2 = map(
            float,
            (lat1, lon1, lat2, lon2),
        )
    except (TypeError, ValueError):
        return 0.0

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


def _travel_estimate(distance_km: float) -> tuple[int, int]:
    if distance_km <= 0.05:
        return 0, 0

    # V1 estimate: 18 km/h city travel and a simple distance-based fare.
    minutes = max(5, int(round((distance_km / 18.0) * 60)))
    cost = max(0, int(round(distance_km * 15.0)))
    return minutes, cost


def _add_minutes(value: time, minutes: int) -> time:
    total = value.hour * 60 + value.minute + max(0, minutes)
    return time((total // 60) % 24, total % 60)


def _minutes_between(start: time, end: time) -> int:
    return (
        (end.hour * 60 + end.minute)
        - (start.hour * 60 + start.minute)
    ) % (24 * 60)


def _unique_strings(values: Any) -> list[str]:
    """Flatten tags, including values serialized as Postgres array text."""
    result: list[str] = []
    seen: set[str] = set()

    if values is None:
        return result

    if isinstance(values, str):
        text = values.strip()
        if not text:
            return result
        if text.startswith("["):
            try:
                decoded = json.loads(text)
                if isinstance(decoded, list):
                    values = decoded
                else:
                    values = [text]
            except (TypeError, ValueError):
                values = [text]
        else:
            values = [text]

    if not isinstance(values, (list, tuple, set)):
        return result

    for value in values:
        text = str(value).strip()
        # CSV parsing honors quoted commas and handles the common dataset
        # representation: {"Coffee Shop", Cafe, Food}.
        if len(text) >= 2 and text[0] in "{[" and text[-1] in "}]":
            text = text[1:-1].strip()
        try:
            parts = next(csv.reader(StringIO(text), skipinitialspace=True))
        except (csv.Error, StopIteration):
            parts = [text]
        for part in parts:
            label = part.strip().strip("\\\"'").strip()
            if not label or label.casefold() in {"none", "null", "nan"}:
                continue
            key = label.casefold()
            if key not in seen:
                seen.add(key)
                result.append(label)

    return result


def summarize_group_preferences(
    group_profiles: list[dict[str, Any]],
) -> tuple[list[str], int | None]:
    tags: list[str] = []
    budgets: list[float] = []
    accessibility: list[str] = []
    place_targets: list[int] = []

    for profile in group_profiles:
        tags.extend(_unique_strings(profile.get("activity_tags")))
        accessibility.extend(_unique_strings(profile.get("accessibility_preferences")))
        target = profile.get("desired_places_per_day")
        try:
            if target is not None and profile.get("has_preferences"):
                target = int(target)
                if target > 0:
                    place_targets.append(target)
        except (TypeError, ValueError):
            pass

        budget = profile.get("max_budget")
        try:
            if profile.get("has_preferences") and budget is not None:
                budgets.append(float(budget))
        except (TypeError, ValueError):
            pass

    unique_tags = _unique_strings(tags)
    preferences = unique_tags[:3]

    if budgets:
        preferences.append(f"₱{min(budgets):,.0f} / person")
    preferences.extend(f"Accessibility: {tag}" for tag in _unique_strings(accessibility))
    # Trip length now controls multi-day planning; place-count preferences no
    # longer cap the selected itinerary stops.
    return preferences, None


def build_trip_itinerary(
    group_profiles: list[dict[str, Any]],
    candidate_places: list[Any],
    *,
    trip_date: Date | None = None,
    start_time: Any = None,
    start_location: dict[str, float] | None = None,
    origin_lat: float | None = None,
    origin_lon: float | None = None,
    duration_days: int = 1,
) -> dict[str, Any]:
    duration_days = max(1, min(int(duration_days or 1), 30))
    route = generate_group_acs_itinerary(
        group_profiles=group_profiles,
        candidate_places=candidate_places,
        start_location=start_location,
        origin_lat=origin_lat,
        origin_lon=origin_lon,
        desired_places_per_day=None,
    )

    route_items = route.get("itinerary") or []
    daily_items = _balance_route_by_day(route_items, duration_days, start_location)

    days: list[dict[str, Any]] = []
    stops: list[dict[str, Any]] = []
    all_warnings: list[str] = []

    total_duration = 0
    total_travel = 0
    total_travel_cost = 0
    total_budget = 0
    total_distance = 0.0

    first_start: time | None = None
    last_end: time | None = None
    start_clock = _parse_clock(start_time) or time(9, 0)
    meal_item_ids = {
        id(item)
        for item in route_items
        if _is_restaurant(item.get("place") or {})
        or _is_cafe(item.get("place") or {})
    }

    for day_index, day_items in enumerate(daily_items):
        day_date = trip_date + timedelta(days=day_index) if trip_date else None
        cursor = start_clock if day_index == 0 else time(9, 0)
        previous_place: Any = None
        day_stops: list[dict[str, Any]] = []

        for item in day_items:
            place = item.get("place") or {}
            if previous_place is not None:
                distance = _distance_km(previous_place, place)
            elif start_location:
                distance = _distance_km(start_location, place)
            else:
                distance = 0.0

            travel_minutes, travel_cost = _travel_estimate(distance)
            cursor = _add_minutes(cursor, travel_minutes)
            if day_index > 0 and id(item) in meal_item_ids and cursor < time(12, 0):
                cursor = time(12, 0)
            duration = _estimate_duration_minutes(place)
            open_clock = _parse_clock(_get(place, "open_time"))
            close_clock = _parse_clock(_get(place, "close_time"))
            warnings: list[str] = []
            feasible = True

            if day_date and _closed_on(place, day_date):
                feasible = False
                warnings.append(f"Closed on {day_date.strftime('%A')}.")
            if open_clock is not None and cursor < open_clock:
                cursor = open_clock
                warnings.append(f"Opens at {_format_clock(open_clock)}.")

            end = _add_minutes(cursor, duration)
            if close_clock is not None and not (open_clock is not None and close_clock < open_clock):
                if cursor > close_clock:
                    feasible = False
                    warnings.append(f"Starts after closing at {_format_clock(close_clock)}.")
                elif end > close_clock:
                    feasible = False
                    warnings.append(f"Ends after closing at {_format_clock(close_clock)}.")

            if first_start is None:
                first_start = cursor
            last_end = end
            warning = " ".join(warnings) or None
            if warning:
                all_warnings.append(warning)
            budget = _place_budget(place)
            stop = {
                "sequence": len(stops) + 1,
                "day_number": day_index + 1,
                "date": day_date.isoformat() if day_date else None,
                "id": _get(place, "id"),
                "place_id": _get(place, "id"),
                "master_id": _get(place, "master_id"),
                "name": _get(place, "name") or "",
                "category": _get(place, "category") or "",
                "area": _get(place, "district") or "",
                "address": _get(place, "address") or "",
                "description": _get(place, "description") or "",
                "image_url": _get(place, "image_url") or "",
                "latitude": _get(place, "latitude"),
                "longitude": _get(place, "longitude"),
                "activity_tags": _unique_strings(_get(place, "activity_tags", [])),
                "dietary_tags": _unique_strings(_get(place, "dietary_options", [])),
                "accessibility_tags": _unique_strings(_get(place, "accessibility_pets", [])),
                "accessibility_match_status": _get(place, "accessibility_match_status", "unknown"),
                "start_time": _format_clock(cursor),
                "end_time": _format_clock(end),
                "duration_minutes": duration,
                "travel_minutes": travel_minutes,
                "travel_cost": travel_cost,
                "travel_distance_km": round(distance, 2),
                "budget": budget,
                "group_score": round(float(item.get("group_score", 0.0) or 0.0), 4),
                "member_scores": _get(place, "member_scores", []) or [],
                "open_time": _format_clock(open_clock),
                "close_time": _format_clock(close_clock),
                "days_open": _get(place, "days_open", []) or [],
                "feasible": feasible,
                "warning": warning,
            }
            stops.append(stop)
            day_stops.append(stop)
            total_duration += duration
            total_travel += travel_minutes
            total_travel_cost += travel_cost
            total_budget += budget
            total_distance += distance
            previous_place = place
            cursor = end

        days.append({
            "day_number": day_index + 1,
            "date": day_date.isoformat() if day_date else None,
            "label": f"Day {day_index + 1}" + (f" · {day_date.strftime('%b %d')}" if day_date else ""),
            "stops": day_stops,
        })

    summary = {
        "total_stops": len(stops),
        "total_duration_minutes": total_duration,
        "total_travel_minutes": total_travel,
        "total_travel_cost": total_travel_cost,
        "total_budget": total_budget,
        "total_distance_km": round(total_distance, 2),
        "start_time": _format_clock(first_start),
        "end_time": _format_clock(last_end),
        "span_minutes": sum(
            _minutes_between(
                _parse_clock(day["stops"][0]["start_time"]),
                _parse_clock(day["stops"][-1]["end_time"]),
            )
            for day in days
            if day["stops"]
        ),
    }

    return {
        "algorithm": route.get("algorithm", "group_acs"),
        "objective_score": route.get("objective_score"),
        "parameters": route.get("parameters"),
        "stops": stops,
        "days": days,
        "duration_days": duration_days,
        "summary": summary,
        "warnings": all_warnings,
    }
