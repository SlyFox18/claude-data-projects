"""
Verifies the Fact_JDNationalChangeReport_Enriched dim_Parts join/enrichment
logic against real production data via DuckDB + OneLake delta_scan, BEFORE
the equivalent Power Query M logic is written. Confirms:
  1. Row count is unchanged from the raw table (this fact doesn't
     regrain/dedup -- unlike Fact_PriceUpdate_Enriched).
  2. IsCarriedLocally is mostly False (most national Deere parts aren't
     carried at South Plains) but genuinely True for at least some rows
     (confirming the join actually finds real matches, not silently
     failing entirely).

Run manually -- not part of any scheduled pipeline.
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

raw_row_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Raw_JDNationalChangeReport_History')
""").fetchone()[0]

carried_check = con.execute(f"""
    SELECT
        d.PartNumber IS NOT NULL AS IsCarriedLocally,
        COUNT(*) AS RowCount
    FROM delta_scan('{base}/Raw_JDNationalChangeReport_History') r
    LEFT JOIN delta_scan('{base}/dim_Parts') d
        ON UPPER(TRIM(r.PartNumber)) = d.PartNumber
    GROUP BY d.PartNumber IS NOT NULL
    ORDER BY IsCarriedLocally
""").fetchall()

joined_row_count = sum(row[1] for row in carried_check)

print(f"1. ROW COUNT: raw={raw_row_count:,}  joined={joined_row_count:,}")
print("   Expect these to be EQUAL -- this fact doesn't regrain, only enriches.")

print(f"\n2. IsCarriedLocally DISTRIBUTION:")
for row in carried_check:
    print(f"   IsCarriedLocally={row[0]}  RowCount={row[1]:,}")
print("   Expect the majority to be False (most national parts aren't carried "
      "locally), but at least some True rows confirming the join actually "
      "finds real matches, not silently failing entirely.")
