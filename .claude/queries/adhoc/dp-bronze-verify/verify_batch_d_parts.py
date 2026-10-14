"""
DP_PRESENTATION - BATCH D VERIFICATION: dim_Parts
============================================================================
Confirms the dim_Parts build landed correctly - a dim with real documented
history (project_dim_parts_dedup_fix.md, project_dim_parts_perf_followup.md,
project_dim_parts_vendorcode_limitation.md). Checks the real issues found
and fixed this batch:
  1. Majority-vote restored to all 5 remaining business filter columns
     (production only does 4, due to a Power Query M-engine performance
     limit that doesn't apply in Spark).
  2. PartNumberKey is a stable xxhash64(PartNumber) hash, not a sequential
     index (avoids the same key-shift bug class already fixed on
     dim_CustomerList's CustomerKey).
  3. PartNumber is normalized (upper+trim) BEFORE grouping, so casing/
     whitespace variants of the same real part are treated as one part
     (production normalizes AFTER its dedup step, silently dropping one
     variant's data for ~81 real parts).
  4. VendorCode DROPPED entirely (2026-09-14, after Brian's Ben conversation
     confirmed the branch-variance interpretation). Confirmed zero real
     usage of dim_Parts.VendorCode anywhere in the report portfolio - the
     real part x branch vendor relationship already exists correctly inside
     Fact_Inventory (reads VendorCode at its own native per-branch grain,
     before any dedup collapse). dim_Parts is 21 real columns now, not 22 -
     corrects the original column-usage-depth audit's "22/22 used" claim,
     which was a bare-string-grep false positive (couldn't distinguish
     dim_Parts.VendorCode from dim_VendorCode.VendorCode or
     Fact_Inventory's own pre-lookup VendorCode).

Run manually after Brian runs Build_Gold_Parts.Notebook.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
pres_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"
staging_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

EXPECTED_COLS = {
    "PartNumberKey", "PartNumber", "Description", "Franchise", "Source", "SLC",
    "DealerGroupCode", "CommodityCode", "QuantityOnHand", "BackOrderQty",
    "StockStatus", "IsAvailable", "InventoryCost", "SellPrice1", "ListPrice",
    "Current12MoSales", "HasRecentSales", "ActivityStatus", "Returnable",
    "IsReturnable", "IsHighValue",
}

print("=" * 80)
print("VERIFY: dim_Parts - column contract (21 columns - VendorCode dropped 2026-09-14)")
print("=" * 80)
cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{pres_base}/dim_Parts') LIMIT 0").df()
col_set = set(cols["column_name"].tolist())
if col_set == EXPECTED_COLS:
    print(f"PASS: {len(EXPECTED_COLS)}-column contract matches exactly (no VendorCode).")
else:
    print(f"Missing: {EXPECTED_COLS - col_set}")
    print(f"Extra: {col_set - EXPECTED_COLS}")
print()

print("=" * 80)
print("VERIFY: row count + uniqueness (PartNumber and PartNumberKey both)")
print("=" * 80)
count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{pres_base}/dim_Parts')").fetchone()[0]
print(f"Total rows: {count:,} (expect 316,365 = 316,364 normalized-distinct real parts + 1 UNKNOWN)")
dup_pn = con.execute(f"""
    SELECT PartNumber, COUNT(*) AS n FROM delta_scan('{pres_base}/dim_Parts')
    GROUP BY PartNumber HAVING COUNT(*) > 1
""").df()
print(f"Duplicate PartNumber rows (expect 0): {len(dup_pn)}")
dup_key = con.execute(f"""
    SELECT PartNumberKey, COUNT(*) AS n FROM delta_scan('{pres_base}/dim_Parts')
    GROUP BY PartNumberKey HAVING COUNT(*) > 1
""").df()
print(f"Duplicate PartNumberKey rows (expect 0): {len(dup_key)}")
print()

print("=" * 80)
print("VERIFY: special UNKNOWN row")
print("=" * 80)
unk = con.execute(f"""
    SELECT * FROM delta_scan('{pres_base}/dim_Parts') WHERE PartNumberKey = -1
