"""Customer Anatomy parity: DP_Presentation vs production LH_Master_Data, complete months only.

Expected differences (spec, decisions 1/2/5):
  Service_Detail: prod ~2x DP for 2023+ (prod doubling bug); DP adds 2022
  Equipment_Sales: DP adds 2022; 2023+ identical
  CustomerPerformance: 2022 gains equipment; service follows Service_Invoices
  Service_Invoices: small diffs from the reused-InvoiceNumber fix (key-level list printed)
  Parts_Detail: DP higher in Aug 2026 (prod InTrans gap); older small diffs listed key-level
  lookup: identical except the 4 approved Tornillo/Dell City corrections
"""
import sys
from datetime import date, timedelta

import duckdb

sys.stdout.reconfigure(encoding="utf-8")
con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
DP = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
LAST = date.today().replace(day=1) - timedelta(days=1)
print(f"Complete months through {LAST}\n")


def show(title, sql, limit=80):
    cur = con.sql(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(f"=== {title} ({len(rows)} rows)\n  " + " | ".join(cols))
    for r in rows[:limit]:
        print("  " + " | ".join("" if v is None else str(v) for v in r))
    if len(rows) > limit:
        print(f"  ... {len(rows) - limit} more")
    print()


def monthly(table, date_expr, measures):
    agg = ", ".join(f"ROUND(SUM(CAST({m} AS DOUBLE)), 2) AS {m}" for m in measures)
    for tag, base in (("dp", DP), ("prod", LH)):
        con.sql(f"""CREATE OR REPLACE TABLE {table}_{tag} AS
            SELECT strftime({date_expr}, '%Y-%m') AS ym, COUNT(*) AS n, {agg}
            FROM delta_scan('{base}{table}') WHERE {date_expr} <= DATE '{LAST}' GROUP BY 1""")
    diffs = ", ".join(f"ROUND(COALESCE(d.{m},0) - COALESCE(p.{m},0), 2) AS d_{m}" for m in measures)
    show(f"{table} by month (dp - prod)", f"""
        SELECT COALESCE(d.ym, p.ym) AS ym, d.n AS dp_n, p.n AS prod_n, {diffs}
        FROM {table}_dp d FULL OUTER JOIN {table}_prod p ON d.ym = p.ym ORDER BY 1""", limit=200)


monthly("Fact_CustomerPerformance", "make_date(CAST(PeriodDateKey/10000 AS INT), CAST(PeriodDateKey/100 % 100 AS INT), 1)",
        ["PartsSales", "ServiceSales", "EquipmentSales", "TotalSales"])
monthly("Fact_Parts_Invoices", "CAST(InvoiceDate AS DATE)", ["PartsSaleValue", "PartsCostValue"])
monthly("Fact_Service_Invoices", "CAST(InvoiceDate AS DATE)", ["LabourSaleValue", "PartsSaleValue", "TotalNetSales"])
monthly("Fact_Equipment_Sales", "CAST(SaleDate AS DATE)", ["SalesValue", "TotalBaseCost"])
monthly("Fact_Parts_Detail", "CAST(TransDatetime AS DATE)", ["SaleValue", "CostValue"])
monthly("Fact_Service_Detail", "CAST(InvoiceDate AS DATE)", ["InvLabor", "InvParts", "TotalInvoiced"])
# Fact_Service_Parts_Details has no date column - compare totals (both sides are full snapshots).
show("Fact_Service_Parts_Details totals", f"""
    SELECT 'dp' side, COUNT(*), ROUND(SUM(CAST(SaleValue AS DOUBLE)),2), ROUND(SUM(CAST(Quantity AS DOUBLE)),2) FROM delta_scan('{DP}Fact_Service_Parts_Details')
    UNION ALL SELECT 'prod', COUNT(*), ROUND(SUM(CAST(SaleValue AS DOUBLE)),2), ROUND(SUM(CAST(Quantity AS DOUBLE)),2) FROM delta_scan('{LH}Fact_Service_Parts_Details')""")

show("Service_Detail 2023+: prod rows / DP rows per year (expect ~2.0)", f"""
    SELECT YEAR(CAST(d.InvoiceDate AS DATE)) y, COUNT(*) dp_rows,
           (SELECT COUNT(*) FROM delta_scan('{LH}Fact_Service_Detail') p WHERE YEAR(CAST(p.InvoiceDate AS DATE)) = YEAR(CAST(d.InvoiceDate AS DATE))) prod_rows
    FROM delta_scan('{DP}Fact_Service_Detail') d WHERE CAST(d.InvoiceDate AS DATE) <= DATE '{LAST}' GROUP BY 1 ORDER BY 1""")

show("Service_Invoices keys only on one side (complete months)", f"""
    WITH d AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, strftime(CAST(InvoiceDate AS DATE),'%Y-%m') ym, ROUND(CAST(TotalNetSales AS DOUBLE),2) v
               FROM delta_scan('{DP}Fact_Service_Invoices') WHERE CAST(InvoiceDate AS DATE) <= DATE '{LAST}'),
         p AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, strftime(CAST(InvoiceDate AS DATE),'%Y-%m') ym, ROUND(CAST(TotalNetSales AS DOUBLE),2) v
               FROM delta_scan('{LH}Fact_Service_Invoices') WHERE CAST(InvoiceDate AS DATE) <= DATE '{LAST}')
    SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT ALL SELECT * FROM p)
    UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT ALL SELECT * FROM d) ORDER BY ym, inv""", limit=60)

show("Parts_Detail line-level differences by year (complete months)", f"""
    WITH d AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, PartNumber pn, CAST(TransDatetime AS DATE) dt, ROUND(CAST(SaleValue AS DOUBLE),2) v
               FROM delta_scan('{DP}Fact_Parts_Detail') WHERE CAST(TransDatetime AS DATE) <= DATE '{LAST}'),
         p AS (SELECT CAST(InvoiceNumber AS VARCHAR) inv, CAST(Branch AS VARCHAR) br, PartNumber pn, CAST(TransDatetime AS DATE) dt, ROUND(CAST(SaleValue AS DOUBLE),2) v
               FROM delta_scan('{LH}Fact_Parts_Detail') WHERE CAST(TransDatetime AS DATE) <= DATE '{LAST}')
    SELECT side, YEAR(dt) y, COUNT(*) n, ROUND(SUM(v),2) sale FROM (
        SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT ALL SELECT * FROM p)
        UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT ALL SELECT * FROM d)) GROUP BY 1,2 ORDER BY 1,2""")

show("lookup_UniqueCustomers_Invoice differences", f"""
    WITH d AS (SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{DP}lookup_UniqueCustomers_Invoice')),
         p AS (SELECT CAST(CustomerNumber AS VARCHAR) c, UniqueCustomerGroup g FROM delta_scan('{LH}lookup_UniqueCustomers_Invoice'))
    SELECT COALESCE(d.c, p.c) c, d.g dp, p.g prod FROM d FULL OUTER JOIN p ON d.c = p.c
    WHERE d.c IS NULL OR p.c IS NULL OR d.g <> p.g ORDER BY 1""")

for t in ("dim_CustomerList", "dim_EngagedAcres", "dim_BranchLocation", "dim_DateTable", "dim_Parts"):
    show(f"{t} row counts", f"SELECT 'dp', COUNT(*) FROM delta_scan('{DP}{t}') UNION ALL SELECT 'prod', COUNT(*) FROM delta_scan('{LH}{t}')")
