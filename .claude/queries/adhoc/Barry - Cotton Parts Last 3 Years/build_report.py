"""
COTTON PARTS - LAST 3 YEARS OF SALES (AD HOC) - for Barry
============================================================================
Request (2026-10-22): Barry supplied a list of cotton part numbers (Cotton
Parts Last 3 Years.xlsx, column "Part") and wants, per part:
  Description, # Locations, and units sold in three NON-overlapping
  12-month buckets: Mo 1-12, Mo 13-24, Mo 25-36.
A previous version of this sheet used cumulative windows (Last 24 = months
1-24, Last 36 = months 1-36). Here each bucket covers only its own 12 months.

Barry's workbook has several tabs of part lists ("All Cotton Parts" = the
master list, "0 Demands Removed" = his trimmed list, added 2026-10-22). Every
tab is filled and written as a tab of the same name in ONE output workbook,
in Barry's tab and row order, plus a Notes tab. New tabs are picked up
automatically as long as they have a "Part" column.

Source: DP_Presentation (Prod) lakehouse via DuckDB over OneLake
(Silver_PartInformation and Silver_InTrans through DP_Presentation's
shortcuts, dim_Parts for the description).

DEFINITIONS
  - Franchise 'D' only.
  - Description = dim_Parts.Description (most common description across
    branches); falls back to the most common Silver_PartInformation one.
  - # Locations = branches with a Franchise D part record.
  - # Locations On Hand = of those, branches with QuantityOnHand > 0.
  - Sales (units) = SUM(Qty) of InTrans Type 'I' lines, net of customer
    returns (Type 'I' with Qty < 0).
  - Buckets are rolling 12 months back from the run date:
      Mo 1-12  = (today - 12 mo, today]
      Mo 13-24 = (today - 24 mo, today - 12 mo]
      Mo 25-36 = (today - 36 mo, today - 24 mo]
  - Part numbers are compared trimmed (Equip pads text).

Parts with no part record and no sales are kept with a DATA NOTE.

Run manually - not part of any scheduled pipeline. Requires `az login`:
    timeout 600 python build_report.py
============================================================================
"""

from datetime import date

import duckdb
import pandas as pd
from openpyxl import load_workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

WS_ID = "7836042d-adb1-4846-b70d-bd42980054c5"  # DP - Presentation - Prod
LH_ID = "29d9df80-a383-4d40-9807-1e2e6cbff88f"  # DP_Presentation (Prod)
base = f"abfss://{WS_ID}@onelake.dfs.fabric.microsoft.com/{LH_ID}/Tables"

in_path = "Cotton Parts Last 3 Years.xlsx"
out_path = f"Cotton Parts Last 3 Years - Filled {date.today():%Y-%m-%d}.xlsx"

# Every tab of Barry's workbook that has a Part column, in his tab order
tabs = {}
for name, df in pd.read_excel(in_path, sheet_name=None, dtype={"Part": str}).items():
    if "Part" not in df.columns:
        continue
    parts = df["Part"].dropna().str.strip()
    tabs[name] = parts[parts != ""].drop_duplicates().tolist()
plist = pd.DataFrame({"PartNumber": sorted({p for ps in tabs.values() for p in ps})})

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure; SET TimeZone='UTC';")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
con.register("plist", plist)

# ------------------------------------------------------------------
# Part master: locations + fallback description
# ------------------------------------------------------------------
con.execute(f"""
    CREATE TEMP TABLE pm AS
    SELECT TRIM(i.PartNumber) AS PartNumber,
           COUNT(DISTINCT TRIM(i.Branch)) AS Locations,
           COUNT(DISTINCT TRIM(i.Branch)) FILTER (WHERE i.QuantityOnHand > 0) AS LocationsOnHand,
           mode(NULLIF(TRIM(i.Description), '')) AS PmDescription
    FROM delta_scan('{base}/Silver_PartInformation') i
    JOIN plist p ON TRIM(i.PartNumber) = p.PartNumber
    WHERE i.Franchise = 'D'
    GROUP BY 1
""")

con.execute(f"""
    CREATE TEMP TABLE dp AS
    SELECT TRIM(d.PartNumber) AS PartNumber, MIN(NULLIF(TRIM(d.Description), '')) AS Description
    FROM delta_scan('{base}/dim_Parts') d
    JOIN plist p ON TRIM(d.PartNumber) = p.PartNumber
    GROUP BY 1
""")

