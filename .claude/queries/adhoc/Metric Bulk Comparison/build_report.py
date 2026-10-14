"""
METRIC BULK COMPARISON - METRIC HARDWARE PART METRICS (AD HOC)
============================================================================
Request: Ben supplied a list of metric cap screws / bolts (Metric Bulk
Comparison.xlsx - SIZE, LENGTH, PART NO, NOTES; 159 rows, 158 distinct part
numbers - 19M7936 is listed twice) and wants inventory, pricing, and demand
metrics filled in two ways:
  - BY BRANCH tab: one row per Branch x Part (~19 branches per part)
  - METRIC COMPARISON tab: Ben's original sheet, one row per listed part,
    aggregated across all branches

Source: LH_Master_Data lakehouse via DuckDB over OneLake (same pattern as
../kurt-sales/build_report.py and ../franchise-d-zerostock/build_report.py).
  - jdis_Part_Information  - Bin Qty, On Order Qty, Cost, List, Sell Price 1,
                             On Hand Value, Package Qty
  - InTrans_Incremental    - R12/R24 Demands and Sales

DEFINITIONS (confirmed with Brian 2026-09-30):
  - Franchise 'D' only, on both jdis and InTrans. Two non-JD records share
    these part numbers (19M7489 Franchise M @ branch 11, 19M8197 Franchise BS
    @ branch 96) and are excluded.
  - Demands = count of InTrans lines with Type = 'I' AND Qty > 0 (repo-
    standard demand definition, same as dim_PartDemands / Pieces In Set).
  - Sales (units) = SUM(Qty), Sales $ = SUM(SaleValue) over those same lines
    (gross sales - customer returns, i.e. Type 'I' Qty < 0, are not netted).
  - R12 / R24 = rolling 12 / 24 months back from run time.
  - ON HAND VALUE/IN STOCK COST = jdis InventoryCost (actual extended value
    of stock on hand - close to, but not exactly, On Hand Qty x Cost).
  - PACKAGE QUANTITY = jdis PackageQty.
  - jdis carries an occasional duplicate row per Branch+Part (see
    SPI_PiecesInSet_ByBranchPart.pq NOTES) - deduped here, largest on-hand
    row wins.

AGGREGATION (METRIC COMPARISON tab, across branches):
  - BRANCH COUNT = number of branches with a Franchise D jdis record for the
    part (= its row count on BY BRANCH); 0 when not found. Added per Ben's
    review 2026-09-30.
  - Bin Qty, On Order Qty, On Hand Value, Demands, Sales, Sales $ = SUM
  - COST = on-hand-weighted average of standard Cost (SUM(Cost x OnHand) /
    SUM(OnHand)); plain average when nothing is on hand anywhere
  - LIST, SELL PRICE 1, PACKAGE QUANTITY = most common value across branches
    (normally identical everywhere); when branches disagree the DATA NOTE
    column says so and the BY BRANCH tab shows the per-branch values

Parts not found in jdis at all (19M8720, 19M8194 as of 2026-09-30 - also
absent from InTrans and from any SuperTo/SuperFrom link) are kept with blank
metrics and a DATA NOTE.

KNOWN CAVEAT: InTrans_Incremental is missing ~7,101 Aug-2026 transactions
company-wide (see memory: project_prod_intrans_aug2026_gap). R12/R24 may be
slightly understated for these parts until that gap is fixed.

Run manually - not part of any scheduled pipeline. Requires `az login`.
============================================================================
"""

from datetime import date

import duckdb
import pandas as pd
from openpyxl import load_workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

WS_ID = "b48cdb35-7ce3-46de-96df-d70db77649cb"   # LH_Master_Data workspace
LH_ID = "3e74497b-8c51-4a1a-91a1-888c59118f48"   # LH_Master_Data lakehouse
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

in_path = "Metric Bulk Comparison.xlsx"
out_path = f"Metric Bulk Comparison - Filled {date.today():%Y-%m-%d}.xlsx"

ben = pd.read_excel(in_path, dtype={"PART NO": str})
ben = ben[ben["PART NO"].notna()].copy()
ben["PART NO"] = ben["PART NO"].str.strip()
ben["SortOrder"] = range(len(ben))
part_list = ben.drop_duplicates("PART NO")[["PART NO", "SIZE", "LENGTH", "NOTES", "SortOrder"]]
part_list = part_list.rename(columns={"PART NO": "PartNumber"})

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
con.register("plist", part_list)

# ------------------------------------------------------------------
# jdis: one row per Branch + Part (Franchise D), deduped
# ------------------------------------------------------------------
con.execute(f"""
    CREATE TEMP TABLE jdis AS
    SELECT Branch, PartNumber, BinQty, OnOrder, QuantityOnHand, Cost, ListPrice,
           SellPrice1, InventoryCost, TRY_CAST(PackageQty AS DECIMAL(18,2)) AS PackageQty
    FROM (
        SELECT TRIM(j.Branch) AS Branch, TRIM(j.PartNumber) AS PartNumber, j.*
               EXCLUDE (Branch, PartNumber),
               ROW_NUMBER() OVER (PARTITION BY TRIM(j.Branch), TRIM(j.PartNumber)
                                  ORDER BY j.QuantityOnHand DESC, j.InventoryCost DESC) AS rn
        FROM delta_scan('{base}/jdis_Part_Information') j
        JOIN plist p ON TRIM(j.PartNumber) = p.PartNumber
        WHERE j.Franchise = 'D'
    ) WHERE rn = 1
""")

