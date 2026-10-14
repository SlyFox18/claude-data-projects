"""
DP_PRESENTATION - FACT_PART_TRANSACTIONS VERIFICATION (Batch C, 3/5)
============================================================================
Confirms Fact_Part_Transactions landed correctly after Brian ran
Build_Gold_PartTransactions.Notebook. This is a REDESIGN, not a faithful
port - see docs/architecture/lh-master-data-facts-catalog.md (Batch C
section) and project memory project_facts_catalog_audit.md for the real
usage audit that justified dropping ~30 columns, the matrix-pricing
block, and the customer-dimension join.
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
    "TransactionDate", "Branch", "BranchKey", "FranchiseKey", "PartNumber",
    "PartNumberKey", "Type", "Quantity", "SaleAmount", "CostAmount",
    "Margin", "MarginPercent", "SalesType",
}

print("=" * 80)
print("VERIFY: Fact_Part_Transactions")
print("=" * 80)

count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{pres_base}/Fact_Part_Transactions')").fetchone()[0]
print(f"Row count: {count:,} (expect 11,237,844 - the real Type IN ('C','I') count against Silver_InTrans)")

cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{pres_base}/Fact_Part_Transactions') LIMIT 0").df()
col_set = set(cols["column_name"].tolist())
if col_set == EXPECTED_COLS:
    print(f"PASS: {len(EXPECTED_COLS)}-column contract matches exactly (13 columns, down from 40+).")
else:
    print(f"Missing: {EXPECTED_COLS - col_set}")
    print(f"Extra: {col_set - EXPECTED_COLS}")

print("\n-- Independent recount: Silver_InTrans rows with Type IN ('C','I') --")
src_count = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{staging_base}/Silver_InTrans') WHERE Type IN ('C', 'I')
""").fetchone()[0]
print(f"Source count: {src_count:,} (expect exact match to Fact_Part_Transactions row count)")

print("\n-- Type breakdown (expect ONLY C and I) --")
type_check = con.execute(f"""
    SELECT Type, COUNT(*) AS n FROM delta_scan('{pres_base}/Fact_Part_Transactions') GROUP BY Type
""").df()
print(type_check.to_string())

print("\n-- Null key rates --")
null_check = con.execute(f"""
    SELECT
        SUM(CASE WHEN BranchKey IS NULL THEN 1 ELSE 0 END) AS NullBranchKey,
        SUM(CASE WHEN PartNumberKey IS NULL THEN 1 ELSE 0 END) AS NullPartNumberKey,
        SUM(CASE WHEN FranchiseKey IS NULL THEN 1 ELSE 0 END) AS NullFranchiseKey,
        COUNT(*) AS TotalRows
    FROM delta_scan('{pres_base}/Fact_Part_Transactions')
""").df()
print(null_check.to_string())

print("\n-- Margin/MarginPercent sanity: spot check against raw SaleAmount/CostAmount --")
margin_check = con.execute(f"""
    SELECT COUNT(*) AS Mismatches FROM delta_scan('{pres_base}/Fact_Part_Transactions')
    WHERE ABS(Margin - (SaleAmount - CostAmount)) > 0.01
""").fetchone()[0]
print(f"Margin calculation mismatches: {margin_check} (expect 0)")

print("\n-- SalesType breakdown --")
sales_type = con.execute(f"""
    SELECT SalesType, COUNT(*) AS n FROM delta_scan('{pres_base}/Fact_Part_Transactions')
    GROUP BY SalesType
""").df()
print(sales_type.to_string())

print("\n-- Sample rows --")
sample = con.execute(f"SELECT * FROM delta_scan('{pres_base}/Fact_Part_Transactions') LIMIT 10").df()
print(sample.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
