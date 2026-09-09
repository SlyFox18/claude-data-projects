"""
DP BRONZE SHORTCUT VERIFICATION - GlTrans
============================================================================
Confirms the DP_Staging.GlTrans OneLake shortcut (created in the Parts
Adjustments migration plan's Task 2) is a complete, accurate zero-copy
reference to JD_EquipRDB_Production_Bronze.GlTrans - not a partial or
stale copy.

Unlike InTrans, GlTrans's current LH_Master_Data ingestion (df_GlTrans_Raw.
Dataflow) is a small, fully-filtered, FULL REFRESH pull (DEPT=30, ACCT=480,
since 2023-01-01) via a direct ODBC SQL query - not an incremental/watermark
pipeline, so it doesn't carry the same class of bug InTrans_Incremental had.
This check still confirms the shortcut itself is complete and current.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"   # DP - Staging - Dev workspace
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"   # DP_Staging Dev lakehouse
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count, JD source vs. DP shortcut ===")
jd_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{jd_base}/GlTrans')").df()
dp_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/GlTrans')").df()
print(f"JD Bronze direct: {jd_count['cnt'][0]:,}")
print(f"DP_Staging shortcut: {dp_count['cnt'][0]:,}")
print(f"Match: {jd_count['cnt'][0] == dp_count['cnt'][0]}")

print("\n=== Check 2: sample of Parts Adjustments-scoped rows through the shortcut ===")
sample = con.execute(f"""
    SELECT trans_id, DOC_REF, SUB_ACCT, GLTRANS_DATE, BRANCH
    FROM delta_scan('{dp_base}/GlTrans')
    WHERE DEPT = 30 AND ACCT = 480 AND GLTRANS_DATE >= '2023-01-01'
    ORDER BY GLTRANS_DATE DESC
    LIMIT 5
""").df()
print(sample.to_string())

scoped_count = con.execute(f"""
    SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/GlTrans')
    WHERE DEPT = 30 AND ACCT = 480 AND GLTRANS_DATE >= '2023-01-01'
""").fetchone()[0]
print(f"\nRows found in Parts-Adjustments scope (DEPT=30, ACCT=480, since 2023-01-01): {scoped_count:,}")
