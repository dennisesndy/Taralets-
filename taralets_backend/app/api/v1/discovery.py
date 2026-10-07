from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sklearn.cluster import DBSCAN
import numpy as np

# Siguraduhing tama ang import paths depende sa setup niyo
from app.core.database import get_db
from app.models.poi import Place

router = APIRouter()

@router.get("/places/clusters")
async def get_place_clusters(db: AsyncSession = Depends(get_db)):
    # 1. Kunin lahat ng places mula sa database
    result = await db.execute(select(Place))
    places = result.scalars().all()
    
    if not places:
        return {"clusters": []}

    # 2. Kunin ang coordinates at i-convert sa radians (kailangan ito ng haversine formula)
    coords = np.array([[p.lat, p.lng] for p in places])
    coords_radians = np.radians(coords)

    # 3. I-setup ang DBSCAN
    # Halimbawa: 500 meters ang radius. Ang radius ng Earth ay ~6371000 meters.
    epsilon = 500 / 6371000 
    dbscan = DBSCAN(eps=epsilon, min_samples=2, algorithm='ball_tree', metric='haversine')
    labels = dbscan.fit_predict(coords_radians)

    # 4. I-group ang mga lugar base sa kanilang cluster ID
    # Note: Ang label na '-1' ay ibig sabihin "outlier" (walang malapit na ibang lugar)
    clusters_map = {}
    for place, label in zip(places, labels):
        cluster_id = int(label)
        if cluster_id not in clusters_map:
            clusters_map[cluster_id] = []
        
        clusters_map[cluster_id].append({
            "id": place.id,
            "name": place.name,
            "category": place.category,
            "lat": place.lat,
            "lng": place.lng,
            "is_dot_accredited": place.is_dot_accredited
        })

    # 5. I-format ang JSON response
    response = []
    for cluster_id, places_list in clusters_map.items():
        response.append({
            "cluster_id": cluster_id,
            "is_outlier": cluster_id == -1,
            "places": places_list
        })

    return {"clusters": response}