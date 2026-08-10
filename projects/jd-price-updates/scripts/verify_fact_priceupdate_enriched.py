"""
Verifies the Fact_PriceUpdate_Enriched grouping/dedup logic against real
production data via DuckDB + OneLake delta_scan, BEFORE the equivalent
Power Query M logic is written. Confirms:
  1. Collapsing Raw_PriceUpdate_History from Branch+PartNumber+EffectiveDate
     grain to PartNumber+EffectiveDate grain produces a meaningfully smaller
     row count.
  2. AffectedBranchCount (count of distinct rolled-up Branch values per
     PartNumber+EffectiveDate group) matches a real, manually-confirmed
     example: PartNumber 57M11134 on EffectiveDate 2026-08-03 was
     confirmed (via the Fabric table preview, 2026-08-10) to span exactly
     15 branches. NOTE: if this script is run well after 2026-08-10, this
     specific historical row's AffectedBranchCount should still read 15 --
     it's a fixed historical price event, not something that grows over
     time. If it does NOT read 15, investigate before proceeding --
     that's a signal the grouping logic doesn't match what was manually
     observed in Fabric.
  3. HasBranchPriceDisagreement (branches disagreeing on price fields for
     the same PartNumber+EffectiveDate) fires rarely/never, per the raw
     table's own documented assumption that branch doesn't affect price.
  4. Franchise is consistently 'D' both within Raw_PriceUpdate_History
     itself (across every branch row for a given part+date) and against
     dim_Parts' own Franchise column for the same PartNumber.

Run manually -- not part of any scheduled pipeline. This script's job is
finished once its output has been reviewed; it does not need to be kept
running long-term (though there's no harm leaving it in the repo as a
reference for how the M query's logic was validated).
"""

import duckdb

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# NOTE: the real Raw_PriceUpdate_History table (verified via DESCRIBE against
# production, 2026-08-10) has no HasTypeConversionIssue column -- the actual
# columns are Branch, PartNumber, EffectiveDate, Franchise, PartDescription,
# Category, the price/diff fields, BinLocation, OnHandQty, UpdateCode,
# SourceFileName, SourceFileBranch, SourceFileDate, BranchMismatchFlag,
# IngestedAt. HasTypeConversionIssue was dropped from this script accordingly;
# it isn't referenced by any of the four checks below anyway.
con.execute(f"""
    CREATE OR REPLACE TEMP VIEW normalized AS
    SELECT
        UPPER(TRIM(PartNumber)) AS PartNumber,
        EffectiveDate,
        Branch,
        Franchise,
        Category,
        ManufacturerListPrice, DealerListPrice, ListPriceChangePercent,
        ManufacturerReplacePrice, DealerReplacePrice, ManufacturerSellPrice1,
        DealerSellPrice1, SellPriceOld, CostDiff, ListDiff, SellPrice1Diff,
        UpdateCode
    FROM delta_scan('{base}/Raw_PriceUpdate_History')
""")

raw_row_count = con.execute("SELECT COUNT(*) FROM normalized").fetchone()[0]

con.execute("""
    CREATE OR REPLACE TEMP VIEW grouped AS
    SELECT
        PartNumber,
        EffectiveDate,
        COUNT(DISTINCT Branch) AS AffectedBranchCount,
        (COUNT(DISTINCT ManufacturerListPrice) > 1
            OR COUNT(DISTINCT DealerListPrice) > 1
            OR COUNT(DISTINCT ListPriceChangePercent) > 1
            OR COUNT(DISTINCT ManufacturerReplacePrice) > 1
            OR COUNT(DISTINCT DealerReplacePrice) > 1
            OR COUNT(DISTINCT ManufacturerSellPrice1) > 1
            OR COUNT(DISTINCT DealerSellPrice1) > 1
            OR COUNT(DISTINCT SellPriceOld) > 1
            OR COUNT(DISTINCT CostDiff) > 1
            OR COUNT(DISTINCT ListDiff) > 1
            OR COUNT(DISTINCT SellPrice1Diff) > 1
            OR COUNT(DISTINCT UpdateCode) > 1) AS HasBranchPriceDisagreement,
        COUNT(DISTINCT Franchise) AS DistinctFranchiseCountWithinGroup
    FROM normalized
    GROUP BY PartNumber, EffectiveDate
""")

grouped_row_count = con.execute("SELECT COUNT(*) FROM grouped").fetchone()[0]

print(f"1. ROW COUNT: raw={raw_row_count:,}  grouped={grouped_row_count:,}  "
      f"reduction={(1 - grouped_row_count / raw_row_count):.1%}")
print("   Expect grouped to be meaningfully smaller than raw (branches genuinely fan out).")

sample = con.execute("""
    SELECT PartNumber, EffectiveDate, AffectedBranchCount, HasBranchPriceDisagreement
    FROM grouped
    WHERE PartNumber = '57M11134' AND EffectiveDate = DATE '2026-08-03'
""").fetchall()
print(f"\n2. KNOWN EXAMPLE (57M11134 / 2026-08-03): {sample}")
print("   Expect AffectedBranchCount = 15, HasBranchPriceDisagreement = False.")

disagreement = con.execute("""
    SELECT SUM(CASE WHEN HasBranchPriceDisagreement THEN 1 ELSE 0 END) AS DisagreementCount,
           COUNT(*) AS TotalGroups
    FROM grouped
""").fetchone()
print(f"\n3. DISAGREEMENT CHECK: {disagreement[0]:,} of {disagreement[1]:,} groups "
      f"({disagreement[0] / disagreement[1]:.4%}) have HasBranchPriceDisagreement = True.")
print("   Expect this to be zero or very close to zero.")

franchise_check = con.execute(f"""
    SELECT r.Franchise AS RawFranchise, d.Franchise AS DimPartsFranchise, COUNT(*) AS RowCount
    FROM delta_scan('{base}/Raw_PriceUpdate_History') r
    LEFT JOIN delta_scan('{base}/dim_Parts') d
        ON UPPER(TRIM(r.PartNumber)) = d.PartNumber
    GROUP BY r.Franchise, d.Franchise
    ORDER BY RowCount DESC
""").fetchall()
print(f"\n4. FRANCHISE CONSISTENCY CHECK (raw vs dim_Parts):")
for row in franchise_check:
    print(f"   RawFranchise={row[0]!r}  DimPartsFranchise={row[1]!r}  RowCount={row[2]:,}")
print("   Expect a single row: RawFranchise='D', DimPartsFranchise='D'.")
print("   Any other row is a real exception worth investigating before building the M query.")
