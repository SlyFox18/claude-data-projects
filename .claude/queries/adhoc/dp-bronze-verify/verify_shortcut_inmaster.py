"""
Verify the DP_Staging InMaster shortcut matches JD_EquipRDB_Production_Bronze's
InMaster table exactly (row count + schema) - zero-CU shortcut, so this should
always match unless the shortcut is misconfigured.
"""
import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"

dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY SHORTCUT: InMaster")
print("=" * 80)

jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/InMaster')").fetchone()[0]
dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InMaster')").fetchone()[0]

print(f"JD Bronze InMaster row count: {jd_count:,}")
print(f"DP_Staging InMaster (shortcut) row count: {dp_count:,}")

if jd_count == dp_count:
    print("PASS: row counts match exactly.")
else:
    print(f"FAIL: row counts differ by {abs(jd_count - dp_count):,} - "
          f"source is live and may have drifted between reads, but investigate if the gap is large.")

jd_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{jd_base}/InMaster') LIMIT 0").df()
dp_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/InMaster') LIMIT 0").df()

jd_col_set = set(jd_cols["column_name"].tolist())
dp_col_set = set(dp_cols["column_name"].tolist())

print(f"\nJD Bronze columns: {len(jd_col_set)}")
print(f"DP_Staging columns: {len(dp_col_set)}")

if jd_col_set == dp_col_set:
    print("PASS: schema matches exactly (shortcut, expected).")
else:
    missing = jd_col_set - dp_col_set
    extra = dp_col_set - jd_col_set
    if missing:
        print(f"Missing in DP_Staging: {missing}")
    if extra:
        print(f"Extra in DP_Staging: {extra}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
