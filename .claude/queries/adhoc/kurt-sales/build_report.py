"""
KURT SALES - PARTS AND SERVICE ACTIVITY (AD HOC)
============================================================================
Request: Kurt (sales) supplied a territory account list (account-list.xlsx,
1,080 accounts) and wanted to know which of these customers bought parts
and/or service in the last ~2 years, with sales totals and a part-level
detail view. Delivered as an Excel workbook (Brian works this in Excel,
not Power BI).

Source: LH_Master_Data lakehouse, queried directly via DuckDB over OneLake
(no Fabric notebook/dataflow needed - this is a one-off ad hoc pull).

Tables used:
- Fact_Parts_Invoices  (ModuleType='I' already applied upstream) - PartsSales
- Fact_Service_Invoices (ModuleType='W' already applied upstream) - ServiceSales
- Fact_Parts_Detail    - line-item part detail (PartNumber, Qty, SaleValue)
- dim_Parts            - real part Description (Fact_Parts_Detail.Description
  is populated with the customer name, not the part description - this is
  expected/by-design in how the source system records the invoice line, and
  is already accounted for correctly in the Customer Anatomy report the same
  way: join to dim_Parts for the description, don't use Fact_Parts_Detail.Description)

Matching: Kurt's Account # is matched directly to BillToAccount on the Fact
tables (not routed through dim_CustomerList). Verified during development
that direct-match finds the same accounts as a dim_CustomerList join for
every account with actual purchase activity - dim_CustomerList uses inner
joins upstream and drops some accounts, but none that have real activity in
the fact tables, so the simpler direct match is safe and has one less
dependency.

Source file note: use account-list.xlsx, not account-list.csv - the CSV export
had an encoding issue that silently drops ~26 rows if parsed without care.

Output: "Kurt Sales - Parts and Service Activity (2025-01-01 to Present).xlsx"
- Summary tab: one row per account with activity (333 of 1,080), with
  Parts Sales $, Service Sales $, Total $, Last Parts Purchase Date, Last
  Service Date. Accounts with zero activity in the window are excluded per
  Brian's call - Kurt only wants buyers.
- Parts Detail tab: one row per account x part number sold in the window,
  with description, qty, and $ (18,146 rows).

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb
import pandas as pd

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

xlsx_path = "account-list.xlsx"
out_path = "Kurt Sales - Parts and Service Activity (2025-01-01 to Present).xlsx"

START_DATE = "2025-01-01"

kurt = pd.read_excel(xlsx_path, dtype=str)
kurt.columns = ["AccountNumber", "AccountName", "City", "State", "Type"]
kurt["AccountNumber"] = kurt["AccountNumber"].str.strip()

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
con.register("kurt_list", kurt)

# ------------------------------------------------------------------
# Summary: Parts Sales $ and Service Sales $ per account, company-wide (all branches)
# ------------------------------------------------------------------
summary = con.execute(f"""
    WITH parts AS (
        SELECT TRIM(BillToAccount) AS AccountNumber, SUM(TotalPartsSales) AS PartsSales,
               MAX(InvoiceDate) AS LastPartsPurchaseDate
        FROM delta_scan('{base}/Fact_Parts_Invoices')
        WHERE InvoiceDate >= TIMESTAMP '{START_DATE}'
        GROUP BY TRIM(BillToAccount)
    ),
    service AS (
        SELECT TRIM(BillToAccount) AS AccountNumber, SUM(TotalLabourSales) AS ServiceSales,
               MAX(InvoiceDate) AS LastServiceDate
        FROM delta_scan('{base}/Fact_Service_Invoices')
        WHERE InvoiceDate >= TIMESTAMP '{START_DATE}'
        GROUP BY TRIM(BillToAccount)
    ),
    combined AS (
        SELECT COALESCE(p.AccountNumber, s.AccountNumber) AS AccountNumber,
               COALESCE(p.PartsSales, 0) AS PartsSales,
               COALESCE(s.ServiceSales, 0) AS ServiceSales,
               p.LastPartsPurchaseDate, s.LastServiceDate
        FROM parts p
        FULL OUTER JOIN service s ON p.AccountNumber = s.AccountNumber
    )
    SELECT k.AccountNumber, k.AccountName, k.City, k.State,
           c.PartsSales, c.ServiceSales, (c.PartsSales + c.ServiceSales) AS TotalSales,
           CAST(c.LastPartsPurchaseDate AS DATE) AS LastPartsPurchaseDate,
           CAST(c.LastServiceDate AS DATE) AS LastServiceDate
    FROM kurt_list k
    INNER JOIN combined c ON TRIM(k.AccountNumber) = c.AccountNumber
    WHERE (c.PartsSales + c.ServiceSales) > 0
    ORDER BY TotalSales DESC
""").df()

# ------------------------------------------------------------------
# Parts detail: part-level summary per customer, same window
# ------------------------------------------------------------------
detail = con.execute(f"""
    SELECT k.AccountNumber, k.AccountName, k.City, k.State,
           d.PartNumber, p.Description,
           SUM(d.Qty) AS QtySold, SUM(d.SaleValue) AS PartsSales
    FROM kurt_list k
    INNER JOIN delta_scan('{base}/Fact_Parts_Detail') d
        ON TRIM(d.BillToAcc) = TRIM(k.AccountNumber)
    LEFT JOIN delta_scan('{base}/dim_Parts') p
        ON d.PartNumber = p.PartNumber
    WHERE d.TransDatetime >= TIMESTAMP '{START_DATE}'
    GROUP BY k.AccountNumber, k.AccountName, k.City, k.State, d.PartNumber, p.Description
    ORDER BY k.AccountName, PartsSales DESC
""").df()

print(f"Summary rows (accounts with activity): {len(summary)} of {len(kurt)} total accounts")
print(f"Detail rows (customer x part lines): {len(detail)}")
print(f"Parts-only accounts: {(summary['ServiceSales']==0).sum()}, Service-only: {(summary['PartsSales']==0).sum()}, Both: {((summary['PartsSales']>0)&(summary['ServiceSales']>0)).sum()}")

with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    summary.to_excel(writer, sheet_name="Summary", index=False)
    detail.to_excel(writer, sheet_name="Parts Detail", index=False)

print(f"Saved: {out_path}")
