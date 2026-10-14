"""
DP BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the DP_Staging.InTrans OneLake shortcut (created in Plan 2, Task 2)
is a complete, accurate zero-copy reference to
JD_EquipRDB_Production_Bronze.InTrans — not a partial or stale copy.

Three checks:
1. Row count and date range match a direct query of the JD Bronze source
2. The specific RO 1985073 spot check (9 rows, matching the printed invoice)
   still resolves correctly through the shortcut — this is the exact case
   that proved JD Bronze doesn't have the original watermark-drop bug
   (see docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md)
3. JD's PL_EquipRDB_To_Fabric_Full pipeline is still refreshing nightly,
   so the shortcut's freshness is being maintained upstream

Run manually — not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"   # DP - Staging - Dev workspace
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"   # DP_Staging lakehouse
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count / date range, JD source vs. DP shortcut ===")
jd_stats = con.execute(f"""
    SELECT COUNT(*) AS RowCount, MIN(Trans_Datetime) AS MinTS, MAX(Trans_Datetime) AS MaxTS
    FROM delta_scan('{jd_base}/InTrans')
""").df()
print("JD Bronze direct:")
print(jd_stats.to_string())

dp_stats = con.execute(f"""
    SELECT COUNT(*) AS RowCount, MIN(Trans_Datetime) AS MinTS, MAX(Trans_Datetime) AS MaxTS
    FROM delta_scan('{dp_base}/InTrans')
""").df()
print("\nDP_Staging shortcut:")
print(dp_stats.to_string())

match = (jd_stats["RowCount"][0] == dp_stats["RowCount"][0]
         and jd_stats["MaxTS"][0] == dp_stats["MaxTS"][0])
print(f"\nRow count and max timestamp match: {match}")

print("\n=== Check 2: RO 1985073 spot check through the shortcut ===")
ro_check = con.execute(f"""
    SELECT BRANCH, FRANCHISE, REF_NO, PART_NO, Trans_Datetime, SALE_VAL
    FROM delta_scan('{dp_base}/InTrans')
    WHERE REF_NO = '1985073'
    ORDER BY Trans_Datetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 through shortcut: {len(ro_check)} (expect 9, matching source)")

print("\n=== Check 3: is PL_EquipRDB_To_Fabric_Full still refreshing nightly? ===")
freshness = con.execute(f"""
    SELECT MAX(Trans_Datetime) AS MaxTS FROM delta_scan('{jd_base}/InTrans')
""").df()
print(freshness.to_string())
print("Compare MaxTS to today's date — should be within the last 1-2 days given the nightly Full reload.")
