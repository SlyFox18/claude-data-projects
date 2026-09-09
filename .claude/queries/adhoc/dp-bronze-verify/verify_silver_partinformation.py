"""
DP SILVER PARTINFORMATION VERIFICATION
============================================================================
Independent check of Silver_PartInformation (built by
Build_Silver_PartInformation.Notebook) - confirms the combined row count
equals the sum of the two bronze tiers exactly (no loss or duplication
across the union), and that ActivityTier classification is internally
consistent with the underlying QuantityOnHand/sales columns.

Run manually after the notebook confirmed it ran successfully.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: combined row count matches the sum of the two bronze tiers exactly ===")
active_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Active')").fetchone()[0]
dead_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Dead')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_PartInformation')").fetchone()[0]
print(f"Bronze Active: {active_count:,}")
print(f"Bronze Dead: {dead_count:,}")
print(f"Bronze sum: {active_count + dead_count:,}")
print(f"Silver combined: {silver_count:,}")
print(f"Match: {silver_count == active_count + dead_count}")

print("\n=== Check 2: ActivityTier breakdown ===")
breakdown = con.execute(f"""
    SELECT ActivityTier, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/Silver_PartInformation')
    GROUP BY ActivityTier
    ORDER BY ActivityTier
""").df()
print(breakdown.to_string())

print("\n=== Check 3: ActivityTier is internally consistent with the underlying data ===")
inconsistent = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_PartInformation')
    WHERE (ActivityTier = 'Dead' AND NOT (
              (QuantityOnHand = 0 OR QuantityOnHand IS NULL)
              AND (Current12MoSales IS NULL OR Current12MoSales = 0)
              AND (Previous12MoSales IS NULL OR Previous12MoSales = 0)
          ))
       OR (ActivityTier = 'Active' AND (
              (QuantityOnHand = 0 OR QuantityOnHand IS NULL)
              AND (Current12MoSales IS NULL OR Current12MoSales = 0)
              AND (Previous12MoSales IS NULL OR Previous12MoSales = 0)
          ))
""").fetchone()[0]
print(f"Rows where ActivityTier contradicts the underlying activity data (expect 0): {inconsistent}")
