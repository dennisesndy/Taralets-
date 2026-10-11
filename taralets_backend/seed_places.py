
import asyncio
import re
from datetime import datetime, time
from decimal import Decimal, InvalidOperation

import pandas as pd
from sqlalchemy import select, delete

from app.core.database import AsyncSessionLocal
from app.models.poi import Place


CSV_PATH = "sample cleaned - cleaned sample.csv"


def get_text(value):
    """Return None for empty values instead of storing 'nan'."""
    if value is None or pd.isna(value):
        return None

    value = str(value).strip()
    return value if value else None


def parse_array(value):
    value = get_text(value)
    if not value:
        return []

    # Accept comma-separated or semicolon-separated values.
    return [
        item.strip()
        for item in re.split(r"[,;]", value)
        if item.strip()
    ]


def parse_decimal(value, default=Decimal("0")):
    value = get_text(value)
    if not value:
        return default

    cleaned = value.replace(",", "").replace("₱", "")
    cleaned = cleaned.replace("PHP", "").replace("php", "").strip()

    if cleaned.lower() in {"free", "none", "n/a", "na", "-"}:
        return default

    try:
        return Decimal(cleaned)
    except InvalidOperation:
        return default


def parse_bool(value):
    value = get_text(value)
    if not value:
        return None

    normalized = value.lower()

    if normalized in {"yes", "y", "true", "1"}:
        return True
    if normalized in {"no", "n", "false", "0"}:
        return False

    return None


def parse_time(value):
    value = get_text(value)
    if not value:
        return None

    for fmt in ("%H:%M:%S", "%H:%M", "%I:%M %p", "%I:%M%p"):
        try:
            return datetime.strptime(value, fmt).time()
        except ValueError:
            continue

    return None



async def seed_places_from_csv(csv_path):
    df = pd.read_csv(
        csv_path,
        encoding="utf-8-sig",
        dtype=str,
        keep_default_na=False,
    )
    df.columns = df.columns.str.strip().str.lower()

    print(f"CSV loaded: {len(df)} rows")

    # Build the authoritative dataset from the CSV.
    records = {}
    skipped = 0

    for _, row in df.iterrows():
        master_id = get_text(row.get("master_id"))

        if not master_id:
            skipped += 1
            continue

        values = {
            "master_id": master_id,
            "district_id": get_text(row.get("district_id")),
            "district": get_text(row.get("district")),
            "name": get_text(row.get("name")),
            "category": get_text(row.get("category")),
            "sub_category_1": get_text(row.get("sub_category_1")),
            "sub_category_2": get_text(row.get("sub_category_2")),
            "sub_category_3": get_text(row.get("sub_category_3")),
            "description": get_text(row.get("description")),
            "image_url": get_text(row.get("image_url")),
            "address": get_text(row.get("address")),
            "latitude": float(parse_decimal(row.get("latitude")))
                if get_text(row.get("latitude")) else None,
            "longitude": float(parse_decimal(row.get("longitude")))
                if get_text(row.get("longitude")) else None,
            "activity_tags": parse_array(row.get("activity_tags")),
            "dietary_options": parse_array(row.get("dietary_options")),
            "entrance_fee": get_text(row.get("entrance_fee")),
            "min_cost": parse_decimal(row.get("min_cost")),
            "max_cost": parse_decimal(row.get("max_cost")),
            "pet_friendly": parse_bool(row.get("pet_friendly")),
            "wheelchair_accessible": parse_bool(
                row.get("wheelchair_accessible")
            ),
            "good_for_children": parse_bool(
                row.get("good_for_children")
            ),
            "days_open": parse_array(row.get("days_open")),
            "open_time": parse_time(row.get("open_time")),
            "close_time": parse_time(row.get("close_time")),
            "rating": parse_decimal(row.get("rating")),
            "reviews": int(parse_decimal(row.get("reviews"))),
        }

        # If the CSV repeats an ID, use its last occurrence only.
        records[master_id] = values

    if skipped:
        print(f"WARNING: {skipped} CSV rows have no master_id.")

    if not records:
        raise ValueError("No valid master_id values found. Import cancelled.")

    async with AsyncSessionLocal() as db:
        inserted = 0
        updated = 0

        try:
            result = await db.execute(select(Place))
            existing_places = result.scalars().all()

            existing_by_master_id = {}
            duplicate_ids = []

            # Keep one existing row for each master_id.
            for place in existing_places:
                if place.master_id in existing_by_master_id:
                    duplicate_ids.append(place.id)
                else:
                    existing_by_master_id[place.master_id] = place

            # Delete duplicate rows and old records absent from the CSV.
            csv_ids = set(records.keys())
            ids_to_delete = list(duplicate_ids)

            for place in existing_places:
                if place.master_id not in csv_ids:
                    ids_to_delete.append(place.id)

            if ids_to_delete:
                await db.execute(
                    delete(Place).where(Place.id.in_(set(ids_to_delete)))
                )

            # Update matching records and insert missing records.
            for master_id, values in records.items():
                place = existing_by_master_id.get(master_id)

                if place is not None and place.id not in ids_to_delete:
                    for key, value in values.items():
                        setattr(place, key, value)
                    updated += 1
                else:
                    db.add(Place(**values))
                    inserted += 1

            await db.commit()

            print("Import and cleanup complete!")
            print(f"CSV rows: {len(df)}")
            print(f"Unique CSV Master IDs: {len(records)}")
            print(f"Inserted: {inserted}")
            print(f"Updated: {updated}")
            print(f"Deleted old/duplicate records: {len(set(ids_to_delete))}")
            print(f"Skipped (missing Master ID): {skipped}")

        except Exception:
            await db.rollback()
            raise



if __name__ == "__main__":
    asyncio.run(seed_places_from_csv(CSV_PATH))
