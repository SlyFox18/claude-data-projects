"""
DP RAW SOURCES BATCH 2 - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms each of the 10 new OneLake shortcuts in DP_Staging resolves to the
exact same row count as reading the same table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch here means the shortcut itself
is broken (wrong table selected, stale metadata), not a data problem.

Run manually after Brian creates all 10 shortcuts (plan Task 1).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

TABLES = [
    "TechnicianInvoiceDetail",
    "TechnicianPunchedDetail",
    "VhStock",
    "VhTrans",
    "WkInvReg",
    "WKMECHWK",
    "WKOTHSUB",
    "WkRoFile",
    "WkVehFl",
    "WarClaim",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Table':<26} {'DP_Staging shortcut':>20} {'JD Bronze direct':>20} {'Match':>10}")
print("=" * 90)

all_match = True
for t in TABLES:
    dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{t}')").fetchone()[0]
    jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/{t}')").fetchone()[0]
    match = dp_count == jd_count
    all_match = all_match and match
    print(f"{t:<26} {dp_count:>20,} {jd_count:>20,} {'OK' if match else 'MISMATCH':>10}")

print("=" * 90)
print(f"All 10 shortcuts match their JD Bronze source exactly: {all_match}")