# ------------------------------------------------------------------
# InTrans: R12 / R24 demands and sales per Branch + Part
# ------------------------------------------------------------------
con.execute(f"""
    CREATE TEMP TABLE demand AS
    SELECT TRIM(t.Branch) AS Branch, TRIM(t.PartNumber) AS PartNumber,
           COUNT(*) FILTER (WHERE t.TransDatetime >= now() - INTERVAL 12 MONTH) AS R12Demands,
           COALESCE(SUM(t.Qty)       FILTER (WHERE t.TransDatetime >= now() - INTERVAL 12 MONTH), 0) AS R12Sales,
           COALESCE(SUM(t.SaleValue) FILTER (WHERE t.TransDatetime >= now() - INTERVAL 12 MONTH), 0) AS R12SalesDollars,
           COUNT(*)                     AS R24Demands,
           SUM(t.Qty)                   AS R24Sales,
           SUM(t.SaleValue)             AS R24SalesDollars
    FROM delta_scan('{base}/InTrans_Incremental') t
    JOIN plist p ON TRIM(t.PartNumber) = p.PartNumber
    WHERE t.Franchise = 'D'
      AND t.Type = 'I'
      AND t.Qty > 0
      AND t.TransDatetime >= now() - INTERVAL 24 MONTH
      AND t.TransDatetime <= now()
    GROUP BY ALL
""")

# ------------------------------------------------------------------
# BY BRANCH: full outer join so demand at a branch with no jdis row
# (or vice versa) is never dropped
# ------------------------------------------------------------------
by_branch = con.execute("""
    SELECT p.SortOrder, p.SIZE, p.LENGTH, p.PartNumber, p.NOTES,
           COALESCE(j.Branch, d.Branch) AS Branch,
           j.Branch IS NOT NULL AS InJdis,
           j.BinQty, j.OnOrder, j.QuantityOnHand, j.Cost, j.ListPrice, j.SellPrice1,
           j.InventoryCost, j.PackageQty,
           COALESCE(d.R12Demands, 0) AS R12Demands, COALESCE(d.R12Sales, 0) AS R12Sales,
           COALESCE(d.R12SalesDollars, 0) AS R12SalesDollars,
           COALESCE(d.R24Demands, 0) AS R24Demands, COALESCE(d.R24Sales, 0) AS R24Sales,
           COALESCE(d.R24SalesDollars, 0) AS R24SalesDollars,
           CASE WHEN j.Branch IS NULL AND d.Branch IS NOT NULL THEN 'Demand at branch with no jdis record'
                WHEN j.Branch IS NULL THEN 'Part not found in jdis_Part_Information' END AS DataNote
    FROM plist p
    LEFT JOIN (jdis j FULL OUTER JOIN demand d
               ON j.Branch = d.Branch AND j.PartNumber = d.PartNumber)
        ON p.PartNumber = COALESCE(j.PartNumber, d.PartNumber)
    ORDER BY p.SortOrder, TRY_CAST(regexp_extract(COALESCE(j.Branch, d.Branch), '^[0-9]+') AS INT),
             COALESCE(j.Branch, d.Branch)
""").df()

# ------------------------------------------------------------------
# METRIC COMPARISON: aggregate across branches
# ------------------------------------------------------------------
con.register("bb", by_branch)
agg = con.execute("""
    SELECT PartNumber,
           SUM(BinQty) AS BinQty, SUM(OnOrder) AS OnOrder,
           COALESCE(SUM(Cost * GREATEST(QuantityOnHand, 0)) / NULLIF(SUM(GREATEST(QuantityOnHand, 0)), 0),
                    AVG(Cost)) AS Cost,
           mode(ListPrice) AS ListPrice, mode(SellPrice1) AS SellPrice1,
           SUM(InventoryCost) AS InventoryCost, mode(PackageQty) AS PackageQty,
           SUM(R12Demands) AS R12Demands, SUM(R12Sales) AS R12Sales, SUM(R12SalesDollars) AS R12SalesDollars,
           SUM(R24Demands) AS R24Demands, SUM(R24Sales) AS R24Sales, SUM(R24SalesDollars) AS R24SalesDollars,
           COUNT(*) FILTER (WHERE InJdis) AS Branches,
           COUNT(DISTINCT ListPrice) > 1 OR COUNT(DISTINCT SellPrice1) > 1 AS PriceVaries,
           COUNT(DISTINCT PackageQty) > 1 AS PackVaries
    FROM bb
    GROUP BY PartNumber
""").df()


