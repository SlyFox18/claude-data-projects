"""
PARTS LOOKUP STATIC-FILE PROTOTYPE - EXTRACT
============================================================================
Pulls InMaster_PartsLookup_Raw from the LH_Master_Data lakehouse via DuckDB
over OneLake (delta_scan). Authenticates via a dedicated service principal
(see config.py / .env) rather than an interactive az/fab CLI login, so this
can run unattended on a schedule.

Requires .env to be populated (see .env.example and Task 3 of
docs/superpowers/plans/2026-08-14-parts-lookup-refresh-pipeline.md).
============================================================================
"""

import time

import duckdb

import config

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"  # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"  # LH_Master_Data lakehouse
BASE = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"
OUT_PATH = "partslookup_extract.parquet"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute(
    f"""
    CREATE SECRET (
        TYPE azure,
        PROVIDER service_principal,
        TENANT_ID '{config.TENANT_ID}',
        CLIENT_ID '{config.CLIENT_ID}',
        CLIENT_SECRET '{config.CLIENT_SECRET}'
    );
    """
)

start = time.time()
df = con.execute(
    f"""
    SELECT
        PartNumber, Branch, Franchise, Description, VendorCode,
        Bin, BinQty, OnOrder, SellPrice1, SuperTo, SuperFrom, Comments
    FROM delta_scan('{BASE}/InMaster_PartsLookup_Raw')
    """
).df()
elapsed = time.time() - start

df.to_parquet(OUT_PATH, index=False)

print(f"Extracted {len(df):,} rows in {elapsed:.1f} sec")
print(f"Saved to {OUT_PATH}")
