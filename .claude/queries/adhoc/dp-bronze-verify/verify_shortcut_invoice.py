"""
DP INVOICE - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the new Invoice OneLake shortcut in DP_Staging resolves to the
exact same row count as reading the table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch means the shortcut itself is
broken (wrong table selected, stale metadata), not a data problem.

Run manually after Brian creates the shortcut.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Invoice')").fetchone()[0]
jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/Invoice')").fetchone()[0]

print(f"DP_Staging shortcut row count:  {dp_count:,}")
print(f"JD Bronze direct row count:     {jd_count:,}")
print(f"Match: {dp_count == jd_count}")