def agg_note(r):
    if r["Branches"] == 0:
        return "Part not found in jdis_Part_Information"
    notes = []
    if r["PriceVaries"]:
        notes.append("List/Sell Price 1 vary by branch - most common shown, see BY BRANCH")
    if r["PackVaries"]:
        notes.append("Package Qty varies by branch - most common shown")
    return "; ".join(notes) or None


agg["DataNote"] = agg.apply(agg_note, axis=1)
summary = ben.merge(agg, left_on="PART NO", right_on="PartNumber", how="left").sort_values("SortOrder")
summary.loc[summary["Branches"].fillna(0) == 0,
            ["BinQty", "OnOrder", "Cost", "ListPrice", "SellPrice1", "InventoryCost", "PackageQty"]] = None

# ------------------------------------------------------------------
# Output - Ben's column order, BRANCH inserted on the branch tab,
# Sales $ next to each Sales column
# ------------------------------------------------------------------
metric_cols = [
    ("BinQty", "BIN QTY"), ("OnOrder", "ON ORDER QTY"), ("Cost", "COST"), ("ListPrice", "LIST"),
    ("SellPrice1", "SELL PRICE 1"), ("InventoryCost", "ON HAND VALUE/IN STOCK COST"),
    ("PackageQty", "PACKAGE QUANTITY"),
    ("R12Demands", "R12 DEMANDS"), ("R12Sales", "R12 SALES"), ("R12SalesDollars", "R12 SALES $"),
    ("R24Demands", "R24 DEMANDS"), ("R24Sales", "R24 SALES"), ("R24SalesDollars", "R24 SALES $"),
    ("DataNote", "DATA NOTE"),
]
lead = [("SIZE", "SIZE"), ("LENGTH", "LENGTH"), ("PART NO", "PART NO"), ("NOTES", "NOTES")]

# BRANCH COUNT (Ben, round 2): number of branches with a jdis record for the part
summary["Branches"] = summary["Branches"].fillna(0).astype(int)
summary_lead = lead + [("Branches", "BRANCH COUNT")]
summary_out = summary[[c for c, _ in summary_lead + metric_cols]].copy()
summary_out.columns = [h for _, h in summary_lead + metric_cols]

branch_lead = [("SIZE", "SIZE"), ("LENGTH", "LENGTH"), ("PartNumber", "PART NO"),
               ("NOTES", "NOTES"), ("Branch", "BRANCH")]
branch_out = by_branch[[c for c, _ in branch_lead + metric_cols]].copy()
branch_out.columns = [h for _, h in branch_lead + metric_cols]

with pd.ExcelWriter(out_path, engine="openpyxl") as xw:
    summary_out.to_excel(xw, sheet_name="METRIC COMPARISON", index=False)
    branch_out.to_excel(xw, sheet_name="BY BRANCH", index=False)

money = {"COST", "LIST", "SELL PRICE 1", "ON HAND VALUE/IN STOCK COST", "R12 SALES $", "R24 SALES $"}
wb = load_workbook(out_path)
for ws in wb.worksheets:
    headers = [c.value for c in ws[1]]
    for i, h in enumerate(headers, start=1):
        cell = ws.cell(row=1, column=i)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="367C2B")
        cell.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
        fmt = "$#,##0.00" if h in money else ("#,##0" if h not in {"SIZE", "PART NO", "NOTES", "BRANCH", "DATA NOTE"} else None)
        if fmt:
            for row in ws.iter_rows(min_row=2, min_col=i, max_col=i):
                row[0].number_format = fmt
        ws.column_dimensions[get_column_letter(i)].width = 45 if h == "DATA NOTE" else max(10, min(len(str(h)) + 2, 16))
    ws.row_dimensions[1].height = 32
    ws.freeze_panes = "D2" if ws.title == "METRIC COMPARISON" else "F2"
    ws.auto_filter.ref = ws.dimensions
wb.save(out_path)

print(f"METRIC COMPARISON rows: {len(summary_out)} ({summary_out['PART NO'].nunique()} distinct parts)")
print(f"BY BRANCH rows: {len(branch_out)}  (avg {len(branch_out) / part_list.shape[0]:.1f} branches/part)")
print("Not found in jdis:", sorted(agg.loc[agg['Branches'] == 0, 'PartNumber']))
print("Price varies:", sorted(agg.loc[agg['PriceVaries'], 'PartNumber']))
print("Branch rows with demand but no jdis record:", int((by_branch['DataNote'] == 'Demand at branch with no jdis record').sum()))
print(f"Totals - Bin {branch_out['BIN QTY'].sum():,.0f}, OnHandValue ${branch_out['ON HAND VALUE/IN STOCK COST'].sum():,.2f}, "
      f"R12 Dem {branch_out['R12 DEMANDS'].sum():,}, R24 Dem {branch_out['R24 DEMANDS'].sum():,}, R24 $ {branch_out['R24 SALES $'].sum():,.2f}")
print(f"Wrote {out_path}")
