"""
DP_PRESENTATION - FACT_INVENTORY VERIFICATION (Batch C, 2/5)
============================================================================
Confirms Fact_Inventory landed correctly after Brian ran
Build_Gold_Inventory.Notebook (and its prerequisite,
Build_Gold_DealerGroupCode.Notebook's duplicate-key fix). See
docs/architecture/lh-master-data-facts-catalog.md (Batch C section).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
staging_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"
pres_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

EXPECTED_COLS = {
    "BranchKey", "PartNumber", "PartNumberKey", "Description", "FranchiseKey",
    "VendorCodeKey", "SourceKey", "SLCKey", "DealerGroupKey", "CommodityCodeKey",
    "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "PackageQty",
    "Returnable", "SellPrice1", "Cost", "ListPrice", "Current12MoSales",
    "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars",
    "DateCreated", "DateLastRequested",
}

print("=" * 80)
print("VERIFY: Fact_Inventory")
print("=" * 80)

count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{pres_base}/Fact_Inventory')").fetchone()[0]
print(f"Row count: {count:,}")

cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{pres_base}/Fact_Inventory') LIMIT 0").df()
col_set = set(cols["column_name"].tolist())
if col_set == EXPECTED_COLS:
    print(f"PASS: {len(EXPECTED_COLS)}-column contract matches exactly.")
else:
    print(f"Missing: {EXPECTED_COLS - col_set}")
    print(f"Extra: {col_set - EXPECTED_COLS}")

print("\n-- Independent recount: Silver_PartInformation rows with InventoryCost <> 0 --")
src_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{staging_base}/Silver_PartInformation') WHERE InventoryCost <> 0
""").fetchone()[0]
print(f"Source count: {src_count:,} (expect exact match to Fact_Inventory row count)")

print("\n-- Null key rates (any large unexpected gap is worth investigating) --")
null_check = con.execute(f"""
    SELECT
        SUM(CASE WHEN BranchKey IS NULL THEN 1 ELSE 0 END) AS NullBranchKey,
        SUM(CASE WHEN PartNumberKey IS NULL THEN 1 ELSE 0 END) AS NullPartNumberKey,
        SUM(CASE WHEN FranchiseKey IS NULL THEN 1 ELSE 0 END) AS NullFranchiseKey,
        SUM(CASE WHEN VendorCodeKey IS NULL THEN 1 ELSE 0 END) AS NullVendorCodeKey,
        SUM(CASE WHEN SourceKey IS NULL THEN 1 ELSE 0 END) AS NullSourceKey,
        SUM(CASE WHEN SLCKey IS NULL THEN 1 ELSE 0 END) AS NullSLCKey,
        SUM(CASE WHEN DealerGroupKey IS NULL THEN 1 ELSE 0 END) AS NullDealerGroupKey,
        SUM(CASE WHEN CommodityCodeKey IS NULL THEN 1 ELSE 0 END) AS NullCommodityCodeKey,
        COUNT(*) AS TotalRows
    FROM delta_scan('{pres_base}/Fact_Inventory')
""").df()
print(null_check.to_string())

print("\n-- CommodityCodeKey completeness fix check (the real bug fixed this batch) --")
cc_check = con.execute(f"""
    SELECT
        SUM(CASE WHEN CommodityCodeKey IS NULL THEN 1 ELSE 0 END) AS NullCommodityCodeKey,
        COUNT(*) AS TotalRows
    FROM delta_scan('{pres_base}/Fact_Inventory')
""").df()
print(cc_check.to_string())
print("(expect NullCommodityCodeKey close to 0 - previously ~22% of rows would have been")
print(" silently null here before the 'Unknown' casing fix)")

print("\n-- dim_DealerGroupCode duplicate check (the real bug fixed this batch) --")
dgc_dupes = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT DealerGroupCode FROM delta_scan('{pres_base}/dim_DealerGroupCode')
        GROUP BY DealerGroupCode HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate DealerGroupCode groups in dim_DealerGroupCode: {dgc_dupes} (expect 0)")

print("\n-- Fan-out sanity: real grain is (PartNumber, BranchKey, FranchiseKey) --")
print("   NOTE: (PartNumber, BranchKey) alone is NOT unique - confirmed 2026-09-14 that")
print("   Silver_PartInformation's true natural key includes Franchise (the same part can")
print("   have separate real records at the same branch under different franchise codes,")
print("   each with its own cost/pricing/vendor). Checking the real grain instead.")
fanout_check = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT PartNumber, BranchKey, FranchiseKey FROM delta_scan('{pres_base}/Fact_Inventory')
        GROUP BY PartNumber, BranchKey, FranchiseKey HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate (PartNumber, BranchKey, FranchiseKey) groups: {fanout_check} (expect 0 - confirms no join fan-out)")

print("\n-- Sample rows --")
sample = con.execute(f"SELECT * FROM delta_scan('{pres_base}/Fact_Inventory') LIMIT 10").df()
print(sample.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
