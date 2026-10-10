import pandas as pd
import asyncio
from sqlalchemy import select
from app.core.database import AsyncSessionLocal
from app.models.poi import Place

async def seed_places_from_csv(csv_path: str):
    # 1. Basahin ang CSV
    df = pd.read_csv(csv_path)
    
    print("Columns na nabasa sa CSV:", df.columns.tolist())
    
    # 2. Helper functions
    def parse_array_column(val):
        if pd.isna(val) or str(val).strip() == '':
            return []
        return [item.strip() for item in str(val).split(',')]

    def safe_float(val):
        """Kino-convert ang value to float. Kung 'Free' o text, gagawing 0.0"""
        if pd.isna(val):
            return 0.0
        val_str = str(val).strip().lower()
        if val_str in ['free', 'none', 'n/a', '']:
            return 0.0
        try:
            # Pagtanggal ng peso sign o comma kung sakaling meron
            clean_val = val_str.replace('₱', '').replace(',', '').replace('php', '').strip()
            return float(clean_val)
        except ValueError:
            return 0.0

    print(f"Nagsisimula nang i-save ang {len(df)} places sa database (Async Mode)...")
    
    async with AsyncSessionLocal() as db:
        for index, row in df.iterrows():
            master_id_val = str(row.get('Master ID', f'UNKNOWN-{index}'))
            
            if master_id_val.startswith('UNKNOWN'):
                continue
                
            result = await db.execute(select(Place).where(Place.master_id == master_id_val))
            existing_place = result.scalars().first()
            
            if not existing_place:
                new_place = Place(
                    master_id=master_id_val,
                    district_id=str(row.get('District ID', '')),
                    district=str(row.get('District', '')),
                    name=str(row.get('Name', '')),
                    category=str(row.get('Category', '')),
                    description=str(row.get('Description', '')),
                    image_url=str(row.get('Image URL', '')),
                    address=str(row.get('Address', '')),
                    
                    latitude=safe_float(row.get('Latitude')),
                    longitude=safe_float(row.get('Longitude')),
                    
                    activity_tags=parse_array_column(row.get('Activity Tags', '')),
                    dietary_options=parse_array_column(row.get('Dietary Options', '')),
                    
                    # Saluhin natin kung may space o wala yung "Accessibility & Pets"
                    accessibility_pets=parse_array_column(row.get('Accessibility& Pets', row.get('Accessibility & Pets', ''))),
                    
                    # Gamitin ang safe_float para iwas crash sa 'Free'
                    entrance_fee=safe_float(row.get('Entrance Fee')),
                    min_cost=safe_float(row.get('Min Cost')),
                    max_cost=safe_float(row.get('Max Cost')),
                    
                    days_open=str(row.get('Days Open', '')),
                    
                    rating=safe_float(row.get('Rating')),
                    reviews=int(safe_float(row.get('Reviews'))) # float muna bago int para safe
                )
                db.add(new_place)
                
        # I-save (commit) ang lahat sa database
        await db.commit()
        
    print("Tagumpay na naipasok ang dataset sa Neon PostgreSQL!")

if __name__ == "__main__":
    csv_file_path = "testing_places.csv" 
    asyncio.run(seed_places_from_csv(csv_file_path))