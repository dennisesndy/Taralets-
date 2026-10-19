from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sklearn.cluster import DBSCAN
import numpy as np

from app.core.database import get_db
from app.models.poi import Place

router = APIRouter()

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
    for place, label in zip(places, labels):
        cluster_id = int(label)
        
        if cluster_id == -1:
            continue
            
        if cluster_id not in clusters_map:
            clusters_map[cluster_id] = []
        
        # NGAYON, ipinapasa na natin ang buong details (Address, Description, Reviews, etc.)
        clusters_map[cluster_id].append({
            "id": place.id,
            "name": place.name,
            "category": getattr(place, 'category', 'Unknown'),
            "lat": place.latitude,
            "lng": place.longitude,
            "address": getattr(place, 'address', None),
            "district": getattr(place, 'district', None),
            "description": getattr(place, 'description', None),
            "rating": float(getattr(place, 'rating', 0.0) or 0.0),
            "reviews": getattr(place, 'reviews', 0),
            "entrance_fee": getattr(place, 'entrance_fee', None),
            "image_url": getattr(place, 'image_url', None),
            "open_time": place.open_time.isoformat() if getattr(place, 'open_time', None) else None,
            "close_time": place.close_time.isoformat() if getattr(place, 'close_time', None) else None,
            "activity_tags": getattr(place, 'activity_tags', []),
            "is_dot_accredited": getattr(place, 'is_dot_accredited', False)
        })

    response = []
    for cluster_id, places_list in clusters_map.items():
        response.append({
            "cluster_id": cluster_id,
            "places": places_list
        })

    return {"clusters": response}