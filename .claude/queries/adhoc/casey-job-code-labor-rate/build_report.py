"""
JOB CODES ON AN OLD LABOR RATE (AD HOC) — for Casey
============================================================================
Request: Casey (service) needs to find job codes that are still quoting an
outdated labor rate. His method: pull up a job code in Job Code Maintenance,
divide its Labor Charges by its Estimated Hours, and see if the resulting
$/hr looks stale vs. the shop's current labor rate. Example he gave:
/10-020030-F-00001 -> Est Hours 3.25, Labor Charges $341.25 -> $105.00/hr.

Investigation finding (2026-08-12): The $ field Casey is reading in Job Code
Maintenance is WkCodeFl.LABOUR_COST — confirmed by direct match against his
example (LABOUR_COST 341.25 / EST_HOURS 3.25 = 105.00). This field is NOT
currently pulled into the Lakehouse: the existing dim_JobCodes dataflow
(.claude/queries/raw-tables/WkCodeFl.pq) extracts 13 of ~46 source columns
and LABOUR_COST isn't one of them. So this is queried directly from the
source system via ODBC (dsn=EquipRDB64), same as Job Code Maintenance itself
reads it — not from the Lakehouse.

LABOUR_COST appears to be a static value baked in at job-code-creation/last-
edit time (EstHours x the labor rate in effect then). If the shop's labor
rate goes up later and a job code's LABOUR_COST is never recalculated, that
job code keeps quoting the old rate indefinitely — that's the bug Casey is
hunting for.

Grain note: WkCodeFl has one row per full branch/model-specific CODE (e.g.
/10-020030-F-0000101 through -0000121 are all "ENGINE ROCKER ARM COVER
GASKET REPLACE" for different tractor models), grouped under a canonical
FACTORY_CODE. In every case checked, EST_HOURS and LABOUR_COST are identical
across all variants of the same FactoryCode — so a FactoryCode-level view
collapses ~558K rows down to the distinct set of actual job types, which is
much more usable for a manual review. Delivered both, per Brian's request.

SECOND FINDING (2026-08-12, discovered while scoping this pull): 86.5% of
WkCodeFl rows (493,555 of 570,396) have a NULL ModifiedDate. The production
dim_JobCodes dataflow (.claude/queries/raw-tables/WkCodeFl.pq) filters WHERE
ModifiedDate >= 2023-01-01, which only catches the 13.5% of job codes that
have been touched since 2023 — every job code nobody has edited since
creation (NULL ModifiedDate) is silently excluded from the Lakehouse today.
That's a real bug in that dataflow, independent of this ad hoc request, and
it means we CANNOT scope this pull the same way — doing so would exclude
exactly the untouched, likely-stale-rate job codes Casey is looking for. So
this pulls the full table instead, with no date filter.

Output: "Job Codes - Labor Rate Review.xlsx"
- All Job Codes tab: one row per full CODE (branch/model variant), sorted by
  Labor Rate ascending so the lowest/oldest-looking rates are at the top.
- By Job Type tab: DISTINCT FactoryCode x EstHours x LaborCharges combos
  (collapses identical model variants; if a FactoryCode's variants actually
  disagree on hours/cost, both combos are kept as separate rows rather than
  averaged away). Excludes ~35K rows where FACTORY_CODE is blank/NULL —
  legacy free-text job entries that aren't real structured codes, same
  exclusion the production WkCodeFl.pq dataflow already documents.
- Rows with EST_HOURS <= 0 or NULL are excluded from both tabs (no
  computable rate) — count reported at the end of the run.
- Rows with LaborCharges = 0 are NOT excluded (full list, as requested) —
  but note these aren't meaningful "old rate" signal, just unpriced job
  codes. They sort to the very top of the ascending view; the real signal
  starts once you're past that small cluster (~12 rows in the By Job Type
  tab as of this run). Current shop rate looks to be clustered around
  $152.50/hr based on the median across all priced job types.

THIRD FINDING (2026-08-12): Multiple attempts to fetch a large row set in one
shot from WkCodeFl all hung (full 570K-row unfiltered table via
pandas.read_sql, same via raw pyodbc; even the deduped 35,728-row DISTINCT
set hung on fetchall()) — while every *small* fetch (TOP 10, DISTINCT TOP
100) and every server-side aggregate (COUNT, COUNT of the DISTINCT set) came
back in under a second. So the bottleneck is specifically fetch *volume* in
a single round trip over this ODBC driver/environment, not query complexity,
DISTINCT, or general source-system congestion (a COUNT of the exact same
DISTINCT set was instant while pulling its rows hung). Workaround: paginate
with SQL Anywhere's `SELECT TOP n START AT m ... ORDER BY` and stitch
batches together client-side — each batch is small enough to hit the fast
path proven above.

Run manually — not part of any scheduled pipeline. Always run ad hoc pulls
against this source under an OS-level hard timeout (e.g. `timeout 300 python
build_report.py`) so a stall fails loud instead of hanging silently.
============================================================================
"""

