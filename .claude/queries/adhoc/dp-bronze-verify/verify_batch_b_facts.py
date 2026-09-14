"""
DP_PRESENTATION - FACTS BATCH B VERIFICATION
============================================================================
Confirms Batch B's facts landed correctly (see
docs/architecture/lh-master-data-facts-catalog.md). Covers all real tables
built this batch (17, accounting for the multi-table dataflows found along
the way):
  Fact_JobCodePartFrequency, Fact_JobCodePartFrequency_Branch,
  Fact_InternalWorkOrders, Fact_PendingInspections, Fact_LaborJobSummary,
  Fact_ServiceRecommendations, Fact_PlanterInspectionParts,
  Fact_PlanterInspections, Fact_PlanterPartSales, Fact_PlanterInvoiceAllParts,
  Fact_InTrans_UniqueCustomers, Fact_Invoice_UniqueCustomers,
  Fact_Invoice_InventoryAnalysis, Fact_PartsNotReordered,
  Fact_MDInvoices_Closed, Fact_MDInvoices_NoFreight, Fact_Transfers.

Run manually after Brian adds the new shortcuts (RepairOrderDetail,
Silver_WkMechWk, Silver_VhStock) to DP_Presentation, syncs the workspace,
and runs all 9 new notebooks in this order (respecting real dependencies):
  1. Build_Gold_JobCodePartFrequency
  2. Build_Gold_JobCodePartFrequencyBranch
  3. Build_Gold_InternalWorkOrders
  4. Build_Gold_PendingInspections
  5. Build_Gold_LaborJobSummary
  6. Build_Gold_ServiceRecommendations   (needs 4 and 5 done first)
  7. Build_Gold_PlanterInspectionPartSales
  8. Build_Gold_InTransUniqueCustomers
  9. Build_Gold_InvoiceUniqueCustomers
  10. Build_Gold_InvoiceInventoryAnalysis
  11. Build_Gold_PartsNotReordered
  12. Build_Gold_MDInvoicesClosed
  13. Build_Gold_MDInvoicesNoFreight
  14. Build_Gold_Transfers
============================================================================
"""

import duckdb

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"
base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")


def check_table(name, expected_cols=None, note=""):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    try:
        count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{name}')").fetchone()[0]
    except Exception as e:
        print(f"FAIL: could not read table - {e}")
        print()
        return
    print(f"Row count: {count:,}" + (f" ({note})" if note else ""))
    if expected_cols:
        cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{base}/{name}') LIMIT 0").df()
        col_set = set(cols["column_name"].tolist())
        if col_set == expected_cols:
            print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
        else:
            print(f"Missing: {expected_cols - col_set}")
            print(f"Extra: {col_set - expected_cols}")
    print()


check_table("Fact_JobCodePartFrequency",
            {"JobCode", "PartNumber", "TimesWithPart", "TotalOrdersWithJobCode", "FrequencyPct"})
check_table("Fact_JobCodePartFrequency_Branch",
            {"Branch", "JobCode", "PartNumber", "TimesWithPart", "TotalOrdersWithJobCode", "FrequencyPct"})
check_table("Fact_InternalWorkOrders",
            {"Branch", "WorkOrder", "JobCode", "JobType", "JobValue", "CreatedOn", "ClosedDate",
             "ProgressStatus", "IsClosed", "StockNumber", "Registration", "Make", "Model", "EstHours",
             "IsStandardLabor", "IsNonRevenue", "InvoiceNumber", "HoursWorked", "InvoiceHours", "Year",
             "VIN", "OwnerContactCode", "SalesValue", "StockStatus", "SaleDate", "RetailCost",
             "WholesaleCost", "RepairCost", "Salesperson", "SalesInvoice", "SalesType"},
            note="expect ~7,000-12,000 per production's own documentation")
check_table("Fact_PendingInspections",
            {"BranchCode", "WorkOrderNumber", "JobCode", "JobType", "StatusDisplay", "ROProgressStatus",
             "CreationDate", "FirstLaborPunch", "LastLaborPunch", "DaysSinceCreation", "HoursWorked",
             "IsInspection"})
check_table("Fact_LaborJobSummary",
            {"BranchCode", "WorkOrderNumber", "JobCode", "JobType", "EstimatedLaborAmount",
             "ActualLaborAmount", "InvoicedLaborAmount", "EstimatedHours", "ActualHoursWorked",
             "InvoicedHours", "EstimatedPartsAmount", "ActualPartsAmount", "InvoicedPartsAmount",
             "TotalInvoicedAmount", "TotalEstimatedAmount", "HoursVariance", "IsMachineDown",
             "WorkCategory", "JobStatus", "IsNonRevenue", "IsFieldRepair", "IsStandardLabor",
             "InvoiceNumber", "InvoiceDate", "ClaimNumber", "WorkOrderStatus", "WorkOrderCreationDate",
             "WorkOrderClosedDate", "ModifiedDate", "IsInspection", "IsPending"})
check_table("Fact_ServiceRecommendations",
            {"InspectionJobCode", "JobCode", "JobType", "CompletedInspections", "TimesAdded", "TotalLabor"})
check_table("Fact_PlanterInspectionParts",
            {"BranchCode", "InvoiceNumber", "CustomerNumber", "PartNumber", "Description", "Franchise",
             "Quantity", "SaleValue", "CostValue", "TransactionDate"})
check_table("Fact_PlanterInspections",
            {"BranchCode", "WorkOrderNumber", "InvoiceNumber", "CustomerNumber", "InvoicedLaborAmount",
             "InvoiceDate", "WorkOrderCreationDate"})
