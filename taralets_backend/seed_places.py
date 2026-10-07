import pandas as pd
import asyncio
from app.core.database import AsyncSessionLocal, engine, Base
from app.models.poi import Place

async def seed_data():
    # 1. I-create ang table sa DB (Maganda kung gagamit ng Alembic, pero for testing pwede ito)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # 2. Basahin ang CSV gamit ang pandas
    # Tiyaking tama ang path papunta sa iyong CSV file
    csv_file = 'sample_places - sample_places.csv.csv'
    
    try:
        df = pd.read_csv(csv_file)
        print(f"Nabasa ang {len(df)} places mula sa CSV.")
        
        async with AsyncSessionLocal() as db:
            for index, row in df.iterrows():
                # Clean up empty (NaN) values
                entrance_fee = float(row['entrance_fee']) if pd.notna(row['entrance_fee']) else 0.0
                avg_visit_mins = int(row['avg_visit_minutes']) if pd.notna(row['avg_visit_minutes']) else 60
                opening_hrs = str(row['opening_hours']) if pd.notna(row['opening_hours']) else "Not specified"
                
                place = Place(
                    name=row['name'],
                    category=row['category'],
                    tags=row['tags'],
                    address=row['address'],
                    lat=row['lat'],
                    lng=row['lng'],
                    opening_hours=opening_hrs,
                    avg_visit_minutes=avg_visit_mins,
                    entrance_fee=entrance_fee,
                    is_dot_accredited=bool(row['is_dot_accredited'])
                )
                db.add(place)
            
            await db.commit()
            print("Success! ")
            
    except Exception as e:
        print(f"May error sa pag-seed: {e}")

if __name__ == "__main__":
    import sys
    
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        
    asyncio.run(seed_data())