"""
DP_PRESENTATION - CUSTOMER ANATOMY VERIFICATION (Batch D, all 9 tables, LAST)
============================================================================
Confirms all 9 Customer Anatomy tables landed correctly after Brian ran
every Build_Gold_*.Notebook in Fact Tables/Customer Anatomy/. See
docs/architecture/lh-master-data-facts-catalog.md (Batch D section).
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

CONTRACTS = {
    "CustomerLookup": {"MatchKey", "CustomerKey", "ContactID", "Territory", "DisplayName", "MatchType"},
    "dim_EngagedAcres": {
        "CustomerNumber", "EngagementLevel", "EstimatedAcres", "EngagedAcreBreadth",
        "EngagedAcreDepth", "HighlyEngagedAcres", "PrepareAcres", "PlantAcres",
        "ApplyAcres", "HarvestAcres",
    },
    "Fact_Parts_Invoices": {
        "InvoiceNumber", "CustomerKey", "InvoiceDateKey", "BillToAccount", "ContactID",
        "Territory", "CustomerDisplayName", "CompanyName", "CustomerNumber", "InvoiceDate",
        "InvoiceYear", "InvoiceMonth", "Branch", "InvoiceType", "ModuleType",
        "PartsCostValue", "PartsSaleValue", "TotalPartsSales", "PartsMargin",
        "LabourCostValue", "LabourSaleValue", "SubletCostValue", "SubletSaleValue",
        "OtherSaleValue", "GST", "TotalNetSales", "TotalCost", "TotalMargin",
        "PaidCash", "PaidCreditCard", "PaidCheque", "PaymentMethod",
    },
    "Fact_Service_Invoices": {
        "InvoiceNumber", "CustomerKey", "InvoiceDateKey", "BillToAccount", "ContactID",
        "Territory", "CustomerDisplayName", "CompanyName", "CustomerNumber",
        "CustomerVehicleFlag", "IsStockEquipment", "InvoiceDate", "InvoiceYear",
        "InvoiceMonth", "Branch", "InvoiceType", "ModuleType", "LabourCostValue",
        "LabourSaleValue", "TotalLabourSales", "LabourMargin", "PartsCostValue",
        "PartsSaleValue", "SubletCostValue", "SubletSaleValue", "OtherSaleValue", "GST",
        "TotalNetSales", "TotalCost", "TotalMargin", "PaidCash", "PaidCreditCard",
        "PaidCheque", "PaymentMethod",
    },
    "Fact_Equipment_Sales": {
        "StockNumber", "CustomerKey", "SaleDateKey", "AccountNumber", "Territory",
        "SaleDate", "SaleYear", "SaleMonth", "Make", "Model", "Year", "VIN",
        "EngineNumber", "Status", "SalesValue", "RetailCost", "WholesaleCost",
        "PredeliveryCost", "RepairCost", "AccessoryCost", "OtherCost", "RegistrationFees",
        "LotFees", "StampDuty", "TransferFees", "OptionCost", "PaintCost", "TrimCost",
        "ChargeCost", "AfterMarketCost", "TotalBaseCost", "TotalTradeAllowance",
        "TradeAllowance", "PreTradeAllowance", "OwnerContactCode",
    },
    "Fact_CustomerPerformance": {
        "CustomerKey", "Year", "Month", "PeriodDateKey", "Territory",
        "PartsSales", "PartsCost", "PartsMargin", "ServiceSales", "ServiceCost",
        "ServiceMargin", "EquipmentSales", "EquipmentCost", "EquipmentMargin",
        "TotalSales", "TotalCost", "TotalMargin", "TotalTransactionCount",
    },
    "Fact_Parts_Detail": {
        "TransId", "CustomerKey", "TransDateKey", "BillToAcc", "ContactID", "Territory",
        "CustomerDisplayName", "TransDatetime", "TransYear", "TransMonth", "Branch",
        "Franchise", "PartNumber", "Description", "Type", "RONumber", "InvoiceNumber",
        "Qty", "SaleValue", "CostValue", "LineMargin", "IsSundryPart",
    },
    "Fact_Service_Parts_Details": {
        "BranchCode", "InvoiceNumber", "TransactionDate", "PartNumber", "Description",
        "Franchise", "Quantity", "SaleValue", "CostValue", "SellPrice", "ListPrice",
        "CustomerNumber", "TradeType",
    },
    "Fact_Service_Detail": {
        "CustomerKey", "InvoiceDateKey", "BillToAccount", "ContactID", "Territory",
        "CustomerDisplayName", "CustomerVehicleFlag", "IsStockEquipment", "InvoiceDate",
        "InvoiceYear", "InvoiceMonth", "Branch", "WorkOrder", "JobCode", "JobType",
        "JobStatus", "WorkCategory", "IsNonRevenue", "IsFieldRepair", "IsMachineDown",
        "EstLabor", "ActLabor", "InvLabor", "LaborMargin", "EstHours", "EstParts",
        "ActParts", "InvParts", "PartsMargin", "TotalInvoiced", "TotalJobMargin",
        "InvoiceNumber", "ClaimNumber", "IsWarrantyJob", "DetailSource",
    },
}


def check_contract(name, expected_cols):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    try:
        count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{name}')").fetchone()[0]
    except Exception as e:
        print(f"FAIL: could not read table - {e}\n")
        return None
    print(f"Row count: {count:,}")
    cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/{name}') LIMIT 0").df()
    col_set = set(cols["column_name"].tolist())
    if col_set == expected_cols:
        print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
    else:
        print(f"Missing: {expected_cols - col_set}")
        print(f"Extra: {col_set - expected_cols}")
    print()
    return count


counts = {}
for tbl, cols in CONTRACTS.items():
    counts[tbl] = check_contract(tbl, cols)

print("=" * 80)
print("SPOT CHECKS")
print("=" * 80)

print("\n-- CustomerLookup: duplicate MatchKey check (expect 0) --")
dup_check = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT MatchKey FROM delta_scan('{base}/CustomerLookup') GROUP BY MatchKey HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate MatchKey groups: {dup_check}")

print("\n-- Fact_Service_Invoices: the real bug fix - CustomerKey breakdown --")
print("   (expect Unknown Customer revenue near the ~$2.3M production baseline, NOT ~$19M -")
print("    and NOT some other inflated number from the dedup/SUM bug that's now removed)")
svc_breakdown = con.execute(f"""
    SELECT
        SUM(CASE WHEN CustomerKey = -9 THEN 1 ELSE 0 END) AS StockEquipmentRows,
        SUM(CASE WHEN CustomerKey = -1 THEN 1 ELSE 0 END) AS UnknownCustomerRows,
        SUM(CASE WHEN CustomerKey > 0 THEN 1 ELSE 0 END) AS MatchedCustomerRows,
        SUM(CASE WHEN CustomerKey = -9 THEN LabourSaleValue ELSE 0 END) AS StockEquipmentLaborRevenue,
        SUM(CASE WHEN CustomerKey = -1 THEN LabourSaleValue ELSE 0 END) AS UnknownCustomerLaborRevenue,
        COUNT(*) AS TotalRows
    FROM delta_scan('{base}/Fact_Service_Invoices')
