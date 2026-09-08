"""
DP SILVER INTRANS VERIFICATION
============================================================================
Independent check of Silver_InTrans (built by Build_Silver_InTrans.Notebook,
Plan 3) against the bronze shortcut it was built from — confirms the silver
build didn't lose or duplicate rows, and that RO 1985073 (the case that
proved the original bug) still resolves correctly one layer downstream.

Corrected 2026-09-08 to check (TransId, TransDatetime) duplicates, not
TransId alone — TransId is reused by the source system for unrelated
transactions (see project memory project_intrans_incremental_dedup_2026-08-11
and the design spec), so a TransId-only duplicate check is expected to find
millions of "duplicates" that are actually correct, distinct rows.

Also checks for orphaned rows: any row in Silver_InTrans whose
(TransId, TransDatetime) doesn't exist in the bronze shortcut at all would
mean stale data survived from a bad prior build — a direct way to confirm
the current state is clean regardless of exactly how it was built.

Run manually after Task 2 confirms the notebook ran successfully.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"   # DP - Staging - Dev workspace
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"   # DP_Staging lakehouse
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# NOTE: the physical table is "silver_intrans" (lowercase) on disk, not
# "Silver_InTrans" as named in the notebook's spark.sql/saveAsTable calls.
# Fabric's saveAsTable() lowercases the physical OneLake folder name
# regardless of the case passed in code (confirmed previously in
# feedback_fabric_saveastable_casing.md — FreightCalculator, MD Invoices
# snapshot). Spark's own catalog resolves the name case-insensitively so
# the notebook runs fine, but anything reading the direct OneLake path
# (like this script, or a future TMDL semantic model partition) must use
# the lowercase physical name or it fails with a delta-kernel "No files
# in log segment" error that looks like a missing/broken table but isn't.
SILVER_INTRANS_TABLE = "silver_intrans"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row counts, bronze shortcut vs. silver table ===")
bronze_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/InTrans')").df()
silver_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')").df()
print(f"Bronze (InTrans) row count: {bronze_count['cnt'][0]:,}")
print(f"Silver (Silver_InTrans) row count: {silver_count['cnt'][0]:,}")
diff = bronze_count['cnt'][0] - silver_count['cnt'][0]
pct = diff / bronze_count['cnt'][0] * 100
print(f"Difference: {diff:,} rows ({pct:.2f}%) — small (a few %) is expected/correct (true exact")
print("duplicates + rare genuine same-key corrections collapsed); large (10%+) means the key is still wrong.")

print("\n=== Check 2: no duplicate (TransId, TransDatetime) in silver ===")
dupes = con.execute(f"""
    SELECT TransId, TransDatetime, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    GROUP BY TransId, TransDatetime
    HAVING COUNT(*) > 1
""").df()
print(f"Duplicate (TransId, TransDatetime) groups: {len(dupes)} (expect 0)")

print("\n=== Check 3: orphaned rows — anything in silver with no match in bronze? ===")
orphans = con.execute(f"""
    SELECT COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}') s
    LEFT JOIN delta_scan('{dp_base}/InTrans') b
        ON s.TransId = b.trans_id AND s.TransDatetime = b.Trans_Datetime
    WHERE b.trans_id IS NULL
""").df()
print(f"Orphaned silver rows (no matching bronze row): {orphans['cnt'][0]:,} (expect 0)")
print("(A non-zero count here would mean stale data survived from a prior bad build.)")

print("\n=== Check 4: RO 1985073 through silver ===")
ro_check = con.execute(f"""
    SELECT Branch, Franchise, RONumber, PartNumber, TransDatetime, SaleValue
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    WHERE RONumber = '1985073'
    ORDER BY TransDatetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 in silver: {len(ro_check)} (expect 9)")
