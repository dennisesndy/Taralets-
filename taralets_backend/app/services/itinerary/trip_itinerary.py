from __future__ import annotations

import csv
import json
import math
import re
from datetime import date as Date, datetime, time
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
    target = math.floor(sum(place_targets) / len(place_targets) + 0.5) if place_targets else None
    return preferences, target


def build_trip_itinerary(
    group_profiles: list[dict[str, Any]],
    candidate_places: list[Any],
    *,
    trip_date: Date | None = None,
    start_time: Any = None,
    start_location: dict[str, float] | None = None,
    origin_lat: float | None = None,
    origin_lon: float | None = None,
) -> dict[str, Any]:
    route = generate_group_acs_itinerary(
        group_profiles=group_profiles,
        candidate_places=candidate_places,
        start_location=start_location,
        origin_lat=origin_lat,
        origin_lon=origin_lon,
        desired_places_per_day=summarize_group_preferences(group_profiles)[1],
    )

    route_items = route.get("itinerary") or []
    cursor = _parse_clock(start_time) or time(9, 0)
    previous_place: Any = None

    stops: list[dict[str, Any]] = []
    all_warnings: list[str] = []

    total_duration = 0
    total_travel = 0
    total_travel_cost = 0
    total_budget = 0
    total_distance = 0.0

    first_start: time | None = None
    last_end: time | None = None

    for item in route_items:
        place = item.get("place") or {}

        if previous_place is not None:
            distance = _distance_km(previous_place, place)
        elif start_location:
            distance = _distance_km(start_location, place)
        else:
            distance = 0.0

        travel_minutes, travel_cost = _travel_estimate(distance)
        cursor = _add_minutes(cursor, travel_minutes)

        duration = _estimate_duration_minutes(place)
        open_clock = _parse_clock(_get(place, "open_time"))
        close_clock = _parse_clock(_get(place, "close_time"))

        warnings: list[str] = []
        feasible = True

        if _closed_on(place, trip_date):
            feasible = False
            warnings.append(
                f"Closed on {trip_date.strftime('%A')}."
            )

        if open_clock is not None and cursor < open_clock:
            cursor = open_clock
            warnings.append(
                f"Opens at {_format_clock(open_clock)}."
            )

        end = _add_minutes(cursor, duration)

        if close_clock is not None and not (
            open_clock is not None and close_clock < open_clock
        ):
            if cursor > close_clock:
                feasible = False
                warnings.append(
                    f"Starts after closing at "
                    f"{_format_clock(close_clock)}."
                )
            elif end > close_clock:
                feasible = False
                warnings.append(
                    f"Ends after closing at "
                    f"{_format_clock(close_clock)}."
                )

        if first_start is None:
            first_start = cursor
        last_end = end

        warning = " ".join(warnings) or None
        if warning:
            all_warnings.append(warning)

        budget = _place_budget(place)

        stops.append(
            {
                "sequence": item.get("sequence"),
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
                "activity_tags": _unique_strings(
                    _get(place, "activity_tags", [])
                ),
                "dietary_tags": _unique_strings(
                    _get(place, "dietary_options", [])
                ),
                "accessibility_tags": _unique_strings(
                    _get(place, "accessibility_pets", [])
                ),
                "accessibility_match_status": _get(place, "accessibility_match_status", "unknown"),
                "start_time": _format_clock(cursor),
                "end_time": _format_clock(end),
                "duration_minutes": duration,
                "travel_minutes": travel_minutes,
                "travel_cost": travel_cost,
                "travel_distance_km": round(distance, 2),
                "budget": budget,
                "group_score": round(
                    float(item.get("group_score", 0.0) or 0.0),
                    4,
                ),
                "member_scores": _get(place, "member_scores", []) or [],
                "open_time": _format_clock(open_clock),
                "close_time": _format_clock(close_clock),
                "days_open": _get(place, "days_open", []) or [],
                "feasible": feasible,
                "warning": warning,
            }
        )

        total_duration += duration
        total_travel += travel_minutes
        total_travel_cost += travel_cost
        total_budget += budget
        total_distance += distance

        previous_place = place
        cursor = end

    summary = {
        "total_stops": len(stops),
        "total_duration_minutes": total_duration,
        "total_travel_minutes": total_travel,
        "total_travel_cost": total_travel_cost,
        "total_budget": total_budget,
        "total_distance_km": round(total_distance, 2),
        "start_time": _format_clock(first_start),
        "end_time": _format_clock(last_end),
        "span_minutes": (
            _minutes_between(first_start, last_end)
            if first_start is not None and last_end is not None
            else 0
        ),
    }

    return {
        "algorithm": route.get("algorithm", "group_acs"),
        "objective_score": route.get("objective_score"),
        "parameters": route.get("parameters"),
        "stops": stops,
        "summary": summary,
        "warnings": all_warnings,
    }