import re
import pyodbc
import pandas as pd

out_path = "Job Codes - Labor Rate Review.xlsx"
BATCH_SIZE = 2000

# openpyxl rejects XML-illegal control characters (e.g. some source Description
# fields contain stray control bytes). Strip anything outside the allowed XML
# 1.0 character ranges rather than let the whole workbook write fail.
_ILLEGAL_XLSX_CHARS = re.compile(
    "[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]"
)


def clean_text(val):
    if isinstance(val, str):
        return _ILLEGAL_XLSX_CHARS.sub("", val)
    return val


def paginated_fetch(cur, sql_builder, batch_size, label):
    """Fetch a large result set in small batches via SQL Anywhere TOP/START AT
    pagination — a single large fetchall() hangs on this ODBC driver/env
    (see THIRD FINDING), but small batches are fast and reliable."""
    all_rows = []
    cols = None
    start_at = 1
    batch_num = 0
    while True:
        batch_num += 1
        cur.execute(sql_builder(batch_size, start_at))
        if cols is None:
            cols = [d[0] for d in cur.description]
        batch = cur.fetchall()
        print(f"[{label}] batch {batch_num} (rows {start_at}-{start_at + len(batch) - 1}): {len(batch)} rows")
        if not batch:
            break
        all_rows.extend(batch)
        if len(batch) < batch_size:
            break
        start_at += batch_size
    return pd.DataFrame.from_records(all_rows, columns=cols)


cnxn = pyodbc.connect("dsn=EquipRDB64", timeout=30)
cur = cnxn.cursor()

# ------------------------------------------------------------------
# All Job Codes: full CODE grain, no dedup (CODE is the natural key)
# ------------------------------------------------------------------
def all_codes_sql(n, start_at):
    return f"""
        SELECT TOP {n} START AT {start_at}
            CODE         AS JobCode,
            DESCRIPTION  AS Description,
            PART_BRANCH  AS Branch,
            EST_HOURS    AS EstimatedHours,
            LABOUR_COST  AS LaborCharges
        FROM WkCodeFl
        ORDER BY CODE, PART_BRANCH
    """

all_codes_raw = paginated_fetch(cur, all_codes_sql, BATCH_SIZE, "All Job Codes")
print(f"Total rows pulled (All Job Codes): {len(all_codes_raw)}")

# ------------------------------------------------------------------
# By Job Type: canonical FactoryCode, deduped server-side via SELECT DISTINCT.
# Excludes blank/NULL FactoryCode (legacy free-text entries, not real codes).
# ------------------------------------------------------------------
def by_type_sql(n, start_at):
    return f"""
        SELECT DISTINCT TOP {n} START AT {start_at}
            FACTORY_CODE AS FactoryCode,
            DESCRIPTION  AS Description,
            EST_HOURS    AS EstimatedHours,
            LABOUR_COST  AS LaborCharges
        FROM WkCodeFl
        WHERE FACTORY_CODE IS NOT NULL AND FACTORY_CODE <> ''
        ORDER BY FactoryCode, Description, EstimatedHours, LaborCharges
    """

by_type_raw = paginated_fetch(cur, by_type_sql, BATCH_SIZE, "By Job Type")
print(f"Total rows pulled (By Job Type): {len(by_type_raw)}")

cur.close()
cnxn.close()


def add_rate(df):
    df = df.copy()
    df["EstimatedHours"] = df["EstimatedHours"].astype(float)
    df["LaborCharges"] = df["LaborCharges"].astype(float)
    no_hours = (df["EstimatedHours"] <= 0) | df["EstimatedHours"].isna()
    print(f"  Excluded (EstimatedHours <= 0 or NULL, no computable rate): {no_hours.sum()}")
    df = df[~no_hours].copy()
    df["LaborRate"] = (df["LaborCharges"] / df["EstimatedHours"]).round(2)
    return df.sort_values("LaborRate", ascending=True).reset_index(drop=True)


all_codes = add_rate(all_codes_raw)[["JobCode", "Description", "Branch", "EstimatedHours", "LaborCharges", "LaborRate"]]
by_type = add_rate(by_type_raw)[["FactoryCode", "Description", "EstimatedHours", "LaborCharges", "LaborRate"]]

print(f"All Job Codes tab rows: {len(all_codes)}")
print(f"By Job Type tab rows: {len(by_type)}")

for df in (all_codes, by_type):
    for col in df.select_dtypes(include="object").columns:
        df[col] = df[col].map(clean_text)

with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
    all_codes.to_excel(writer, sheet_name="All Job Codes", index=False)
    by_type.to_excel(writer, sheet_name="By Job Type", index=False)

print(f"Saved: {out_path}")
