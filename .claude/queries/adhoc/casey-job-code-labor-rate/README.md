# Job Codes on an Old Labor Rate — ad hoc pull for Casey

**Request:** Casey (service) needs to find job codes still quoting an outdated
labor rate. His method: open a job code in Job Code Maintenance, divide its
Labor Charges by its Estimated Hours, and see if the resulting $/hr looks
stale. Example he gave: `/10-020030-F-00001` → Est Hours 3.25, Labor Charges
$341.25 → $105.00/hr.

**Deliverable:** `Job Codes - Labor Rate Review.xlsx` — 2 tabs:
- **All Job Codes** (560,386 rows) — one row per full branch/model-specific
  job code, exactly like Job Code Maintenance shows them.
- **By Job Type** (34,922 rows) — deduped to one row per canonical job type
  (`FactoryCode`), since every branch/model variant of the same job carries
  identical hours and labor charges. Much easier to actually scan.

Both sorted by Labor Rate ascending. No threshold filter applied — full list,
per Brian's call, so the low end is visible without guessing a cutoff.

## What the numbers mean

- Current shop labor rate looks to be **~$152.50/hr** (median across all
  priced job types).
- A real population of job codes sits well below that — **$105/hr, $75/hr**,
  and other older tiers — exactly the kind of stale-rate codes Casey is
  hunting for. These are the rows to start with.
- A small number of rows (~12 in By Job Type) have `LaborCharges = 0`. These
  aren't "old rate" — they're job codes that were never priced at all. Left
  in the sheet since Casey asked for the full list, but they're a different
  issue and sort to the very top; skip past them.

## Where the data lives (and why this wasn't a Lakehouse query)

The $ field Casey reads in Job Code Maintenance is `WkCodeFl.LABOUR_COST` —
confirmed by exact match against his example (`341.25 / 3.25 = 105.00`).

This field is **not currently pulled into the Lakehouse**. The existing
`dim_JobCodes` dataflow (`.claude/queries/raw-tables/WkCodeFl.pq`) extracts
13 of ~46 available source columns, and none of them are dollar fields. So
this was queried directly from the source system (`dsn=EquipRDB64`,
`WkCodeFl` table) via `pyodbc`, the same place Job Code Maintenance itself
reads from — not the DuckDB/OneLake pattern used for Lakehouse-resident data
(see `.claude/queries/adhoc/kurt-sales/` for that pattern).

`LABOUR_COST` appears to be a static value baked in at job-code
creation/last-edit time (hours × the labor rate in effect then). If the
shop's labor rate increases later and a job code is never touched again,
it keeps quoting the old rate indefinitely — that's the mechanism behind
the bug Casey is chasing.

## Two other findings surfaced during this investigation

**1. `dim_JobCodes` is silently missing ~86.5% of job codes.**
493,555 of 570,396 rows in `WkCodeFl` have a **NULL `ModifiedDate`**. The
production `dim_JobCodes` dataflow filters `WHERE ModifiedDate >= 2023-01-01`
— which only captures the 13.5% of job codes touched since 2023. Every job
code nobody has edited since creation (the majority, and the ones most
likely to carry a stale rate) never makes it into the Lakehouse today. This
is a real bug in that dataflow, independent of Casey's request, and is why
this pull couldn't be scoped the same way the production dataflow is. Worth
fixing on its own — likely needs either a full-refresh fallback or an
`ModifiedDate IS NULL OR ModifiedDate >= RangeStart` condition.

**2. Fetching a large row set in one shot hangs on this ODBC driver/env.**
Two early attempts to pull the full table unfiltered (once via
`pandas.read_sql`, once via raw `pyodbc.fetchall()` with a larger
`arraysize`) both hung — the second for the full 10-minute hard timeout.
Even a deduped 35K-row `SELECT DISTINCT` fetch hung, while a `COUNT(*)` of
that exact same set returned in under a second. So the bottleneck is
specifically **fetch volume in a single round trip**, not query complexity,
`DISTINCT`, or general source congestion. Workaround used here: paginate
with SQL Anywhere's `SELECT TOP n START AT m ... ORDER BY` in 2,000-row
batches and stitch them together client-side — proven fast and reliable
(the full 570K-row pull completed in a few minutes this way). Worth reusing
this pagination pattern for any future large ad hoc pull against
`EquipRDB64`, not just this one.

**Also fixed along the way:** the source stores blank job codes as empty
string (`''`) rather than `NULL` for some legacy free-text entries, and the
ODBC driver converts `''` to `NULL` on fetch — so `WHERE FACTORY_CODE IS NOT
NULL` alone didn't filter them out server-side. Added `AND FACTORY_CODE <>
''` to actually exclude them from the By Job Type tab.

## Running it again

`build_report.py` — run manually, not part of any scheduled pipeline.
Always wrap in an OS-level hard timeout (`timeout 600 python
build_report.py`) given the fetch-hang risk above. Takes ~7-8 minutes for
the full pull (mostly the 286-batch All Job Codes tab).
