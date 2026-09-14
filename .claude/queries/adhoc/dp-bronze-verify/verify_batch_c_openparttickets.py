"""
DP_PRESENTATION - FACT_PARTS_OPEN_TICKETS + _DETAILS VERIFICATION
(Batch C, 5/5, LAST)
============================================================================
Confirms both tables landed correctly after Brian ran
Build_Gold_PartsOpenTickets.Notebook. See
docs/architecture/lh-master-data-facts-catalog.md (Batch C section) and
projects/open parts tickets - report/ for the real source SQL this
ports.
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

SUMMARY_COLS = {
    "Location", "Location_Name", "Order_No", "Invoice_Type", "Order_Date", "Created_On",
    "WO_Creation_Date", "Aging_Base_Date", "Days_Open", "Aging", "Aging_Sort_Order",
    "Aging_Date_Source", "#_Parts_On_Order", "#_On_Back_Order", "Order_Total_$$",
    "$$_Available", "$$_BackOrdered", "Backorder_Pct", "Deposit", "Salesman",
    "Contact_Code", "AR_Acct", "Customer",
}
DETAILS_COLS = {
    "Location", "Location_Name", "Order_No", "RO_Number", "File_No", "Invoice_Type",
    "Order_Date", "Created_On", "WO_Creation_Date", "Days_Open", "Aging",
    "Aging_Sort_Order", "Aging_Date_Source", "Part_No", "Quantity_Ordered", "Unit_Price",
    "Line_Total", "BackOrdered_QTY", "Available_QTY", "Line_Backorder_Pct",
    "Contact_Code", "Customer", "Salesman",
}


def check_contract(name, expected_cols):
    print("=" * 80)
    print(f"VERIFY: {name}")
    print("=" * 80)
    count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{pres_base}/{name}')").fetchone()[0]
    print(f"Row count: {count:,}")
    cols = con.execute(f"DESCRIBE SELECT * FROM delta_scan('{pres_base}/{name}') LIMIT 0").df()
    col_set = set(cols["column_name"].tolist())
    if col_set == expected_cols:
        print(f"PASS: {len(expected_cols)}-column contract matches exactly.")
    else:
        print(f"Missing: {expected_cols - col_set}")
        print(f"Extra: {col_set - expected_cols}")
    print()
    return count


summary_count = check_contract("Fact_Parts_Open_Tickets", SUMMARY_COLS)
details_count = check_contract("Fact_Parts_Open_Tickets_Details", DETAILS_COLS)

print("=" * 80)
print("SPOT CHECKS")
print("=" * 80)

print("\n-- Independent recount: InSalOrd rows excluding Transfers --")
src_orders = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{staging_base}/Silver_InSalOrd')
    WHERE OrderType IS NULL OR OrderType != 'T'
""").fetchone()[0]
print(f"Source InSalOrd rows (Type<>T): {src_orders:,} (Summary table should be <= this, one row per real order)")
print(f"Fact_Parts_Open_Tickets rows: {summary_count:,}")

print("\n-- Aging breakdown (Summary) --")
aging = con.execute(f"""
    SELECT Aging, Aging_Sort_Order, COUNT(*) AS n FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets')
    GROUP BY Aging, Aging_Sort_Order ORDER BY Aging_Sort_Order
""").df()
print(aging.to_string())

print("\n-- Aging_Sort_Order consistency: should exactly match the Aging bucket text --")
sort_check = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets')
    WHERE (Aging = '0-7 days' AND Aging_Sort_Order != 1)
       OR (Aging = '8-14 days' AND Aging_Sort_Order != 2)
       OR (Aging = '15-30 days' AND Aging_Sort_Order != 3)
       OR (Aging = '31-60 days' AND Aging_Sort_Order != 4)
       OR (Aging = '61-90 days' AND Aging_Sort_Order != 5)
       OR (Aging = '90+ days' AND Aging_Sort_Order != 6)
""").fetchone()[0]
print(f"Mismatches: {sort_check} (expect 0)")

print("\n-- Days_Open vs Aging_Base_Date consistency --")
days_check = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets')
    WHERE Days_Open < 0
""").fetchone()[0]
print(f"Negative Days_Open rows: {days_check} (expect 0)")

print("\n-- Aging_Date_Source breakdown --")
source_breakdown = con.execute(f"""
    SELECT Aging_Date_Source, COUNT(*) AS n FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets')
    GROUP BY Aging_Date_Source ORDER BY n DESC
""").df()
print(source_breakdown.to_string())

print("\n-- Order_No join consistency: Details.Order_No values should all exist in Summary --")
orphans = con.execute(f"""
    SELECT COUNT(DISTINCT d.Order_No) FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets_Details') d
    LEFT JOIN delta_scan('{pres_base}/Fact_Parts_Open_Tickets') s ON d.Order_No = s.Order_No AND d.Location = s.Location
    WHERE s.Order_No IS NULL
""").fetchone()[0]
print(f"Details Order_No values missing from Summary: {orphans} (expect 0)")

print("\n-- Invoice_Type discrepancy check (real, documented - expect Details has 'Invoice', Summary doesn't) --")
summary_types = con.execute(f"""
    SELECT DISTINCT Invoice_Type FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets') ORDER BY 1
""").df()
details_types = con.execute(f"""
    SELECT DISTINCT Invoice_Type FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets_Details') ORDER BY 1
""").df()
print("Summary Invoice_Type values:")
print(summary_types.to_string())
print("Details Invoice_Type values:")
print(details_types.to_string())

print("\n-- Sample rows --")
print(con.execute(f"SELECT * FROM delta_scan('{pres_base}/Fact_Parts_Open_Tickets') LIMIT 5").df().to_string())

print("\n" + "=" * 80)
print("DONE")
print("=" * 80)
