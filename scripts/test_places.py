
import os
import requests
import pandas as pd
from dotenv import load_dotenv


# ============================================================
# TEST MODE SETTINGS
# ============================================================

TEST_MODE = True

# Maximum number of unique places to collect
TEST_LIMIT = 10

# Test only ONE district and ONE category first
TEST_DISTRICT = "Binondo"
TEST_CATEGORY = "restaurants"


# ============================================================
# LOAD ENVIRONMENT VARIABLES
# ============================================================

load_dotenv()

API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")

if not API_KEY:
    raise ValueError(
        "GOOGLE_PLACES_API_KEY was not found.\n"
        "Make sure your .env file contains:\n"
        "GOOGLE_PLACES_API_KEY=your_api_key"
    )


# ============================================================
# GOOGLE PLACES API
# ============================================================

API_URL = (
    "https://places.googleapis.com/v1/places:searchText"
)

FIELD_MASK = (
    "places.id,"
    "places.displayName,"
    "places.editorialSummary,"
    "places.photos,"
    "places.formattedAddress,"
    "places.location,"
    "places.types,"
    "places.accessibilityOptions,"
    "places.allowsDogs,"
    "places.regularOpeningHours,"
    "places.rating,"
    "places.userRatingCount,"
    "places.priceLevel"
)

HEADERS = {
    "Content-Type": "application/json",
    "X-Goog-Api-Key": API_KEY,
    "X-Goog-FieldMask": FIELD_MASK
}


# ============================================================
# PRICE RANGES
# ============================================================

PRICE_RANGES = {

    "PRICE_LEVEL_FREE": {
        "min": 0,
        "max": 0
    },

    "PRICE_LEVEL_INEXPENSIVE": {
        "min": 50,
        "max": 300
    },

    "PRICE_LEVEL_MODERATE": {
        "min": 300,
        "max": 700
    },

    "PRICE_LEVEL_EXPENSIVE": {
        "min": 700,
        "max": 1000
    },

    "PRICE_LEVEL_VERY_EXPENSIVE": {
        "min": 1000,
        "max": 2000
    }
}


# ============================================================
# DESCRIPTION
# ============================================================

def get_description(place, category, district):

    editorial_summary = place.get(
        "editorialSummary",
        {}
    )

    description = editorial_summary.get(
        "text"
    )

    if description:
        return description

    name = place.get(
        "displayName",
        {}
    ).get(
        "text",
        "This establishment"
    )

    address = place.get(
        "formattedAddress",
        ""
    )

    if address:
        return (
            f"{name} is a {category.lower()} "
            f"located in {district}, Manila. "
            f"It is located at {address}."
        )

    return (
        f"{name} is a {category.lower()} "
        f"located in {district}, Manila."
    )


# ============================================================
# PHOTO URL
# ============================================================

def get_photo_url(place):

    photos = place.get(
        "photos",
        []
    )

    if not photos:
        return ""

    photo_name = photos[0].get(
        "name"
    )

    if not photo_name:
        return ""

    return (
        "https://places.googleapis.com/v1/"
        f"{photo_name}/media"
        "?maxHeightPx=400"
        "&maxWidthPx=400"
        f"&key={API_KEY}"
    )


# ============================================================
# OPENING HOURS
# ============================================================

def parse_opening_hours(place):

    opening_hours = place.get(
        "regularOpeningHours",
        {}
    )

    weekday_descriptions = opening_hours.get(
        "weekdayDescriptions",
        []
    )

    days_open = []
    open_times = []
    close_times = []

    for day in weekday_descriptions:

        if ":" not in day:
            continue

        day_name, schedule = day.split(
            ":",
            1
        )

        day_name = day_name.strip()
        schedule = schedule.strip()

        if schedule.lower() == "closed":
            continue

        days_open.append(day_name)

        if "–" in schedule:
            parts = schedule.split("–")

        elif "-" in schedule:
            parts = schedule.split("-")

        else:
            continue

        if len(parts) == 2:

            open_times.append(
                parts[0].strip()
            )

            close_times.append(
                parts[1].strip()
            )

    return (

        ", ".join(days_open)
        if days_open
        else "N/A",

        open_times[0]
        if open_times
        else "N/A",

        close_times[0]
        if close_times
        else "N/A"
    )


