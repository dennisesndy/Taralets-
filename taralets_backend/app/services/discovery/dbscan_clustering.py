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
    
    try:
        df = pd.read_csv(csv_path)
    except FileNotFoundError:
        return {"error": f"Can't found dataset in {csv_path}"}

    if 'latitude' not in df.columns or 'longitude' not in df.columns:
        return {"error": "The dataset should have 'latitude' and 'longitude' columns."}

    coords = np.radians(df[['latitude', 'longitude']].values)

    epsilon = (eps_meters / 1000.0) / 6371.0

    db = DBSCAN(eps=epsilon, min_samples=min_pts, algorithm='ball_tree', metric='haversine')
    df['cluster_id'] = db.fit_predict(coords)

    clustered_pois = df[df['cluster_id'] != -1].copy()

    return clustered_pois.to_dict(orient='records')
