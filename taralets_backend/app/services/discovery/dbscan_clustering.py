import pandas as pd
import numpy as np
from sklearn.cluster import DBSCAN
from pathlib import Path

CANONICAL_DATASET = (
    Path(__file__).resolve().parents[3]
    / "Dataset - final_postgres_ready_dataset_sequenced.csv"
)

def get_discovery_clusters(
    csv_path: str | Path = CANONICAL_DATASET,
    eps_meters: float = 500.0,
    min_pts: int = 3
):
    """
    Nagbabasa ng CSV dataset at nag-eexecute ng DBSCAN clustering 
    para sa Location-Based Discovery module.
    """
    
    # 1. I-load ang pinalitang dataset
    try:
        df = pd.read_csv(csv_path)
    except FileNotFoundError:
        return {"error": f"Hindi mahanap ang dataset sa {csv_path}"}

    # Siguraduhing tama ang pangalan ng latitude at longitude columns base sa inyong CSV
    if 'latitude' not in df.columns or 'longitude' not in df.columns:
        return {"error": "Ang dataset ay dapat may 'latitude' at 'longitude' na columns."}

    # 2. Ihanda ang coordinates para sa DBSCAN (kailangan ng radians para sa Haversine metric)
    coords = np.radians(df[['latitude', 'longitude']].values)

    # 3. I-setup ang DBSCAN parameters
    # Ang epsilon ay kinoconvert mula meters papuntang radians (Earth radius ~ 6371 km)
    epsilon = (eps_meters / 1000.0) / 6371.0

    # 4. I-execute ang DBSCAN density clustering sa retrieved POI dataset
    db = DBSCAN(eps=epsilon, min_samples=min_pts, algorithm='ball_tree', metric='haversine')
    df['cluster_id'] = db.fit_predict(coords)

    # 5. I-filter out ang isolated spatial noise (Cluster ID == -1) at tukuyin ang core spatial clusters
    clustered_pois = df[df['cluster_id'] != -1].copy()

    # 6. I-cache at i-return ang density-validated POI cluster hubs para sa interactive map
    return clustered_pois.to_dict(orient='records')