# ------------------------------------------------------------------
# InTrans: net units sold in three non-overlapping 12-month buckets
# ------------------------------------------------------------------
con.execute(f"""
    CREATE TEMP TABLE sales AS
    SELECT TRIM(t.PartNumber) AS PartNumber,
           COALESCE(SUM(t.Qty) FILTER (WHERE t.TransDatetime >  now() - INTERVAL 12 MONTH), 0) AS Mo1_12,
           COALESCE(SUM(t.Qty) FILTER (WHERE t.TransDatetime <= now() - INTERVAL 12 MONTH
                                         AND t.TransDatetime >  now() - INTERVAL 24 MONTH), 0) AS Mo13_24,
           COALESCE(SUM(t.Qty) FILTER (WHERE t.TransDatetime <= now() - INTERVAL 24 MONTH), 0) AS Mo25_36
    FROM delta_scan('{base}/Silver_InTrans') t
    JOIN plist p ON TRIM(t.PartNumber) = p.PartNumber
    WHERE t.Franchise = 'D'
      AND t.Type = 'I'
      AND t.TransDatetime >  now() - INTERVAL 36 MONTH
      AND t.TransDatetime <= now()
    GROUP BY 1
""")

filled = con.execute("""
    SELECT p.PartNumber AS "Part",
           COALESCE(dp.Description, pm.PmDescription) AS "Description",
           COALESCE(pm.Locations, 0) AS "# Locations",
           COALESCE(pm.LocationsOnHand, 0) AS "# Locations On Hand",
           COALESCE(s.Mo1_12, 0) AS "Mo 1-12 Sales",
           COALESCE(s.Mo13_24, 0) AS "Mo 13-24 Sales",
           COALESCE(s.Mo25_36, 0) AS "Mo 25-36 Sales",
           COALESCE(s.Mo1_12 + s.Mo13_24 + s.Mo25_36, 0) AS "36 Mo Total",
           CASE WHEN pm.PartNumber IS NULL AND s.PartNumber IS NULL THEN 'Not found in part master or sales'
                WHEN pm.PartNumber IS NULL THEN 'Sales but no Franchise D part record' END AS "Data Note"
    FROM plist p
    LEFT JOIN pm ON pm.PartNumber = p.PartNumber
    LEFT JOIN dp ON dp.PartNumber = p.PartNumber
    LEFT JOIN sales s ON s.PartNumber = p.PartNumber
""").df().set_index("Part")

# One output tab per input tab, in Barry's row order
outputs = {name: filled.loc[parts].reset_index() for name, parts in tabs.items()}

today = date.today()
periods = pd.DataFrame({
    "Bucket": ["Mo 1-12", "Mo 13-24", "Mo 25-36"],
    "From (after)": [today - pd.DateOffset(months=m) for m in (12, 24, 36)],
    "To (through)": [today - pd.DateOffset(months=m) for m in (0, 12, 24)],
})
periods["From (after)"] = periods["From (after)"].dt.date
periods["To (through)"] = periods["To (through)"].dt.date
notes = pd.DataFrame({"Notes": [
    "Each bucket covers only its own 12 months (not cumulative).",
    "Sales = units sold on parts invoices (InTrans Type I), net of customer returns. Franchise D only.",
    "# Locations = branches with a part record for the part; # Locations On Hand = of those, branches with stock on hand.",
    "Description = most common description across branches.",
    "Each tab is the part list from the tab of the same name in Barry's workbook.",
    f"Run date {today:%Y-%m-%d}; source DP_Presentation (Prod).",
]})

with pd.ExcelWriter(out_path, engine="openpyxl") as xw:
    for name, df in outputs.items():
        df.to_excel(xw, sheet_name=name, index=False)
    periods.to_excel(xw, sheet_name="Notes", index=False)
    notes.to_excel(xw, sheet_name="Notes", index=False, startrow=len(periods) + 2)

wb = load_workbook(out_path)
for name in outputs:
    ws = wb[name]
    for i, h in enumerate([c.value for c in ws[1]], start=1):
        cell = ws.cell(row=1, column=i)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill("solid", fgColor="367C2B")
        cell.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
        if h not in {"Part", "Description", "Data Note"}:
            for row in ws.iter_rows(min_row=2, min_col=i, max_col=i):
                row[0].number_format = "#,##0"
        ws.column_dimensions[get_column_letter(i)].width = {"Description": 32, "Data Note": 38}.get(h, 14)
    ws.row_dimensions[1].height = 32
    ws.freeze_panes = "C2"
    ws.auto_filter.ref = ws.dimensions
nws = wb["Notes"]
for col, w in zip("ABC", (60, 14, 14)):
    nws.column_dimensions[col].width = w
wb.save(out_path)

for name, df in outputs.items():
    print(f"{name}: {len(df)} parts, not found {df['Data Note'].notna().sum()}, "
          f"totals {df['Mo 1-12 Sales'].sum():,.0f} / {df['Mo 13-24 Sales'].sum():,.0f} / {df['Mo 25-36 Sales'].sum():,.0f}")
print(periods.to_string(index=False))
print(f"Wrote {out_path}")
