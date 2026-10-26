# Taralets! API Documentation v1

Base URL: `http://localhost:8000/api/v1`

---

## 1. Authentication & Users

### POST `/auth/register`
* **Description:** register new user account.
* **Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "full_name": "Dennise Sinday",
  "is_discount_eligible": false
}
{
  "id": "<DYNAMIC_USER_UUID>",
  "email": "user@example.com",
  "full_name": "Dennise Sinday",
  "is_discount_eligible": false
}
{
  "email": "user@example.com",
  "password": "password123"
}
{
  "access_token": "<JWT_BEARER_TOKEN>",
  "token_type": "bearer"
}
[
  {
    "id": "<DYNAMIC_PLACE_UUID>",
    "name": "Rizal Park",
    "description": "Historical urban park in Manila.",
    "category": "Historical",
    "latitude": 14.5818,
    "longitude": 120.9770,
    "rating": 4.5,
    "approx_budget": 0.0
  }
]
{
  "title": "Intramuros Tour",
  "target_arrival_time": "2026-10-15T10:00:00Z",
  "destination_place_id": "<DYNAMIC_PLACE_UUID>"
}
{
  "id": "<DYNAMIC_TRIP_UUID>",
  "title": "Intramuros Tour",
  "target_arrival_time": "2026-10-15T10:00:00Z",
  "destination_place_id": "<DYNAMIC_PLACE_UUID>",
  "status": "PLANNING"
}
{
  "user_id": "<DYNAMIC_USER_UUID>",
  "origin_latitude": 14.6091,
  "origin_longitude": 121.0223
}
{
  "id": "<DYNAMIC_MEMBER_UUID>",
  "trip_id": "<DYNAMIC_TRIP_UUID>",
  "user_id": "<DYNAMIC_USER_UUID>",
  "required_departure_time": "2026-10-15T09:15:00Z",
  "status": "WAITING_DEPARTURE",
  "priority_category": "Far"
}
{
  "categories": ["Historical", "Food"],
  "budget_max": 500.0
}
{
  "trip_id": "<DYNAMIC_TRIP_UUID>",
  "itinerary_items": [
    {
      "id": "<DYNAMIC_ITINERARY_ITEM_UUID>",
      "place": {
        "id": "<DYNAMIC_PLACE_UUID>",
        "name": "Rizal Park",
        "category": "Historical",
        "latitude": 14.5818,
        "longitude": 120.9770,
        "rating": 4.5,
        "approx_budget": 0.0
      },
      "time_slot": "10:00 AM - 11:30 AM",
      "duration_minutes": 90,
      "sequence_order": 1
    }
  ]
}
```

---

## 2. Trip Itinerary

### POST `/trips/{trip_id}/itinerary/generate`
* **Description:** generate a stateless itinerary from the trip's real members, preferences, and selected place IDs.
* **Auth:** Bearer token required. The caller must be a member of the trip.
* **Request Body:**
```json
{
  "place_ids": ["MNL-00595", "MNL-00098"],
  "date": "2026-10-26",
  "start_time": "09:00"
}
```
* **Response:**
```json
{
  "status": "success",
  "data": {
    "trip_id": "<TRIP_ID>",
    "title": "Intramuros Tour",
    "date_label": "Mon, Oct 26",
    "status": "review",
    "pace": "Moderate",
    "group_preferences": ["Museums", "Food", "₱1,000 / person"],
    "members": [
      {
        "member_id": "<MEMBER_ID>",
        "user_id": "<USER_ID>",
        "username": "aig",
        "name": "Aig Lopez",
        "is_leader": true,
        "is_current_user": true
      }
    ],
    "stops": [
      {
        "sequence": 1,
        "id": 123,
        "master_id": "MNL-00595",
        "name": "Test Museum",
        "category": "Museums",
        "area": "Manila",
        "start_time": "10:00",
        "end_time": "11:15",
        "duration_minutes": 75,
        "travel_minutes": 12,
        "travel_cost": 8,
        "travel_distance_km": 0.53,
        "budget": 0,
        "group_score": 0.91,
        "member_scores": [0.91],
        "open_time": "10:00",
        "close_time": "17:00",
        "days_open": ["Monday"],
        "feasible": true,
        "warning": null
      }
    ],
    "summary": {
      "total_stops": 1,
      "total_duration_minutes": 75,
      "total_travel_minutes": 12,
      "total_travel_cost": 8,
      "total_budget": 0,
      "total_distance_km": 0.53,
      "start_time": "10:00",
      "end_time": "11:15",
      "span_minutes": 75
    },
    "warnings": [],
    "algorithm": "group_acs"
  }
}
```
* **Notes:**
  * This endpoint is stateless and does not write itinerary rows.
  * `start_time` and `date` are optional. When omitted, the trip's `arrival_target` and `date` are used.
  * Opening hours are checked against `open_time`, `close_time`, and `days_open`; infeasible stops are marked with `feasible: false` and a `warning`.

