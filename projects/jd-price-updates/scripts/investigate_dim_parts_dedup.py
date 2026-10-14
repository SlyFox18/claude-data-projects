"""
Verification script for dim_Parts dedup majority-vote fix.

Confirms (against real production data in LH_Master_Data via DuckDB/OneLake,
no Fabric round-trip needed):

1. Majority-vote SQL logic gives the expected (correct) value for the 5 known
   examples (DZ111141, 19M7966, Z47990, R78055, R71387).
2. Quantifies how many distinct PartNumbers in the CURRENT (buggy) dim_Parts
   table disagree with the majority-vote answer, across all 6 business-filter
   columns (Franchise, Source, SLC, DealerGroupCode, CommodityCode, VendorCode).
3. Spot-checks a handful of already-unanimous PartNumbers to confirm the
   majority-vote logic doesn't change anything for parts that were already
   correct.

Run manually - not part of any scheduled pipeline.
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

BUSINESS_COLS = ["Franchise", "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode"]

# ------------------------------------------------------------------
# Step 1: Prove majority-vote SQL logic gives 'D' for the 5 known examples
# ------------------------------------------------------------------
examples = ["DZ111141", "19M7966", "Z47990", "R78055", "R71387"]
examples_sql = ",".join(f"'{p}'" for p in examples)

print("=" * 70)
print("STEP 1: Majority-vote Franchise for 5 known examples")
print("=" * 70)
majority_check = con.execute(f"""
    WITH ranked AS (
        SELECT
            UPPER(TRIM(PartNumber)) AS PartNumber,
            Franchise,
            COUNT(*) AS Cnt,
            ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(PartNumber)) ORDER BY COUNT(*) DESC) AS rn
        FROM delta_scan('{base}/jdis_Part_Information')
        WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
          AND Franchise IS NOT NULL AND TRIM(Franchise) <> ''
          AND UPPER(TRIM(PartNumber)) IN ({examples_sql})
        GROUP BY UPPER(TRIM(PartNumber)), Franchise
    )
    SELECT PartNumber, Franchise AS MajorityFranchise, Cnt AS VoteCount
    FROM ranked WHERE rn = 1
    ORDER BY PartNumber
""").df()
print(majority_check.to_string(index=False))

print()
print("Full vote breakdown for these 5 parts (all distinct Franchise values seen):")
breakdown = con.execute(f"""
    SELECT
        UPPER(TRIM(PartNumber)) AS PartNumber,
        Franchise,
        COUNT(*) AS Cnt
    FROM delta_scan('{base}/jdis_Part_Information')
    WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
      AND Franchise IS NOT NULL AND TRIM(Franchise) <> ''
      AND UPPER(TRIM(PartNumber)) IN ({examples_sql})
    GROUP BY UPPER(TRIM(PartNumber)), Franchise
    ORDER BY PartNumber, Cnt DESC
