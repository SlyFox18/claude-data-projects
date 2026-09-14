"""
DP_PRESENTATION - FACTS BATCH A VERIFICATION
============================================================================
Confirms the 4 easy Batch A facts landed correctly (see
docs/architecture/lh-master-data-facts-catalog.md):
  Fact_NegativeOnHand_OnHandNoBin, Fact_InSalOrd_InSalPar,
  Fact_OpenOrderParts, Fact_OpenOrders.

Run manually after Brian adds the Silver_InSalOrd, Silver_InSalPar, and
Silver_WkRoFile shortcuts to DP_Presentation, syncs the workspace, and runs
all 4 notebooks.
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")


def check_table(name, expected_cols, expect_row_range=None):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{name}')").fetchone()[0]
    print(f"Row count: {count:,}" + (f" (expect {expect_row_range})" if expect_row_range else ""))

    cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/{name}') LIMIT 0").df()
    col_set = set(cols["column_name"].tolist())
    if col_set == expected_cols:
        print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
    else:
        print(f"Missing: {expected_cols - col_set}")
        print(f"Extra: {col_set - expected_cols}")
    print()


check_table(
    "Fact_NegativeOnHand_OnHandNoBin",
    {
        "Branch", "PartNumber", "Description", "Franchise", "Source", "CommodityCode",
        "Bin", "BulkBin", "BinQty", "QuantityOnHand", "BulkBinQty", "PendingQty",
        "BackOrderQty", "OnOrder", "TotalAvailableQty", "Cost", "SellPrice1",
        "InventoryCost", "Current12MoSales", "Current12MoDollars", "DateCreated",
        "DateLastRequested", "DaysSinceLastRequest", "VendorCode",
        "HasNegativeBinQty", "HasBinQtyNoBin", "IssueType", "IssueSeverity",
        "InventoryValueAtRisk",
    },
    expect_row_range="~1,398 per production's own historical figure",
)
check_table(
    "Fact_InSalOrd_InSalPar",
    {
        "HeaderBranch", "CustomerNumber", "HeaderSalesperson", "FileNumber", "Order_No",
        "OrderType", "OrderDate", "Days_Open", "Aging", "#_Parts_On_Order",
        "#_On_Back_Order", "Order_Total_$$", "$$_not_BO", "Backorder_Amount", "Freight",
    },
    expect_row_range="~1,386 per production's own historical figure",
)
check_table(
    "Fact_OpenOrderParts",
    {"WorkOrderNumber", "BranchCode", "PartNumber"},
)
check_table(
    "Fact_OpenOrders",
    {"WorkOrderNumber", "BranchCode", "CustomerNumber", "JobCode", "OpenDate"},
    expect_row_range="hundreds to low thousands, per production's own documentation",
)

print("=" * 80)
print("Fact_NegativeOnHand_OnHandNoBin - IssueType breakdown + sample")
print("=" * 80)
noh_breakdown = con.execute(f"""
    SELECT IssueType, IssueSeverity, COUNT(*) AS RowCount
    FROM delta_scan('{base}/Fact_NegativeOnHand_OnHandNoBin')
    GROUP BY IssueType, IssueSeverity ORDER BY IssueType, IssueSeverity
""").df()
print(noh_breakdown.to_string())
no_issue = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{base}/Fact_NegativeOnHand_OnHandNoBin') WHERE IssueType = 'No Issue'
""").fetchone()[0]
print(f"\n'No Issue' rows (expect 0): {no_issue}")

print("\n" + "=" * 80)
print("Fact_InSalOrd_InSalPar - Aging breakdown")
print("=" * 80)
aging = con.execute(f"""
    SELECT Aging, COUNT(*) AS OrderCount, SUM("Order_Total_$$") AS TotalValue
    FROM delta_scan('{base}/Fact_InSalOrd_InSalPar')
    GROUP BY Aging ORDER BY Aging
""").df()
print(aging.to_string())
dup_fileno = con.execute(f"""
    SELECT FileNumber, COUNT(*) AS n FROM delta_scan('{base}/Fact_InSalOrd_InSalPar')
    GROUP BY FileNumber HAVING COUNT(*) > 1
""").df()
print(f"\nDuplicate FileNumber rows (expect 0): {len(dup_fileno)}")

print("\n" + "=" * 80)
print("Fact_OpenOrders - sample")
print("=" * 80)
oo_sample = con.execute(f"""
    SELECT * FROM delta_scan('{base}/Fact_OpenOrders') ORDER BY OpenDate LIMIT 10
""").df()
print(oo_sample.to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