""").df()
print(svc_breakdown.to_string())

print("\n-- Fact_Service_Invoices: confirm no more InvoiceNumber-reuse merging --")
print("   (the real safe grain - InvoiceNumber+Branch - should have 0 duplicates now)")
grain_check = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT InvoiceNumber, Branch FROM delta_scan('{base}/Fact_Service_Invoices')
        GROUP BY InvoiceNumber, Branch HAVING COUNT(*) > 1
    )
""").fetchone()[0]
print(f"Duplicate (InvoiceNumber, Branch) groups: {grain_check} (expect 0)")

print("\n-- Fact_CustomerPerformance: TotalSales sanity (both should match exactly) --")
totals_check = con.execute(f"""
    SELECT SUM(TotalSales) AS SumTotalSales,
           SUM(PartsSales + ServiceSales + EquipmentSales) AS RecomputedTotalSales
    FROM delta_scan('{base}/Fact_CustomerPerformance')
""").df()
print(totals_check.to_string())

print("\n-- Fact_CustomerPerformance: single source of truth check --")
print("   (SUM(PartsSales) here should equal SUM(TotalPartsSales) in Fact_Parts_Invoices)")
l1_parts = con.execute(f"SELECT SUM(PartsSales) FROM delta_scan('{base}/Fact_CustomerPerformance')").fetchone()[0]
l2_parts = con.execute(f"SELECT SUM(TotalPartsSales) FROM delta_scan('{base}/Fact_Parts_Invoices')").fetchone()[0]
print(f"Level 1 (Fact_CustomerPerformance) PartsSales total: {l1_parts:,.2f}")
print(f"Level 2 (Fact_Parts_Invoices) TotalPartsSales total:  {l2_parts:,.2f}")
print(f"Match: {abs((l1_parts or 0) - (l2_parts or 0)) < 0.01}")

print("\n-- Fact_Service_Detail: DetailSource breakdown (expect both types present) --")
source_breakdown = con.execute(f"""
    SELECT DetailSource, COUNT(*) AS n FROM delta_scan('{base}/Fact_Service_Detail')
    GROUP BY DetailSource
""").df()
print(source_breakdown.to_string())

print("\n-- Fact_Service_Detail: drill-through coverage (every Service invoice should have >=1 detail row) --")
coverage = con.execute(f"""
    SELECT
        (SELECT COUNT(DISTINCT InvoiceNumber) FROM delta_scan('{base}/Fact_Service_Invoices')) AS ServiceInvoiceCount,
        (SELECT COUNT(DISTINCT InvoiceNumber) FROM delta_scan('{base}/Fact_Service_Detail')) AS DetailInvoiceCount
""").df()
print(coverage.to_string())

print("\n-- Fact_Parts_Detail: sundry breakdown --")
sundry = con.execute(f"""
    SELECT IsSundryPart, COUNT(*) AS n, SUM(SaleValue) AS TotalSales
    FROM delta_scan('{base}/Fact_Parts_Detail') GROUP BY IsSundryPart
""").df()
print(sundry.to_string())

print("\n-- Null CustomerKey rate across all customer-keyed facts (expect 0 nulls - -1/-9 used instead) --")
for tbl in ["Fact_Parts_Invoices", "Fact_Service_Invoices", "Fact_Equipment_Sales",
            "Fact_CustomerPerformance", "Fact_Parts_Detail", "Fact_Service_Detail"]:
    n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{tbl}') WHERE CustomerKey IS NULL").fetchone()[0]
    print(f"{tbl}: {n} null CustomerKey rows (expect 0)")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
