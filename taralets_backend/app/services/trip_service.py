import math
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.trip import Trip, TripMember


DEFAULT_MAX_BUDGET = 2500.0
IGNORED_TAGS = {"none", "n/a", "not applicable"}


def _clean_tags(values: Any) -> list[str]:
    """Return clean, unique tags while preserving their original case."""
    if values is None:
        return []

    if isinstance(values, str):
        values = [values]

    if not isinstance(values, (list, tuple, set)):
        return []

    cleaned = []
    seen = set()

    for value in values:
        if not isinstance(value, str):
            continue

        tag = value.strip()

        if not tag:
            continue

        key = tag.casefold()

        if key in IGNORED_TAGS or key in seen:
            continue

        seen.add(key)
        cleaned.append(tag)

    return cleaned


def _safe_budget(value: Any) -> float:
    try:
        budget = float(value)
    except (TypeError, ValueError):
        return DEFAULT_MAX_BUDGET

    if not math.isfinite(budget) or budget < 0:
        return DEFAULT_MAX_BUDGET

    return budget


def _safe_place_count(value: Any) -> int | None:
    try:
        count = int(value)
    except (TypeError, ValueError):
        return None
    return count if count >= 1 else None


def build_group_profiles(trip: Trip) -> list[dict]:
    """
    Build one scoring profile for every member of a trip.

    Members without saved preferences are kept with neutral defaults so
    they still count in group consensus instead of being silently skipped.

    Trip-level preferences are deliberately not copied into those
    defaults, because that would double-count the same preferences.

    The caller must load ``trip.members`` and each member's
    ``preferences`` relationship, for example with ``selectinload``.
    """
    if trip is None:
        return []

    members = sorted(
        trip.members or [],
        key=lambda member: (
            not bool(getattr(member, "is_leader", False)),
            str(getattr(member, "id", "")),
        ),
    )

    profiles = []

    for member in members:
        preference = getattr(member, "preferences", None)
        has_preferences = preference is not None

        activity_tags = _clean_tags(
            getattr(preference, "activity_tags", None)
        )
        dietary_preferences = _clean_tags(
            getattr(preference, "dietary_preferences", None)
        )
        accessibility_preferences = _clean_tags(
            getattr(preference, "accessibility_preferences", None)
        )

        max_budget = (
            _safe_budget(
                getattr(preference, "max_budget", None)
            )
            if has_preferences
            else DEFAULT_MAX_BUDGET
        )

        desired_places_per_day = _safe_place_count(
            getattr(preference, "desired_places_per_day", None)
        ) if has_preferences else None

        user_id = getattr(member, "user_id", None)

        profiles.append(
            {
                "id": getattr(member, "id", None),
                "member_id": getattr(member, "id", None),
                "user_id": str(user_id) if user_id else None,
                "is_leader": bool(
                    getattr(member, "is_leader", False)
                ),
                "status": (
                    getattr(member, "status", None) or "notReady"
                ),
                "has_preferences": has_preferences,
                "source": (
                    "member" if has_preferences else "default"
                ),
                "activity_tags": activity_tags,
                "activities": list(activity_tags),
                "dietary_preferences": dietary_preferences,
                "max_budget": max_budget,
                "desired_places_per_day": desired_places_per_day,
                "accessibility_preferences": (
                    accessibility_preferences
                ),
            }
        )

    return profiles


async def load_group_profiles(
    db: AsyncSession,
    trip_id: str,
) -> list[dict] | None:
    """
    Load a trip with its members and preferences, then build profiles.

    Returns ``None`` when the trip does not exist.
    """
    result = await db.execute(
        select(Trip)
        .options(
            selectinload(Trip.members).selectinload(
                TripMember.preferences
            )
        )
        .where(Trip.id == trip_id)
    )

    trip = result.scalars().first()

    if trip is None:
        return None

    return build_group_profiles(trip)
