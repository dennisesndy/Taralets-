import pandas as pd

# I-load ang iyong cleaned CSV
df = pd.read_csv("Dataset - final_postgres_ready_dataset.csv")

# Gumawa ng bagong sequence na may format na MNL-XXXXX
# Magsisimula sa 1 hanggang sa kabuuang bilang ng rows
df['master_id'] = [f"MNL-{i:05d}" for i in range(1, len(df) + 1)]

# I-save bilang bagong CSV file
df.to_csv("Dataset - final_postgres_ready_dataset_sequenced.csv", index=False)
print("Tapos na! Sunod-sunod na ulit ang mga master_id.")