# ============================================================
# ACCESSIBILITY
# ============================================================

def parse_accessibility(place):

    accessibility = place.get(
        "accessibilityOptions",
        {}
    )

    items = []

    for key, value in accessibility.items():

        if isinstance(value, bool):

            formatted_key = (
                key
                .replace("_", " ")
                .title()
            )

            items.append(
                f"{formatted_key}: {value}"
            )

    allows_dogs = place.get(
        "allowsDogs"
    )

    if allows_dogs is not None:

        items.append(
            f"Dogs Allowed: {allows_dogs}"
        )

    if not items:
        return "N/A"

    return " | ".join(items)


# ============================================================
# COST RANGE
# ============================================================

def get_cost_range(place):

    price_level = place.get(
        "priceLevel"
    )

    if not price_level:
        return "N/A", "N/A"

    price_data = PRICE_RANGES.get(
        price_level
    )

    if not price_data:
        return "N/A", "N/A"

    return (
        price_data["min"],
        price_data["max"]
    )


# ============================================================
# SEARCH
# ============================================================

def search_places(
    district,
    category
):

    query = (
        f"{category} "
        f"in {district}, Manila, Philippines"
    )

    print()
    print(
        "============================================================"
    )

    print(
        f"Searching: {query}"
    )

    print(
        "TEST MODE: maximum 10 places"
    )

    print(
        "============================================================"
    )

    payload = {
        "textQuery": query,

        # Only request 10 results
        "pageSize": TEST_LIMIT
    }

    try:

        response = requests.post(
            API_URL,
            json=payload,
            headers=HEADERS,
            timeout=30
        )

    except requests.RequestException as e:

        print()
        print(
            f"REQUEST ERROR: {e}"
        )

        return []

    print()
    print(
        f"HTTP Status: {response.status_code}"
    )

    if response.status_code != 200:

        print()
        print(
            "Google API returned an error:"
        )

        print(
            response.text
        )

        return []

    data = response.json()

    places = data.get(
        "places",
        []
    )

    # Extra safety
    places = places[
        :TEST_LIMIT
    ]

    print(
        f"Places returned: {len(places)}"
    )

    return places


# ============================================================
# MAIN
# ============================================================