""").df()
print(breakdown.to_string(index=False))

# ------------------------------------------------------------------
# Step 2: Quantify real impact - how many PartNumbers does the fix change,
# across all 6 business-filter columns, vs current (buggy) dim_Parts
# ------------------------------------------------------------------
print()
print("=" * 70)
print("STEP 2: Count of PartNumbers where current dim_Parts disagrees with majority vote")
print("=" * 70)

total_changed_any = None
per_column_counts = {}

for col in BUSINESS_COLS:
    q = f"""
        WITH ranked AS (
            SELECT
                UPPER(TRIM(PartNumber)) AS PartNumber,
                {col},
                COUNT(*) AS Cnt,
                ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(PartNumber)) ORDER BY COUNT(*) DESC) AS rn
            FROM delta_scan('{base}/jdis_Part_Information')
            WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
              AND {col} IS NOT NULL AND TRIM(CAST({col} AS VARCHAR)) <> ''
            GROUP BY UPPER(TRIM(PartNumber)), {col}
        ),
        majority AS (
            SELECT PartNumber, {col} AS MajorityValue
            FROM ranked WHERE rn = 1
        )
        SELECT COUNT(*) AS DisagreeCount
        FROM delta_scan('{base}/dim_Parts') d
        INNER JOIN majority m ON UPPER(TRIM(d.PartNumber)) = m.PartNumber
        WHERE d.{col} IS NOT NULL AND TRIM(CAST(d.{col} AS VARCHAR)) <> ''
          AND TRIM(CAST(d.{col} AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR))
    """
    result = con.execute(q).fetchone()[0]
    per_column_counts[col] = result
    print(f"  {col:20s}: {result:,} PartNumbers disagree")

# Distinct PartNumbers affected across ANY of the 6 columns
union_q = f"""
    WITH majority_all AS (
        {" UNION ALL ".join(f'''
        SELECT UPPER(TRIM(PartNumber)) AS PartNumber, '{col}' AS ColName, {col} AS MajorityValue,
               ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(PartNumber)) ORDER BY COUNT(*) DESC) AS rn
        FROM delta_scan('{base}/jdis_Part_Information')
        WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
          AND {col} IS NOT NULL AND TRIM(CAST({col} AS VARCHAR)) <> ''
        GROUP BY UPPER(TRIM(PartNumber)), {col}
        ''' for col in BUSINESS_COLS)}
    ),
    majority AS (
        SELECT PartNumber, ColName, MajorityValue FROM majority_all WHERE rn = 1
    )
    SELECT COUNT(DISTINCT d.PartNumber) AS DistinctPartsChanged
    FROM delta_scan('{base}/dim_Parts') d
    INNER JOIN majority m ON UPPER(TRIM(d.PartNumber)) = m.PartNumber
    WHERE (m.ColName = 'Franchise' AND d.Franchise IS NOT NULL AND TRIM(CAST(d.Franchise AS VARCHAR)) <> '' AND TRIM(CAST(d.Franchise AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
       OR (m.ColName = 'Source' AND d.Source IS NOT NULL AND TRIM(CAST(d.Source AS VARCHAR)) <> '' AND TRIM(CAST(d.Source AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
       OR (m.ColName = 'SLC' AND d.SLC IS NOT NULL AND TRIM(CAST(d.SLC AS VARCHAR)) <> '' AND TRIM(CAST(d.SLC AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
       OR (m.ColName = 'DealerGroupCode' AND d.DealerGroupCode IS NOT NULL AND TRIM(CAST(d.DealerGroupCode AS VARCHAR)) <> '' AND TRIM(CAST(d.DealerGroupCode AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
       OR (m.ColName = 'CommodityCode' AND d.CommodityCode IS NOT NULL AND TRIM(CAST(d.CommodityCode AS VARCHAR)) <> '' AND TRIM(CAST(d.CommodityCode AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
       OR (m.ColName = 'VendorCode' AND d.VendorCode IS NOT NULL AND TRIM(CAST(d.VendorCode AS VARCHAR)) <> '' AND TRIM(CAST(d.VendorCode AS VARCHAR)) <> TRIM(CAST(m.MajorityValue AS VARCHAR)))
"""
distinct_changed = con.execute(union_q).fetchone()[0]
print()
print(f"  TOTAL DISTINCT PartNumbers changed by fix (any of the 6 columns): {distinct_changed:,}")

# ------------------------------------------------------------------
# Step 3: Spot-check already-unanimous parts - confirm no regression
# ------------------------------------------------------------------
print()
print("=" * 70)
print("STEP 3: Spot-check already-unanimous PartNumbers (no regression expected)")
print("=" * 70)
unanimous_check = con.execute(f"""
    WITH counts AS (
        SELECT UPPER(TRIM(PartNumber)) AS PartNumber, COUNT(DISTINCT Franchise) AS DistinctFranchiseCount, COUNT(*) AS RowCount
        FROM delta_scan('{base}/jdis_Part_Information')
        WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
          AND Franchise IS NOT NULL AND TRIM(Franchise) <> ''
        GROUP BY UPPER(TRIM(PartNumber))
        HAVING COUNT(DISTINCT Franchise) = 1 AND COUNT(*) > 3
    )
    SELECT PartNumber, RowCount
    FROM counts
    ORDER BY RowCount DESC
    LIMIT 5
""").df()
print("Sample unanimous parts (all rows agree on Franchise):")
print(unanimous_check.to_string(index=False))

if len(unanimous_check) > 0:
    sample_parts = ",".join(f"'{p}'" for p in unanimous_check["PartNumber"].tolist())
    verify_sql = f"""
        WITH ranked AS (
            SELECT
                UPPER(TRIM(PartNumber)) AS PartNumber,
                Franchise,
                COUNT(*) AS Cnt,
                ROW_NUMBER() OVER (PARTITION BY UPPER(TRIM(PartNumber)) ORDER BY COUNT(*) DESC) AS rn
            FROM delta_scan('{base}/jdis_Part_Information')
            WHERE PartNumber IS NOT NULL AND TRIM(PartNumber) <> ''
              AND Franchise IS NOT NULL AND TRIM(Franchise) <> ''
              AND UPPER(TRIM(PartNumber)) IN ({sample_parts})
            GROUP BY UPPER(TRIM(PartNumber)), Franchise
        )
        SELECT PartNumber, Franchise AS MajorityFranchise, Cnt
        FROM ranked WHERE rn = 1
        ORDER BY PartNumber
    """
    verify_df = con.execute(verify_sql).df()
    print()
    print("Majority-vote result for those same parts (should match their single unanimous value):")
    print(verify_df.to_string(index=False))

print()
print("Done.")
