import asyncio
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sklearn.cluster import DBSCAN
import numpy as np

from app.core.database import get_db
from app.models.poi import Place

router = APIRouter()


def _fetch_place_image(image_url: str) -> tuple[bytes, str]:
    """Fetch a trusted Google Places image so Flutter Web can display it same-origin."""
    parsed = urlparse(image_url)
    if parsed.scheme != "https" or parsed.hostname != "places.googleapis.com":
        raise HTTPException(status_code=404, detail="Place image is unavailable")

    request = Request(image_url, headers={"User-Agent": "Taralets/1.0"})
    try:
        with urlopen(request, timeout=12) as upstream:
            content_type = upstream.headers.get_content_type()
            if not content_type.startswith("image/"):
                raise HTTPException(status_code=404, detail="Place image is unavailable")
            image = upstream.read(8 * 1024 * 1024 + 1)
            if len(image) > 8 * 1024 * 1024:
                raise HTTPException(status_code=413, detail="Place image is too large")
            return image, content_type
    except HTTPException:
        raise
    except (HTTPError, URLError, TimeoutError, OSError) as exc:
        raise HTTPException(status_code=404, detail="Place image is unavailable") from exc


@router.get("/places/{place_id}/image", response_class=Response)
async def get_place_image(place_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Place).where(Place.id == place_id))
    place = result.scalar_one_or_none()
    image_url = (
        str(getattr(place, "image_url", "") or "").strip()
        if place is not None
        else ""
    )
    if not image_url:
        raise HTTPException(status_code=404, detail="Place image is unavailable")

    image, content_type = await asyncio.to_thread(_fetch_place_image, image_url)
    return Response(
        content=image,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )

@router.get("/places/clusters")
async def get_place_clusters(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Place))
    places = result.scalars().all()
    
    if not places:
        return {"clusters": []}

    coords = np.array([[p.latitude, p.longitude] for p in places])
    coords_radians = np.radians(coords)

    epsilon = 500 / 6371000 
    
    dbscan = DBSCAN(eps=epsilon, min_samples=3, algorithm='ball_tree', metric='haversine')
    labels = dbscan.fit_predict(coords_radians)

    clusters_map = {}
    next_noise_cluster_id = int(labels.max()) + 1 if len(labels) else 0
    for place, label in zip(places, labels):
        cluster_id = int(label)
        if cluster_id == -1:
            # Keep DBSCAN outliers visible as standalone places instead of
            # silently dropping rows from the canonical place dataset.
            cluster_id = next_noise_cluster_id
            next_noise_cluster_id += 1
            
        if cluster_id not in clusters_map:
            clusters_map[cluster_id] = []
        
        # IDINAGDAG ANG MGA SUB-CATEGORIES AT ACCESSIBILITY BOOLEANS
        clusters_map[cluster_id].append({
            "id": place.id,
            "name": place.name,
            "category": getattr(place, 'category', 'Unknown'),
            "sub_category_1": getattr(place, 'sub_category_1', None),
            "sub_category_2": getattr(place, 'sub_category_2', None),
            "sub_category_3": getattr(place, 'sub_category_3', None),
            "lat": place.latitude,
            "lng": place.longitude,
            "address": getattr(place, 'address', None),
            "district": getattr(place, 'district', None),
            "description": getattr(place, 'description', None),
            "rating": float(getattr(place, 'rating', 0.0) or 0.0),
            "reviews": getattr(place, 'reviews', 0),
            "entrance_fee": getattr(place, 'entrance_fee', None),
            "min_cost": float(getattr(place, 'min_cost', 0) or 0),
            "max_cost": float(getattr(place, 'max_cost', 0) or 0),
            "image_url": getattr(place, 'image_url', None),
            "open_time": place.open_time.isoformat() if getattr(place, 'open_time', None) else None,
            "close_time": place.close_time.isoformat() if getattr(place, 'close_time', None) else None,
            "activity_tags": getattr(place, 'activity_tags', []),
            "pet_friendly": getattr(place, 'pet_friendly', False),
            "wheelchair_accessible": getattr(place, 'wheelchair_accessible', False),
            "good_for_children": getattr(place, 'good_for_children', False),
            "is_dot_accredited": getattr(place, 'is_dot_accredited', False)
        })

    response = []
    for cluster_id, places_list in clusters_map.items():
        response.append({
            "cluster_id": cluster_id,
            "places": places_list
        })

    return {"clusters": response}