check_table("Fact_PlanterPartSales",
            {"BranchCode", "InvoiceNumber", "CustomerNumber", "PartNumber", "Description", "Franchise",
             "Quantity", "SaleValue", "CostValue", "TransactionDate"})
check_table("Fact_PlanterInvoiceAllParts",
            {"BranchCode", "InvoiceNumber", "CustomerNumber", "PartNumber", "Description", "Franchise",
             "Quantity", "SaleValue", "CostValue", "TransactionDate", "IsPlanterPart"})
check_table("Fact_InTrans_UniqueCustomers",
            {"TransactionKey", "DateKey", "TransDatetime", "TransactionYear", "TransactionMonth",
             "TransactionQuarter", "TransactionYearMonth", "Branch", "BranchKey", "CustomerNo",
             "CustomerKey", "Franchise", "PartNumber", "Description", "Qty", "Type", "TradeType",
             "RONumber", "SaleValue", "CostValue", "MarginAmount", "MarginPercent", "SellPrice1",
             "ListPrice", "SalesType"})
check_table("Fact_Invoice_UniqueCustomers",
            {"TransactionKey", "DateKey", "CustomerKey", "BranchKey", "InvoiceDate", "InvoiceYear",
             "InvoiceMonth", "InvoiceQuarter", "InvoiceYearMonth", "Branch", "CustomerNumber",
             "CompanyName", "InvoiceNumber", "WorkOrderNumber", "CustomerOrderNumber", "PartsSaleValue",
             "PartsCostValue", "MarginAmount", "MarginPercent", "SalesType", "InvoiceType"})
check_table("Fact_Invoice_InventoryAnalysis",
            {"InvoiceNumber", "InvoiceDate", "Branch", "ModuleTypeKey", "PaymentMethodKey", "ModuleType",
             "PaymentMethod", "CustomerNumber", "CompanyName", "FirstName", "LastName", "PartsSaleValue",
             "PartsCostValue", "PartsMargin", "PartsMarginPct", "ModifiedDate"},
            note="expect ~300-350K per production's own documentation")
check_table("Fact_PartsNotReordered",
            {"Branch", "PartNumber", "Description", "QtySold", "InvoiceNumber", "BinQty",
             "DealerGroupCode", "Current12MoSales", "Previous12MoSales", "TransDatetime", "SaleDate",
             "OnOrder", "Type", "Franchise"})
check_table("Fact_MDInvoices_Closed",
            {"FileNumber", "TransId", "Branch", "Franchise", "CustomerNumber", "InvoiceDate", "PartNumber",
             "OrderQty", "UnitPrice", "UnitCost", "LineTotal", "Weight", "TotalLineWeight",
             "TotalFreightCharged", "FreightLineCount", "FreightStatus", "Salesperson", "JobCode"})
check_table("Fact_MDInvoices_NoFreight",
            {"FileNumber", "LineNumber", "Branch", "Franchise", "CustomerNumber", "OrderDate",
             "CustomerOrderNumber", "RONumber", "OrderType", "PartNumber", "OrderQty", "UnitPrice",
             "UnitCost", "LineTotal", "Weight", "TotalLineWeight", "TotalFreightCharged",
             "FreightLineCount", "FreightStatus", "Salesperson", "JobCode", "SuppliedQty", "BackorderQty"})
check_table("Fact_Transfers",
            {"DateKey", "Date", "TransId", "TransDatetime", "RONumber", "Branch", "TransferBranch",
             "PartNumber", "Franchise", "Type", "TransferSubType", "Qty", "CostValue", "OrderQty",
             "ShippedQty", "OrderSalesman"})

print("=" * 80)
print("SPOT CHECKS - real bugs/findings this batch")
print("=" * 80)

print("\n-- Fact_LaborJobSummary.IsPending (KNOWN ISSUE - expect ~100% False) --")
pending = con.execute(f"""
    SELECT IsPending, COUNT(*) AS n FROM delta_scan('{base}/Fact_LaborJobSummary') GROUP BY IsPending
""").df()
print(pending.to_string())

print("\n-- Fact_Invoice_InventoryAnalysis ModuleTypeKey=99 (the fixed edge case) --")
mtk99 = con.execute(f"""
    SELECT COUNT(*) AS n FROM delta_scan('{base}/Fact_Invoice_InventoryAnalysis') WHERE ModuleTypeKey = 99
""").fetchone()[0]
print(f"ModuleTypeKey=99 rows: {mtk99:,} (expect > 0 now - these used to be silently dropped)")
null_mtk = con.execute(f"""
    SELECT COUNT(*) AS n FROM delta_scan('{base}/Fact_Invoice_InventoryAnalysis') WHERE ModuleTypeKey IS NULL
""").fetchone()[0]
print(f"Null ModuleTypeKey rows (expect 0): {null_mtk}")

print("\n-- Fact_Transfers TransferSubType (expect 'Unknown' near-zero) --")
subtype = con.execute(f"""
    SELECT TransferSubType, COUNT(*) AS n FROM delta_scan('{base}/Fact_Transfers')
    WHERE Type = 'T' GROUP BY TransferSubType ORDER BY n DESC
""").df()
print(subtype.to_string())

print("\n-- Fact_InternalWorkOrders LineNumber=1 fix - row count sanity --")
iwo_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Fact_InternalWorkOrders')").fetchone()[0]
print(f"Total rows: {iwo_count:,} (expect ~7,000-12,000 - if much higher, the LineNumber=1 filter may not have applied)")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
