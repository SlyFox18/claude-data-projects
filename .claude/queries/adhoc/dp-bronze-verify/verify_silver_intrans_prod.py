"""
DP SILVER INTRANS VERIFICATION - PROD TIER
============================================================================
Independent check of Silver_InTrans (DP - Staging - Prod) against the
bronze shortcut it was built from - confirms the Prod silver build didn't
lose or duplicate rows, same checks as the Dev tier's
verify_silver_intrans.py, run independently rather than assumed identical.

Run manually after the Prod Silver notebook confirmed it ran successfully.
============================================================================
"""

import duckdb

DP_STAGING_PROD_WS_ID = "189e5c0a-548a-4feb-93d6-dda9ebbe96c1"
DP_STAGING_PROD_LH_ID = "6713bd45-a4ad-47e6-8bff-1bb0415e9784"
dp_base = f"abfss://{DP_STAGING_PROD_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_PROD_LH_ID}/Tables"

SILVER_INTRANS_TABLE = "Silver_InTrans"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row counts, bronze shortcut vs. silver table (Prod) ===")
bronze_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/InTrans')").df()
silver_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')").df()
print(f"Bronze (InTrans) row count: {bronze_count['cnt'][0]:,}")
print(f"Silver (Silver_InTrans) row count: {silver_count['cnt'][0]:,}")
diff = bronze_count['cnt'][0] - silver_count['cnt'][0]
pct = diff / bronze_count['cnt'][0] * 100
print(f"Difference: {diff:,} rows ({pct:.2f}%) — small (a few %) is expected/correct; large (10%+) means something's wrong.")

print("\n=== Check 2: no duplicate (TransId, TransDatetime) in Prod silver ===")
dupes = con.execute(f"""
    SELECT TransId, TransDatetime, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    GROUP BY TransId, TransDatetime
    HAVING COUNT(*) > 1
""").df()
print(f"Duplicate (TransId, TransDatetime) groups: {len(dupes)} (expect 0)")

print("\n=== Check 3: orphaned rows in Prod silver ===")
orphans = con.execute(f"""
    SELECT COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}') s
    LEFT JOIN delta_scan('{dp_base}/InTrans') b
        ON s.TransId = b.trans_id AND s.TransDatetime = b.Trans_Datetime
    WHERE b.trans_id IS NULL
""").df()
print(f"Orphaned silver rows (no matching bronze row): {orphans['cnt'][0]:,} (expect 0)")

print("\n=== Check 4: RO 1985073 through Prod silver ===")
ro_check = con.execute(f"""
    SELECT Branch, Franchise, RONumber, PartNumber, TransDatetime, SaleValue
    FROM delta_scan('{dp_base}/{SILVER_INTRANS_TABLE}')
    WHERE RONumber = '1985073'
    ORDER BY TransDatetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 in Prod silver: {len(ro_check)} (expect 9)")
