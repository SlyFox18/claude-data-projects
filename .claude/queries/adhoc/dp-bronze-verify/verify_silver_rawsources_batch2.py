"""
DP RAW SOURCES BATCH 2 - SILVER VERIFICATION
============================================================================
Independent check of the 10 Silver tables built in this batch. Nine of the
ten should match their bronze shortcut's row count exactly (pure select/
rename, no filtering). WarClaim is the one exception - it applies a real
IS NOT NULL filter, so its Silver count is expected to be LOWER than
bronze by roughly 5,042 rows (10.75% of the table, as of this session -
will drift slightly since the source is live).

Run manually after Brian runs all 10 notebooks (plan Task 13).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name, expect_exact_match)
TABLE_PAIRS = [
    ("TechnicianInvoiceDetail", "Silver_TechnicianInvoiceDetail", True),
    ("TechnicianPunchedDetail", "Silver_TechnicianPunchedDetail", True),
    ("VhStock", "Silver_VhStock", True),
    ("VhTrans", "Silver_VhTrans", True),
    ("WkInvReg", "Silver_WkInvReg", True),
    ("WKMECHWK", "Silver_WkMechWk", True),
    ("WKOTHSUB", "Silver_WkOthSub", True),
    ("WkRoFile", "Silver_WkRoFile", True),
    ("WkVehFl", "Silver_WkVehFl", True),
    ("WarClaim", "Silver_WarClaim", False),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 100)
print(f"{'Bronze':<26} {'Silver':<28} {'Bronze rows':>13} {'Silver rows':>13} {'Result':>10}")
print("=" * 100)

all_ok = True
for bronze_name, silver_name, expect_exact in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    if expect_exact:
        ok = bronze_count == silver_count
        result = "OK" if ok else "MISMATCH"
    else:
        # WarClaim: silver should be strictly less than bronze (real filter applied),
        # and not implausibly smaller (sanity bound - shouldn't drop more than half the table)
        ok = 0 < silver_count < bronze_count and (bronze_count - silver_count) < bronze_count * 0.5
        result = f"OK (-{bronze_count - silver_count:,})" if ok else "UNEXPECTED"
    all_ok = all_ok and ok
    print(f"{bronze_name:<26} {silver_name:<28} {bronze_count:>13,} {silver_count:>13,} {result:>10}")

print("=" * 100)
print(f"All 10 Silver tables verified: {all_ok}")
