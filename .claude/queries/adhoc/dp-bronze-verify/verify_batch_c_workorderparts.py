"""
DP_PRESENTATION - FACT_WORKORDERPARTS VERIFICATION (Batch C, 1/5)
============================================================================
Confirms Fact_WorkOrderParts landed correctly after Brian ran
Build_Gold_WorkOrderParts.Notebook. See
docs/architecture/lh-master-data-facts-catalog.md (Batch C section).
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

EXPECTED_COLS = {
    "BranchCode", "InvoiceNumber", "TransactionDate", "PartNumber", "Description",
    "Franchise", "Quantity", "SaleValue", "CostValue", "SellPrice", "ListPrice",
    "CustomerNumber", "TradeType", "ModifiedDate",
}

print("=" * 80)
print("VERIFY: Fact_WorkOrderParts")
print("=" * 80)

count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Fact_WorkOrderParts')").fetchone()[0]
print(f"Row count: {count:,}")

cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/Fact_WorkOrderParts') LIMIT 0").df()
col_set = set(cols["column_name"].tolist())
if col_set == EXPECTED_COLS:
    print(f"PASS: {len(EXPECTED_COLS)}-column contract matches exactly.")
else:
    print(f"Missing: {EXPECTED_COLS - col_set}")
    print(f"Extra: {col_set - EXPECTED_COLS}")

print("\n-- Franchise breakdown (expect ZP discount rows present) --")
franchise = con.execute(f"""
    SELECT Franchise, COUNT(*) AS n, SUM(SaleValue) AS TotalSaleValue
    FROM delta_scan('{base}/Fact_WorkOrderParts')
    GROUP BY Franchise ORDER BY n DESC LIMIT 15
""").df()
print(franchise.to_string())

print("\n-- ZP franchise SaleValue sign check --")
print("   NOTE (confirmed 2026-09-14): Franchise='ZP' is a broader fee/surcharge bucket,")
print("   not just discounts - freight/service/battery-core fees are mostly POSITIVE,")
print("   only the named discount codes (LEGACY/*10PROMO/ADV/4900) are ~100% negative.")
print("   A mix here is expected, not a bug - see Build_Gold_WorkOrderParts.Notebook header.")
zp = con.execute(f"""
    SELECT COUNT(*) AS ZPRows,
           SUM(CASE WHEN SaleValue < 0 THEN 1 ELSE 0 END) AS NegativeRows
    FROM delta_scan('{base}/Fact_WorkOrderParts') WHERE Franchise = 'ZP'
""").df()
print(zp.to_string())

print("\n-- Sub-branch normalization sanity: any BranchCode ending in S/I/C/B? --")
subbranch = con.execute(f"""
    SELECT BranchCode, COUNT(*) AS n FROM delta_scan('{base}/Fact_WorkOrderParts')
    WHERE right(BranchCode, 1) IN ('S','I','C','B')
    GROUP BY BranchCode ORDER BY n DESC LIMIT 15
""").df()
print(subbranch.to_string())
print("(non-empty is fine - these are real sub-branch InTrans rows that matched via the")
print(" normalized-invoice lookup; this is NOT evidence of a bug on its own.)")

print("\n-- Business-grain dedup no-op check: any duplicate (BranchCode,InvoiceNumber,")
print("   PartNumber,TransactionDate,Quantity,SaleValue) groups in the FINAL table? --")
dup_check = con.execute(f"""
    SELECT COUNT(*) AS DupGroups FROM (
        SELECT BranchCode, InvoiceNumber, PartNumber, TransactionDate, Quantity, SaleValue
        FROM delta_scan('{base}/Fact_WorkOrderParts')
        GROUP BY 1,2,3,4,5,6 HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate groups in final table: {dup_check} (expect 0 - dedup already applied in the notebook)")

print("\n-- Date range sanity (3-year rolling cutoff) --")
date_range = con.execute(f"""
    SELECT MIN(TransactionDate) AS MinDate, MAX(TransactionDate) AS MaxDate
    FROM delta_scan('{base}/Fact_WorkOrderParts')
""").df()
print(date_range.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