""").df()
print(unk.to_string())
print()

print("=" * 80)
print("VERIFY: known Franchise disagreement spot check (majority-vote, not arbitrary row)")
print("=" * 80)
spot = con.execute(f"""
    SELECT PartNumber, Franchise, Source, SLC, DealerGroupCode, CommodityCode
    FROM delta_scan('{pres_base}/dim_Parts')
    WHERE PartNumber IN ('DZ111141', '19M7966', 'Z47990', 'R78055', 'R71387')
    ORDER BY PartNumber
""").df()
print(spot.to_string())
dz = spot[spot["PartNumber"] == "DZ111141"]
if len(dz) and dz.iloc[0]["Franchise"] == "D":
    print("PASS: DZ111141 Franchise = 'D' (the real 19-of-21-row majority, not the old arbitrary pick).")
else:
    print(f"CHECK: DZ111141 Franchise = {dz.iloc[0]['Franchise'] if len(dz) else 'NOT FOUND'} (expected 'D')")
print()

print("=" * 80)
print("INDEPENDENT CROSS-CHECK: recompute majority-vote for all 5 columns via pure SQL")
print("=" * 80)
print("(Same logic as the notebook's majority_vote() helper, written independently in SQL")
print(" against Silver_PartInformation directly - a true cross-check, not just re-reading")
print(" the notebook's own output.)")
for col in ["Franchise", "Source", "SLC", "DealerGroupCode", "CommodityCode"]:
    q = f"""
        WITH normalized AS (
            SELECT UPPER(TRIM(PartNumber)) AS PartNumber,
                   UPPER(TRIM(CAST({col} AS VARCHAR))) AS v
            FROM delta_scan('{staging_base}/Silver_PartInformation')
            WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
              AND {col} IS NOT NULL AND TRIM(CAST({col} AS VARCHAR)) <> ''
        ),
        counts AS (
            SELECT PartNumber, v, COUNT(*) AS VoteCount
            FROM normalized GROUP BY PartNumber, v
        ),
        ranked AS (
            SELECT PartNumber, v,
                   ROW_NUMBER() OVER (PARTITION BY PartNumber ORDER BY VoteCount DESC, v ASC) AS rnk
            FROM counts
        )
        SELECT PartNumber, v AS expected_value FROM ranked WHERE rnk = 1
    """
    expected = con.execute(q).df().set_index("PartNumber")["expected_value"]
    actual = con.execute(f"""
        SELECT PartNumber, {col} AS actual_value FROM delta_scan('{pres_base}/dim_Parts')
        WHERE PartNumberKey <> -1 AND {col} IS NOT NULL
    """).df().set_index("PartNumber")["actual_value"]
    joined = expected.to_frame("expected").join(actual.to_frame("actual"), how="outer")
    mismatches = joined[joined["expected"] != joined["actual"]]
    print(f"{col}: {len(mismatches)} mismatch(es) out of {len(joined):,} compared "
          f"({'PASS' if len(mismatches) == 0 else 'FAIL - investigate'})")
    if len(mismatches):
        print(mismatches.head(10).to_string())
print()

print("=" * 80)
print("VERIFY: VendorCode is NOT present on dim_Parts (dropped 2026-09-14)")
print("=" * 80)
if "VendorCode" not in col_set:
    print("PASS: VendorCode correctly absent from dim_Parts.")
else:
    print("FAIL: VendorCode still present - the drop didn't land, investigate.")
print("(Reference only - real branch-variance count, unaffected by this dim's own build:")
vendor_disagree = con.execute(f"""
    WITH normalized AS (
        SELECT UPPER(TRIM(PartNumber)) AS PartNumber, UPPER(TRIM(CAST(VendorCode AS VARCHAR))) AS v
        FROM delta_scan('{staging_base}/Silver_PartInformation')
        WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
          AND VendorCode IS NOT NULL
    )
    SELECT COUNT(*) FROM (
        SELECT PartNumber FROM normalized GROUP BY PartNumber HAVING COUNT(DISTINCT v) > 1
    )
""").fetchone()[0]
print(f" {vendor_disagree:,} PartNumbers with >1 distinct VendorCode in the raw source - "
      f"this is why VendorCode was dropped rather than majority-voted; the real part x "
      f"branch relationship this represents already lives correctly in Fact_Inventory.)")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
