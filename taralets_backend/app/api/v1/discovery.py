import asyncio
import time
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

_CLUSTER_CACHE_SECONDS = 300
_cluster_cache: dict | None = None
_cluster_cache_expires_at = 0.0
_cluster_cache_lock = asyncio.Lock()


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
    global _cluster_cache, _cluster_cache_expires_at

    async with _cluster_cache_lock:
        now = time.monotonic()
        if _cluster_cache is not None and now < _cluster_cache_expires_at:
            return _cluster_cache

        result = await db.execute(select(Place))
        places = result.scalars().all()

        if not places:
            _cluster_cache = {"clusters": []}
            _cluster_cache_expires_at = now + _CLUSTER_CACHE_SECONDS
            return _cluster_cache

        coords = np.array([[p.latitude, p.longitude] for p in places])
        coords_radians = np.radians(coords)
        epsilon = 500 / 6371000
        dbscan = DBSCAN(
            eps=epsilon,
            min_samples=3,
            algorithm="ball_tree",
            metric="haversine",
        )
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

            clusters_map.setdefault(cluster_id, []).append(
                {
                    "id": place.id,
                    "name": place.name,
                    "category": getattr(place, "category", "Unknown"),
                    "sub_category_1": getattr(place, "sub_category_1", None),
                    "sub_category_2": getattr(place, "sub_category_2", None),
                    "sub_category_3": getattr(place, "sub_category_3", None),
                    "lat": place.latitude,
                    "lng": place.longitude,
                    "address": getattr(place, "address", None),
                    "district": getattr(place, "district", None),
                    "description": getattr(place, "description", None),
                    "rating": float(getattr(place, "rating", 0.0) or 0.0),
                    "reviews": getattr(place, "reviews", 0),
                    "entrance_fee": getattr(place, "entrance_fee", None),
                    "min_cost": float(getattr(place, "min_cost", 0) or 0),
                    "max_cost": float(getattr(place, "max_cost", 0) or 0),
                    "image_url": getattr(place, "image_url", None),
                    "open_time": (
                        place.open_time.isoformat()
                        if getattr(place, "open_time", None)
                        else None
                    ),
                    "close_time": (
                        place.close_time.isoformat()
                        if getattr(place, "close_time", None)
                        else None
                    ),
                    "activity_tags": getattr(place, "activity_tags", []),
                    "pet_friendly": getattr(place, "pet_friendly", False),
                    "wheelchair_accessible": getattr(
                        place, "wheelchair_accessible", False
                    ),
                    "good_for_children": getattr(
                        place, "good_for_children", False
                    ),
                    "is_dot_accredited": getattr(place, "is_dot_accredited", False),
                }
            )

        _cluster_cache = {
            "clusters": [
                {"cluster_id": cluster_id, "places": cluster_places}
                for cluster_id, cluster_places in clusters_map.items()
            ]
        }
        _cluster_cache_expires_at = time.monotonic() + _CLUSTER_CACHE_SECONDS
        return _cluster_cache
