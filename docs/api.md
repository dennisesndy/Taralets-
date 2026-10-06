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

