"""
DP BRONZE SHORTCUT VERIFICATION - PROD TIER
============================================================================
Confirms the DP - Staging - Prod / DP_Staging.InTrans OneLake shortcut
(created in this plan's Task 2) is a complete, accurate zero-copy reference
to JD_EquipRDB_Production_Bronze.InTrans - not a partial or stale copy.

Same three checks as the Dev tier's verify_shortcut.py (Plan 2), run
independently against the Prod shortcut rather than assumed identical
because it came from the same source - this is a separate shortcut object
and needs its own proof.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

DP_STAGING_PROD_WS_ID = "189e5c0a-548a-4feb-93d6-dda9ebbe96c1"   # DP - Staging - Prod workspace
DP_STAGING_PROD_LH_ID = "6713bd45-a4ad-47e6-8bff-1bb0415e9784"   # DP_Staging Prod lakehouse
dp_base = f"abfss://{DP_STAGING_PROD_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_PROD_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count / date range, JD source vs. Prod DP shortcut ===")
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
print("\nDP_Staging (Prod) shortcut:")
print(dp_stats.to_string())

match = (jd_stats["RowCount"][0] == dp_stats["RowCount"][0]
         and jd_stats["MaxTS"][0] == dp_stats["MaxTS"][0])
print(f"\nRow count and max timestamp match: {match}")

print("\n=== Check 2: RO 1985073 spot check through the Prod shortcut ===")
ro_check = con.execute(f"""
    SELECT BRANCH, FRANCHISE, REF_NO, PART_NO, Trans_Datetime, SALE_VAL
    FROM delta_scan('{dp_base}/InTrans')
    WHERE REF_NO = '1985073'
    ORDER BY Trans_Datetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 through Prod shortcut: {len(ro_check)} (expect 9, matching source)")
