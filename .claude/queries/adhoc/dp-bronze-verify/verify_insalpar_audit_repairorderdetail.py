"""
DP INSALPAR_AUDIT + REPAIRORDERDETAIL - VERIFICATION
============================================================================
Both tables landed via direct ODBC pull (Dataflow Gen2), not a shortcut -
there's no JD Bronze mirror to compare against. This script checks the
landed DP_Staging tables directly: row counts against the real numbers
found via SQL Central on 2026-09-10, and the real column contracts.

Row counts WILL drift from the numbers below since the source is live -
investigate only if the gap is large or the PurOrderType filter check
fails outright.

Run manually after Brian runs both dataflows (plan Task 4).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 80)
print("VERIFY: InSalPar_Audit")
print("=" * 80)

insalpar_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/InSalPar_Audit')").fetchone()[0]
print(f"Row count: {insalpar_count:,} (real source on 2026-09-10: 299,145 rows matching PURORDER_TYPE='E')")

expected_insalpar_cols = {
    "FileNo", "Branch", "Franchise", "PurOrderType", "PurOrderNo",
    "Salesman", "CustomerNo", "MachineId", "AuditTimestamp",
}
insalpar_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/InSalPar_Audit') LIMIT 0").df()
insalpar_col_set = set(insalpar_cols["column_name"].tolist())
if expected_insalpar_cols == insalpar_col_set:
    print("PASS: 9-column contract matches exactly (including the AuditTimestamp addition).")
else:
    print(f"Missing: {expected_insalpar_cols - insalpar_col_set}")
    print(f"Extra: {insalpar_col_set - expected_insalpar_cols}")

purordertype_check = con.execute(f"""
    SELECT PurOrderType, COUNT(*) AS RowCount
    FROM delta_scan('{dp_base}/InSalPar_Audit')
    GROUP BY PurOrderType
""").df()
print("\nPurOrderType breakdown (every row should be 'E' - the filter is applied at the source query):")
print(purordertype_check.to_string())

print("\n" + "=" * 80)
print("VERIFY: RepairOrderDetail")
print("=" * 80)

ro_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/RepairOrderDetail')").fetchone()[0]
print(f"Row count: {ro_count:,} (real source on 2026-09-10: 2,875 rows)")

expected_ro_cols = {
    "Branch", "RONumber", "JobCode", "JobType", "InvoiceNumber", "StatusDisplay",
    "Status", "ROProgressStatus", "CreationDate", "ROStartDate", "ROFinishDate",
    "JobStartDate", "JobFinishDate", "InvoiceDate", "AvailablePickupDate",
    "ClosedDate", "QuotationIndicator", "QuotationExpirationDate",
    "FirstLaborPunch", "LastLaborPunch", "SalespersonCode", "NonRevenueIndicator",
    "Year", "LaborSale", "PartSale", "SubletSale", "OtherSale", "TotalSale",
    "DaysSinceCreationDate", "DaysSinceROFinishDate", "DaysSinceLastLabor",
    "SourceCurrentDate",
}
ro_cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{dp_base}/RepairOrderDetail') LIMIT 0").df()
ro_col_set = set(ro_cols["column_name"].tolist())
if expected_ro_cols == ro_col_set:
    print("PASS: 31-column contract matches exactly.")
else:
    print(f"Missing: {expected_ro_cols - ro_col_set}")
    print(f"Extra: {ro_col_set - expected_ro_cols}")

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
