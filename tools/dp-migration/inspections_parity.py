"""Inspections parity: DP_Presentation vs production LH_Master_Data.

Complete months only (through the last day of the previous month). Prints
differences with the ones the spec expects already accounted for:
  - LJS hours: NULL-ModifiedDate punches + 11 pre-2023-modified punches on
    2023+ jobs (Decision 1/2) -> 'expected_extra_hrs'
  - WOP: ~14 invoices production lost to its InTrans watermark gap (DP-only)
  - Pending / ServiceRecommendations: snapshot timing
Anything left in 'unexplained' goes to Brian before any change is made.
"""
from datetime import date, timedelta

import duckdb

con = duckdb.connect()
con.sql("SET TimeZone='UTC'; INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.sql("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
DP = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/"
LH = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/"
ST = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/"
LAST = date.today().replace(day=1) - timedelta(days=1)
WOP_START = "2023-10-01"   # first full month after both sides' 3-year cutoffs
print(f"Comparing complete months through {LAST}\n")


def show(title, sql, limit=60):
    rows = con.sql(sql).fetchall()
    cols = [d[0] for d in con.sql(sql).description]
    print(f"=== {title} ({len(rows)} rows)")
    print("  " + " | ".join(cols))
    for r in rows[:limit]:
        print("  " + " | ".join(str(v) for v in r))
    if len(rows) > limit:
        print(f"  ... {len(rows) - limit} more")
    print()


# ---------- Fact_LaborJobSummary ----------
for tag, base in (("dp", DP), ("prod", LH)):
    con.sql(f"""CREATE TABLE ljs_{tag} AS
      SELECT BranchCode, strftime(CAST(WorkOrderCreationDate AS DATE), '%Y-%m') AS ym,
             COUNT(*) AS n, COUNT(*) FILTER (WHERE IsInspection) AS insp,
             COALESCE(SUM(CAST(ActualHoursWorked AS DOUBLE)), 0) AS hrs,
             COALESCE(SUM(CAST(InvoicedLaborAmount AS DOUBLE)), 0) AS labor
      FROM delta_scan('{base}Fact_LaborJobSummary')
      WHERE WorkOrderCreationDate IS NULL OR CAST(WorkOrderCreationDate AS DATE) <= DATE '{LAST}'
      GROUP BY ALL""")
    con.sql(f"""CREATE TABLE ljs_keys_{tag} AS
      SELECT DISTINCT BranchCode, CAST(WorkOrderNumber AS VARCHAR) AS wo, JobCode, JobType,
             strftime(CAST(WorkOrderCreationDate AS DATE), '%Y-%m') AS ym
      FROM delta_scan('{base}Fact_LaborJobSummary')
      WHERE WorkOrderCreationDate IS NULL OR CAST(WorkOrderCreationDate AS DATE) <= DATE '{LAST}'""")

con.sql(f"""CREATE TABLE extra AS
  WITH jobs AS (SELECT DISTINCT Branch, CAST(WorkOrder AS VARCHAR) AS wo, JobCode, JobType
                FROM delta_scan('{ST}Silver_WkOthSub') WHERE ModifiedDate >= TIMESTAMP '2023-01-01'),
       hdr AS (SELECT Branch, CAST(WorkOrder AS VARCHAR) AS wo, CAST(CreatedOn AS DATE) AS created
               FROM delta_scan('{ST}Silver_WkRoFile'))
  SELECT w.Branch AS BranchCode, strftime(h.created, '%Y-%m') AS ym,
         SUM(CAST(w.HoursWorked AS DOUBLE)) AS extra_hrs
  FROM delta_scan('{ST}Silver_WkMechWk') w
  JOIN jobs j ON j.Branch = w.Branch AND j.wo = CAST(w.WorkOrder AS VARCHAR)
             AND j.JobCode = w.JobCode AND j.JobType = w.JobType
  LEFT JOIN hdr h ON h.Branch = w.Branch AND h.wo = CAST(w.WorkOrder AS VARCHAR)
  WHERE w.ModifiedDate IS NULL OR w.ModifiedDate < TIMESTAMP '2023-01-01'
  GROUP BY ALL""")

con.sql("""CREATE TABLE ljs_diff AS
  SELECT COALESCE(d.BranchCode, p.BranchCode) AS br, COALESCE(d.ym, p.ym) AS ym,
         COALESCE(d.n, 0) - COALESCE(p.n, 0) AS d_rows,
         COALESCE(d.insp, 0) - COALESCE(p.insp, 0) AS d_insp,
         ROUND(COALESCE(d.labor, 0) - COALESCE(p.labor, 0), 2) AS d_labor,
         ROUND(COALESCE(d.hrs, 0) - COALESCE(p.hrs, 0), 2) AS d_hrs,
         ROUND(COALESCE(e.extra_hrs, 0), 2) AS expected_extra_hrs,
         ROUND(COALESCE(d.hrs, 0) - COALESCE(p.hrs, 0) - COALESCE(e.extra_hrs, 0), 2) AS unexplained_hrs
  FROM ljs_dp d
  FULL OUTER JOIN ljs_prod p ON d.BranchCode = p.BranchCode AND d.ym IS NOT DISTINCT FROM p.ym
  LEFT JOIN extra e ON e.BranchCode = COALESCE(d.BranchCode, p.BranchCode)
                   AND e.ym IS NOT DISTINCT FROM COALESCE(d.ym, p.ym)""")

show("LJS totals (dp vs prod)", """
  SELECT 'dp' side, SUM(n), SUM(insp), ROUND(SUM(hrs),1), ROUND(SUM(labor),2) FROM ljs_dp
  UNION ALL SELECT 'prod', SUM(n), SUM(insp), ROUND(SUM(hrs),1), ROUND(SUM(labor),2) FROM ljs_prod""")
show("LJS hours delta vs expected (all months)", """
  SELECT ROUND(SUM(d_hrs),1) d_hrs, ROUND(SUM(expected_extra_hrs),1) expected, ROUND(SUM(unexplained_hrs),1) unexplained
  FROM ljs_diff""")
show("LJS by month (all branches)", """
  SELECT ym, SUM(d_rows) d_rows, SUM(d_insp) d_insp, ROUND(SUM(d_labor),2) d_labor,
         ROUND(SUM(d_hrs),1) d_hrs, ROUND(SUM(expected_extra_hrs),1) exp_hrs, ROUND(SUM(unexplained_hrs),1) unexpl_hrs
  FROM ljs_diff GROUP BY ym ORDER BY ym""", limit=200)
show("LJS branch-months with UNEXPLAINED differences", """
  SELECT * FROM ljs_diff
  WHERE d_rows <> 0 OR d_insp <> 0 OR ABS(d_labor) > 0.01 OR ABS(unexplained_hrs) > 0.5
  ORDER BY ym, br""")
show("LJS job keys only in one side, by month", """
  SELECT COALESCE(a.ym, b.ym) ym,
         COUNT(*) FILTER (WHERE b.wo IS NULL) AS dp_only, COUNT(*) FILTER (WHERE a.wo IS NULL) AS prod_only
  FROM ljs_keys_dp a FULL OUTER JOIN ljs_keys_prod b
    ON a.BranchCode = b.BranchCode AND a.wo = b.wo AND a.JobCode = b.JobCode AND a.JobType = b.JobType
  WHERE a.wo IS NULL OR b.wo IS NULL GROUP BY 1 ORDER BY 1""", limit=200)

# ---------- Fact_WorkOrderParts ----------
for tag, base in (("dp", DP), ("prod", LH)):
    con.sql(f"""CREATE TABLE wop_{tag} AS
      SELECT BranchCode, CAST(InvoiceNumber AS VARCHAR) AS inv,
             strftime(CAST(TransactionDate AS DATE), '%Y-%m') AS ym,
             COUNT(*) AS n, SUM(CAST(SaleValue AS DOUBLE)) AS sale, SUM(CAST(Quantity AS DOUBLE)) AS qty
      FROM delta_scan('{base}Fact_WorkOrderParts')
      WHERE CAST(TransactionDate AS DATE) BETWEEN DATE '{WOP_START}' AND DATE '{LAST}'
      GROUP BY ALL""")
show("WOP by month", """
  SELECT COALESCE(d.ym, p.ym) ym, SUM(COALESCE(d.n,0)) - SUM(COALESCE(p.n,0)) d_rows,
         ROUND(SUM(COALESCE(d.sale,0)) - SUM(COALESCE(p.sale,0)), 2) d_sale,
         ROUND(SUM(COALESCE(d.qty,0)) - SUM(COALESCE(p.qty,0)), 2) d_qty
  FROM wop_dp d FULL OUTER JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  GROUP BY 1 ORDER BY 1""", limit=200)
show("WOP invoices only in DP (expect ~14 recovered from prod's watermark gap)", """
  SELECT d.BranchCode, d.inv, d.ym, d.n, ROUND(d.sale,2) FROM wop_dp d
  LEFT JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE p.inv IS NULL ORDER BY d.ym""")
show("WOP invoices only in PROD (expect none)", """
  SELECT p.BranchCode, p.inv, p.ym, p.n, ROUND(p.sale,2) FROM wop_prod p
  LEFT JOIN wop_dp d ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE d.inv IS NULL ORDER BY p.ym""")
show("WOP invoices in both with different lines/amounts", """
  SELECT d.BranchCode, d.inv, d.ym, d.n - p.n d_rows, ROUND(d.sale - p.sale, 2) d_sale
  FROM wop_dp d JOIN wop_prod p ON d.BranchCode = p.BranchCode AND d.inv = p.inv AND d.ym = p.ym
  WHERE d.n <> p.n OR ABS(d.sale - p.sale) > 0.01 ORDER BY d.ym""")

# ---------- Pending + ServiceRecommendations (snapshot tables) ----------
show("Pending counts", f"""
  SELECT 'dp', COUNT(*) FROM delta_scan('{DP}Fact_PendingInspections')
  UNION ALL SELECT 'prod', COUNT(*) FROM delta_scan('{LH}Fact_PendingInspections')""")
show("Pending keys only in one side", f"""
  WITH d AS (SELECT BranchCode, CAST(WorkOrderNumber AS VARCHAR) wo, JobCode FROM delta_scan('{DP}Fact_PendingInspections')),
       p AS (SELECT BranchCode, CAST(WorkOrderNumber AS VARCHAR) wo, JobCode FROM delta_scan('{LH}Fact_PendingInspections'))
  SELECT 'dp_only' side, * FROM (SELECT * FROM d EXCEPT SELECT * FROM p)
  UNION ALL SELECT 'prod_only', * FROM (SELECT * FROM p EXCEPT SELECT * FROM d)""")
show("ServiceRecommendations", f"""
  SELECT 'dp', COUNT(*), SUM(TimesAdded), COUNT(DISTINCT InspectionJobCode) FROM delta_scan('{DP}Fact_ServiceRecommendations')
  UNION ALL SELECT 'prod', COUNT(*), SUM(TimesAdded), COUNT(DISTINCT InspectionJobCode) FROM delta_scan('{LH}Fact_ServiceRecommendations')""")