if __name__ == "__main__":

    print()
    print(
        "============================================================"
    )

    print(
        "TARALETS! TEST MODE"
    )

    print(
        "============================================================"
    )

    print(
        f"District : {TEST_DISTRICT}"
    )

    print(
        f"Category : {TEST_CATEGORY}"
    )

    print(
        f"Limit    : {TEST_LIMIT} places"
    )

    print(
        "============================================================"
    )


    # --------------------------------------------------------
    # SEARCH
    # --------------------------------------------------------

    places = search_places(
        TEST_DISTRICT,
        TEST_CATEGORY
    )


    if not places:

        print()
        print(
            "No places found."
        )

        exit()


    # --------------------------------------------------------
    # CONVERT TO CSV ROWS
    # --------------------------------------------------------

    rows = []

    seen_ids = set()


    for index, place in enumerate(
        places,
        start=1
    ):

        place_id = place.get(
            "id"
        )

        # Skip duplicate Place IDs
        if (
            not place_id
            or place_id in seen_ids
        ):
            continue

        seen_ids.add(
            place_id
        )


        # ----------------------------------------------------
        # ID
        # ----------------------------------------------------

        generated_id = (
            f"BND-{index:04d}"
        )


        # ----------------------------------------------------
        # NAME
        # ----------------------------------------------------

        name = place.get(
            "displayName",
            {}
        ).get(
            "text",
            "N/A"
        )


        # ----------------------------------------------------
        # DESCRIPTION
        # ----------------------------------------------------

        description = get_description(

            place,

            TEST_CATEGORY.title(),

            TEST_DISTRICT
        )


        # ----------------------------------------------------
        # ADDRESS
        # ----------------------------------------------------

        address = place.get(
            "formattedAddress",
            "N/A"
        )


        # ----------------------------------------------------
        # LOCATION
        # ----------------------------------------------------

        location = place.get(
            "location",
            {}
        )

        latitude = location.get(
            "latitude"
        )

        longitude = location.get(
            "longitude"
        )


        # ----------------------------------------------------
        # IMAGE
        # ----------------------------------------------------

        image_url = get_photo_url(
            place
        )


        # ----------------------------------------------------
        # ACTIVITY TAGS
        # ----------------------------------------------------

        activity_tags = ", ".join(
            place.get(
                "types",
                []
            )
        )


        # ----------------------------------------------------
        # OPENING HOURS
        # ----------------------------------------------------

        (
            days_open,
            open_time,
            close_time
        ) = parse_opening_hours(
            place
        )


        # ----------------------------------------------------
        # ACCESSIBILITY
        # ----------------------------------------------------

        accessibility_pets = (
            parse_accessibility(
                place
            )
        )


        # ----------------------------------------------------
        # COST
        # ----------------------------------------------------

        min_cost, max_cost = (
            get_cost_range(
                place
            )
        )


        # ----------------------------------------------------
        # RATING
        # ----------------------------------------------------

        rating = place.get(
            "rating",
            0
        )


        # ----------------------------------------------------
        # REVIEWS
        # ----------------------------------------------------

        reviews = place.get(
            "userRatingCount",
            0
        )


        # ====================================================
        # 21 COLUMNS
        # ====================================================

        rows.append({

            "ID": generated_id,

            "District": TEST_DISTRICT,

            "Category": TEST_CATEGORY.title(),

            "Name": name,

            "Description": description,

            "Image URL": image_url,

            "Address": address,

            "Latitude": latitude,

            "Longitude": longitude,

            "Activity Tags": activity_tags,

            "Dietary Options": "N/A",

            "Entrance Fee": "N/A",

            "Min Cost": min_cost,

            "Max Cost": max_cost,

            "Pace": "N/A",

            "Accessibility & Pets": accessibility_pets,

            "Days Open": days_open,

            "Open Time": open_time,

            "Close Time": close_time,

            "Rating": rating,

            "Reviews": reviews
        })


    # ========================================================
    # CREATE DATAFRAME
    # ========================================================

    df = pd.DataFrame(
        rows
    )


    # ========================================================
    # FORCE EXACT 21-COLUMN ORDER
    # ========================================================

    columns = [

        "ID",
        "District",
        "Category",
        "Name",
        "Description",
        "Image URL",
        "Address",
        "Latitude",
        "Longitude",
        "Activity Tags",
        "Dietary Options",
        "Entrance Fee",
        "Min Cost",
        "Max Cost",
        "Pace",
        "Accessibility & Pets",
        "Days Open",
        "Open Time",
        "Close Time",
        "Rating",
        "Reviews"
    ]

    df = df[
        columns
    ]


    # ========================================================
    # SAVE TEST CSV
    # ========================================================

    output_file = (
        "taralets_test_10_places.csv"
    )

    df.to_csv(

        output_file,

        index=False,

        encoding="utf-8-sig"
    )


    # ========================================================
    # DISPLAY RESULTS
    # ========================================================

    print()
    print(
        "============================================================"
    )

    print(
        "TEST COMPLETE"
    )

    print(
        "============================================================"
    )

    print(
        f"Unique places: {len(df)}"
    )

    print(
        f"CSV saved: {output_file}"
    )

    print()
    print(
        "Columns:"
    )

    for number, column in enumerate(
        columns,
        start=1
    ):

        print(
            f"{number}. {column}"
        )

    print()
    print(
        "============================================================"
    )

    print(
        "PREVIEW"
    )

    print(
        "============================================================"
    )

    print(
        df[
            [
                "ID",
                "District",
                "Category",
                "Name",
                "Address",
                "Min Cost",
                "Max Cost",
                "Rating",
                "Reviews"
            ]
        ].to_string(
            index=False
        )
    )

    print()
    print(
        "============================================================"
    )
