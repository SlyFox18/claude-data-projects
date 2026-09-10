"""
Verify Silver_InMaster against the DP_Staging InMaster bronze shortcut:
row count must match exactly (rename-only, no filter), spot-check the
20-column contract (including the IN_TRANSIT_QTY addition) and the
LowMarginFlag business field.
"""
import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY SILVER: Silver_InMaster")
print("=" * 80)

bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InMaster')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_InMaster')").fetchone()[0]

print(f"Bronze InMaster row count: {bronze_count:,}")
print(f"Silver_InMaster row count: {silver_count:,}")

if bronze_count == silver_count:
    print("PASS: row counts match exactly (rename-only, no filter, as expected).")
else:
    print(f"FAIL: row counts differ by {abs(bronze_count - silver_count):,} - "
          f"this notebook should never add or drop rows, investigate.")

expected_cols = {
    "Branch", "PartNumber", "PartDescription", "Franchise", "ProductGroup",
    "SalesClass", "Category", "ManufacturerCode", "ListPrice", "SellPrice1",
    "StockOrderPrice", "OnHandQty", "BackOrderQty", "InTransitQty",
    "LowMarginFlag", "UserField1", "UserField2", "LastUpdatedDatetime",
    "CreationDate", "LastDemandDate",
}

silver_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/Silver_InMaster') LIMIT 0").df()
silver_col_set = set(silver_cols["column_name"].tolist())

print(f"\nExpected columns: {len(expected_cols)}")
print(f"Silver_InMaster columns: {len(silver_col_set)}")

if expected_cols == silver_col_set:
    print("PASS: 20-column contract matches exactly (including IN_TRANSIT_QTY addition).")
else:
    missing = expected_cols - silver_col_set
    extra = silver_col_set - expected_cols
    if missing:
        print(f"Missing expected columns: {missing}")
    if extra:
        print(f"Unexpected extra columns: {extra}")

print("\nLowMarginFlag breakdown (confirms real values):")
breakdown = con.execute(f"""
    SELECT LowMarginFlag, COUNT(*) AS RowCount
    FROM delta_scan('{dp_base}/Silver_InMaster')
    GROUP BY LowMarginFlag
    ORDER BY RowCount DESC
    LIMIT 10
""").df()
print(breakdown.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
