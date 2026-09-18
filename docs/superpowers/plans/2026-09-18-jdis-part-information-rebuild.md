# `jdis_Part_Information` Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Build_Silver_PartInformation.Notebook`'s dependency on two unmanaged, unscheduled Dataflow Gen2 items (which query the live source system directly via ODBC) with a proper rebuild sourced from JD Bronze shortcuts — bringing this table fully into the managed, git-tracked, scheduled architecture the rest of the DP backend already uses.

**Architecture:** Four new OneLake shortcuts in `DP - Staging - Dev` (`InManuf`, `InManuf_Locale`, `INHIST_MONTH_4_PI`, `InHistMQT`), joined against the existing `InMaster`/`Branch_Name` shortcuts to faithfully reproduce the ~33 columns the old dataflows selected. The notebook is rewritten in place (same name, same notebook ID) so no config or pipeline changes are needed — it's already wired into `dp_backend_scope.json` and all three refresh pipelines.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification, `fab` CLI.

**Reference:** `docs/superpowers/specs/2026-09-18-jdis-part-information-rebuild-design.md` — the approved design this plan implements.

---

## Real facts this plan relies on (verified 2026-09-18, not assumed)

- **JD Bronze mirror location** (already used by every other shortcut in this project): workspace `JD_FabricOneLake` (`4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`), lakehouse `JD_EquipRDB_Production_Bronze` (`7348c3a6-8694-4d11-bc70-1bd55be84ea2`).
- **`DP_Staging` lakehouse** (where the new shortcuts and the rebuilt notebook live): workspace `DP - Staging - Dev` (`ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`), lakehouse `DP_Staging` (`876255e0-d462-4697-adc1-4a655f5bb101`).
- **Real Bronze column names for all 4 new tables** (queried directly via DuckDB `DESCRIBE`, 2026-09-18 — do not re-derive, use these exact names/casing in code):
  - `InManuf` (42 cols) / `InManuf_Locale` (41 cols): join key `FR` + `PART_NO`. Relevant columns: `FR`, `PART_NO`, `commodity_code`, `return_indicator`, `UNIT_PACK_QTY`, `UNIT_WEIGHT`.
  - `INHIST_MONTH_4_PI` (186 cols): join key `BRANCH` + `FRANCHISE` + `PART_NO`. Relevant columns: `PI_CURRENT_12_MO_SALES`, `PI_PREVIOUS_12_MO_SALES` (already pre-computed — a simple join, no aggregation needed for these two).
  - `InHistMQT` (12 cols): `BRANCH`, `FRANCHISE`, `PART_NO`, `MM_YYYY`, `DATEHIST`, `SAL_QTY`, `REQ_CNT`, `SAL_VAL`, `LOST_CNT`, `LOST_VAL`, `LOST_QTY`, `SALES_ACTIVITY_CNT`. Needed for `Current12MoDollars`/`Previous12MoDollars` — real rolling-12-month `SUM(SAL_VAL)`, grouped by `(BRANCH, FRANCHISE, PART_NO)`.
  - `InMaster` (73 cols, already shortcut): confirmed real columns include `BIN_LOCATION`, `BULK_BIN`, `dealer_group_code`, `Pending_Qty`, `ON_HAND_VAL`, `VENDOR_CODE`, `STOCKTAKE_DATE` — none of these are in the existing `Silver_InMaster` table's narrower 20-column selection, confirming the rebuild must read `InMaster.Shortcut` directly, not through `Silver_InMaster`.
  - `Branch_Name` (105 cols, already shortcut): confirmed real column `FR_LOC_INDICATOR` lives here (not on `InMaster`/`InManuf`) — join key `branch` = `InMaster.BRANCH`. This flag decides whether a part's manufacturer-level fields come from `InManuf_Locale` or `InManuf`.

- **Real finding (Task 2, 2026-09-18): `InManuf_Locale` is completely empty (0 rows) in
  live Bronze data, and all 99 real branches have `FR_LOC_INDICATOR = 'N'`** — the
  locale-pricing path is entirely dormant in this business's current real data.
  Task 5's code below uses a `coalesce(when(flag='Y', locale_value), standard_value,
  default)` pattern rather than a strict either/or `CASE`, so it produces identical
  output to a strict `CASE` for all of today's real data (flag is always 'N', so it
  always falls through to `InManuf`), but gracefully degrades to `InManuf`'s value
  instead of silently going blank if a future branch ever gets `FR_LOC_INDICATOR='Y'`
  without matching `InManuf_Locale` data. Confirmed via direct query, not assumed —
  do not re-verify.
- **Confirmed via `git grep`:** the current notebook's `ActivityTier` column (a marker of which of the two old dataflows a row came from) has zero downstream consumers — safe to drop entirely in the rebuild.
- **Real sample parts with non-zero sales** (from the current, still-ODBC-sourced `Silver_PartInformation` table, queried 2026-09-18 — use these exact values as the verification target in Task 4, since they reflect genuinely correct production data from the live source):

  | Branch | PartNumber | Franchise | QuantityOnHand | Current12MoSales | Current12MoDollars | Previous12MoSales | Previous12MoDollars | VendorCode | ListPrice |
  |---|---|---|---|---|---|---|---|---|---|
  | 13 | PK11 | M | 0 | 1 | 1491.31 | 4 | 5544.40 | 1114 | 1491.31 |
  | 15 | 341-645 | SC | 0 | 1 | 185.23 | 1 | 170.88 | 1661 | 185.23 |
  | 3 | VAK1 | M | 0 | 2 | 174.90 | 1 | 79.76 | 10517 | 75.04 |
  | 3 | 221228 | RM | 0 | 2 | 66.50 | 1 | 28.59 | 417 | 33.25 |
  | 8 | 9RNJA | M | 0 | 18 | 1219.44 | 9 | 441.70 | 12220 | 66.05 |

- **Real, complete simple-column mapping** (`pi_X AS Y` pairs from `df_JDIS_PartInformation_Active_Raw.Dataflow/mashup.pq`, cross-referenced against the view's real `ALTER VIEW` SQL and the Bronze column names above):

  | Output column | Source |
  |---|---|
  | `Branch` | `InMaster.BRANCH` |
  | `PartNumber` | `InMaster.PART_NO` |
  | `Description` | `InMaster.PART_DESC` |
  | `Franchise` | `InMaster.FRANCHISE` |
  | `Source` | `InMaster.CATEGORY` (empty string if null/blank) |
  | `SLC` | `InMaster.SALES_CLASS` (empty string if null/blank) |
  | `CommodityCode` | `InManuf_Locale.commodity_code` if `Branch_Name.FR_LOC_INDICATOR = 'Y'` else `InManuf.commodity_code` |
  | `DealerGroupCode` | `InMaster.dealer_group_code` (empty string if null/blank) |
  | `QuantityOnHand` | `InMaster.ON_HAND_QTY` (0 if null) |
  | `BinQty` | **computed**: `ON_HAND_QTY + BULK_BIN_QTY - IN_TRANSIT_QTY - Pending_Qty` (each 0 if null) |
  | `BulkBinQty` | `InMaster.BULK_BIN_QTY` (0 if null) |
  | `PendingQty` | `InMaster.Pending_Qty` (0 if null) |
  | `BackOrderQty` | `InMaster.BACK_ORD_QTY` (0 if null) |
  | `BulkBin` | `InMaster.BULK_BIN` (empty string if null/blank) |
  | `Bin` | `InMaster.BIN_LOCATION` (empty string if null/blank) |
  | `PackageQty` | `InManuf_Locale.UNIT_PACK_QTY` if `FR_LOC_INDICATOR = 'Y'` else `InManuf.UNIT_PACK_QTY` |
  | `Returnable` | `InManuf_Locale.return_indicator` if `FR_LOC_INDICATOR = 'Y'` else `InManuf.return_indicator` |
  | `Weight` | `InManuf_Locale.UNIT_WEIGHT` if `FR_LOC_INDICATOR = 'Y'` else `InManuf.UNIT_WEIGHT` (0 if null) |
  | `OnOrder` | `InMaster.OS_ORDER_QTY` (0 if null) |
  | `SuperTo` | `InMaster.SUPER_TO` (empty string if null) |
  | `SuperFrom` | `InMaster.SUPER_FROM` (empty string if null) |
  | `InventoryCost` | `InMaster.ON_HAND_VAL` (0 if null) |
  | `Cost` | `InMaster.REPLACE_PRICE` (0 if null) |
  | `SellPrice1` | `InMaster.SELL_PRICE1` (0 if null) |
  | `ListPrice` | `InMaster.LIST_PRICE` (0 if null) |
  | `Current12MoSales` | `INHIST_MONTH_4_PI.PI_CURRENT_12_MO_SALES` (0 if null/no match) |
  | `Current12MoDollars` | **aggregated**: `SUM(InHistMQT.SAL_VAL)` for the trailing 12 months ending this month, same `(BRANCH,FRANCHISE,PART_NO)` |
  | `Previous12MoSales` | `INHIST_MONTH_4_PI.PI_PREVIOUS_12_MO_SALES` (0 if null/no match) |
  | `Previous12MoDollars` | **aggregated**: `SUM(InHistMQT.SAL_VAL)` for the 12 months before that (months -24 to -13) |
  | `VendorCode` | `InMaster.VENDOR_CODE` (0 if null) |
  | `DateCreated` | `InMaster.CREATION_DATE` (`1900-01-01` if null) |
  | `DateLastRequested` | `InMaster.LAST_DEM_DATE` (`1900-01-01` if null) |
  | `StocktakeDate` | `InMaster.STOCKTAKE_DATE` (`1900-01-01` if null) |

  **This mapping is the plan's own best derivation from the real view SQL — it must be
  independently verified against real data in Task 4 before being trusted in the
  notebook (Task 5). Do not skip Task 4.**

---

### Task 1: Brian creates the 4 new OneLake shortcuts

**Files:** none (Fabric portal action). Follows the exact same click-path already
proven for every other shortcut in this project (e.g. `docs/superpowers/plans/2026-09-10-dp-invoice.md` Task 1).

- [ ] **Step 1: Create the `InManuf` shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `InManuf`
7. Keep the destination name as `InManuf` (don't rename)
8. **Create**

- [ ] **Step 2: Create the `InManuf_Locale` shortcut**

Same steps as Step 1, selecting `InManuf_Locale` instead.

- [ ] **Step 3: Create the `INHIST_MONTH_4_PI` shortcut**

Same steps as Step 1, selecting `INHIST_MONTH_4_PI` instead.

- [ ] **Step 4: Create the `InHistMQT` shortcut**

Same steps as Step 1, selecting `InHistMQT` instead.

- [ ] **Step 5: Confirm all 4 appear**

In `DP_Staging` → `Tables`, confirm `InManuf`, `InManuf_Locale`, `INHIST_MONTH_4_PI`,
and `InHistMQT` are all listed alongside everything else already there. Report back
once done.

---

### Task 2: Independently verify all 4 new shortcuts

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_jdis_partinfo.py`

- [ ] **Step 1: Write the verification script**

```python
"""
JDIS_PART_INFORMATION REBUILD - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms the 4 new OneLake shortcuts in DP_Staging (InManuf, InManuf_Locale,
INHIST_MONTH_4_PI, InHistMQT) resolve to the exact same row count as reading
each table directly from JD_EquipRDB_Production_Bronze. A shortcut points at
the same underlying Delta files as its source, so any mismatch means the
shortcut itself is broken (wrong table selected, stale metadata), not a data
problem.

Run manually after Brian creates the 4 shortcuts (plan Task 1).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

all_match = True
for table in ["InManuf", "InManuf_Locale", "INHIST_MONTH_4_PI", "InHistMQT"]:
    dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{table}')").fetchone()[0]
    jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/{table}')").fetchone()[0]
    match = dp_count == jd_count
    all_match = all_match and match
    print(f"{table}: DP_Staging={dp_count:,}  Bronze={jd_count:,}  Match={match}")

print(f"\nAll 4 shortcuts match: {all_match}")
```

- [ ] **Step 2: Run it**

```bash
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_jdis_partinfo.py
```

Expected: `Match=True` for all 4 tables, `All 4 shortcuts match: True`. If any show
`False`, stop and check that shortcut was pointed at the right table before
proceeding (revisit Task 1 for that specific shortcut).

- [ ] **Step 3: Commit**

```bash
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_jdis_partinfo.py
git commit -m "Add bronze shortcut verification for jdis_Part_Information rebuild's 4 new tables

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Independently verify the column mapping against real data

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_jdis_partinfo_mapping.py`

This is the real proof step for the spec's Section 6 verification plan — confirms
the "Real facts" mapping table above is actually correct before it goes into the
notebook, using the 5 real sample parts already captured above.

- [ ] **Step 1: Write the verification script**

```python
"""
JDIS_PART_INFORMATION REBUILD - COLUMN MAPPING VERIFICATION
============================================================================
Independently computes Current12MoSales/Previous12MoSales (via a join to
INHIST_MONTH_4_PI) and Current12MoDollars/Previous12MoDollars (via a rolling
12-month SUM over InHistMQT) for 5 real, already-known parts, and compares
against those same parts' real current values in Silver_PartInformation
(which is still sourced from the live view via the old ODBC dataflows today,
so its current values are a trustworthy real-world baseline).

This is NOT testing the future notebook's code - it's independently proving
the mapping itself (which tables/columns/join logic) is correct BEFORE that
mapping goes into the notebook (plan Task 4). Run after Task 2 passes.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

SAMPLE_PARTS = [
    ("13", "PK11", "M"),
    ("15", "341-645", "SC"),
    ("3", "VAK1", "M"),
    ("3", "221228", "RM"),
    ("8", "9RNJA", "M"),
]

EXPECTED = {
    ("13", "PK11", "M"): (1, 1491.31, 4, 5544.40),
    ("15", "341-645", "SC"): (1, 185.23, 1, 170.88),
    ("3", "VAK1", "M"): (2, 174.90, 1, 79.76),
    ("3", "221228", "RM"): (2, 66.50, 1, 28.59),
    ("8", "9RNJA", "M"): (18, 1219.44, 9, 441.70),
}

print("=== Current12MoSales / Previous12MoSales (via INHIST_MONTH_4_PI join) ===")
for branch, part_no, franchise in SAMPLE_PARTS:
    row = con.execute(f"""
        SELECT PI_CURRENT_12_MO_SALES, PI_PREVIOUS_12_MO_SALES
        FROM delta_scan('{base}/INHIST_MONTH_4_PI')
        WHERE BRANCH = '{branch}' AND PART_NO = '{part_no}' AND FRANCHISE = '{franchise}'
    """).fetchone()
    exp_sales, exp_dollars, exp_prev_sales, exp_prev_dollars = EXPECTED[(branch, part_no, franchise)]
    print(f"{branch}/{part_no}/{franchise}: got Current={row[0] if row else None}, "
          f"Previous={row[1] if row else None}  (expected Current={exp_sales}, Previous={exp_prev_sales})")

print("\n=== Current12MoDollars / Previous12MoDollars (via InHistMQT rolling sum) ===")
print("First, check what date range InHistMQT actually covers, to build the right window:")
date_range = con.execute(f"""
    SELECT MIN(DATEHIST), MAX(DATEHIST) FROM delta_scan('{base}/InHistMQT')
""").fetchone()
print(f"InHistMQT DATEHIST range: {date_range[0]} to {date_range[1]}")

for branch, part_no, franchise in SAMPLE_PARTS:
    row = con.execute(f"""
        SELECT
            SUM(CASE WHEN DATEHIST > (SELECT MAX(DATEHIST) FROM delta_scan('{base}/InHistMQT')) - INTERVAL 12 MONTH
                     THEN SAL_VAL ELSE 0 END) AS current_12mo_dollars,
            SUM(CASE WHEN DATEHIST <= (SELECT MAX(DATEHIST) FROM delta_scan('{base}/InHistMQT')) - INTERVAL 12 MONTH
                      AND DATEHIST > (SELECT MAX(DATEHIST) FROM delta_scan('{base}/InHistMQT')) - INTERVAL 24 MONTH
                     THEN SAL_VAL ELSE 0 END) AS previous_12mo_dollars
        FROM delta_scan('{base}/InHistMQT')
        WHERE BRANCH = '{branch}' AND PART_NO = '{part_no}' AND FRANCHISE = '{franchise}'
    """).fetchone()
    exp_sales, exp_dollars, exp_prev_sales, exp_prev_dollars = EXPECTED[(branch, part_no, franchise)]
    print(f"{branch}/{part_no}/{franchise}: got Current$={row[0]}, Previous$={row[1]}  "
          f"(expected Current$={exp_dollars}, Previous$={exp_prev_dollars})")
```

- [ ] **Step 2: Run it and evaluate the real output**

```bash
python .claude/queries/adhoc/dp-bronze-verify/verify_jdis_partinfo_mapping.py
```

Expected: the `INHIST_MONTH_4_PI` join values should match the expected
Current12MoSales/Previous12MoSales exactly (these come from a real pre-computed
column, so an exact match is the bar). The `InHistMQT` rolling-sum values are
expected to be **close but may not match exactly** — the real view's exact month
boundary logic (`YMD(curyear, curmonth, 1)` etc.) uses calendar-month boundaries
anchored to "now," not a rolling 365-day window from the data's own max date, so a
first pass using `MAX(DATEHIST)` as the anchor is a reasonable starting
approximation, not guaranteed to match to the last file. **If the dollar values
are meaningfully off, this is expected and needs a second iteration**: refine the
date-window logic (likely: anchor to the actual current calendar month, matching
the view's real `YMD(curyear, curmonth, ...)` boundaries, not the data's own max
date) until it matches. Do not proceed to Task 4 until at least the `INHIST_MONTH_4_PI`
values match exactly and the `InHistMQT` dollar values are understood (matching, or a
clearly-identified and accepted small real-world timing difference, not an unexplained
gap).

- [ ] **Step 3: Commit**

```bash
git add .claude/queries/adhoc/dp-bronze-verify/verify_jdis_partinfo_mapping.py
git commit -m "Add real-data verification for jdis_Part_Information's column mapping

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Snapshot the old notebook's current output before rewriting

**Files:** none — this is a one-time data capture, not a code change.

The current `Silver_PartInformation` table gets overwritten
(`.mode("overwrite")`) the moment the rebuilt notebook first runs. Capture a
comparison baseline now, before Task 5 touches anything, so Task 6 has real old
data to compare the new notebook's output against — not just the 5 sample rows
already in this plan (a broader, real comparison).

- [ ] **Step 1: Export a full snapshot for comparison**

```python
import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

con.execute(f"""
    COPY (SELECT * FROM delta_scan('{base}/Silver_PartInformation'))
    TO 'silver_partinformation_old_snapshot.parquet' (FORMAT PARQUET)
""")
count = con.execute("SELECT COUNT(*) FROM read_parquet('silver_partinformation_old_snapshot.parquet')").fetchone()[0]
print(f"Snapshot saved: {count:,} rows")
```

Run this from the session scratchpad directory (this file doesn't get committed —
it's a temporary comparison baseline for Task 6, not project data).

Expected: a real row count printed, matching `Silver_PartInformation`'s current
size (~1.1M rows).

---

### Task 5: Rewrite `Build_Silver_PartInformation.Notebook`

**Files:**
- Modify: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_PartInformation.Notebook/notebook-content.py`

This is a code-writing task for an implementer subagent. Work directly in the
`fabric-workspace-docs` repo's `dev` branch checkout (no worktree needed — this is
a single-file change, and Fabric's own Git integration is how this content actually
reaches the live notebook, matching how every other notebook rewrite in this
project has worked. Confirm with the user before committing directly to `dev` if
unsure).

- [ ] **Step 1: Write the new notebook content**

Replace the entire file with:

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "876255e0-d462-4697-adc1-4a655f5bb101",
# META       "default_lakehouse_name": "DP_Staging",
# META       "default_lakehouse_workspace_id": "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201",
# META       "known_lakehouses": [
# META         {
# META           "id": "876255e0-d462-4697-adc1-4a655f5bb101"
# META         }
# META       ]
# META     },
# META     "environment": {
# META       "environmentId": "35c7a5de-35f2-83b3-4e32-e3ddecb30b6e",
# META       "workspaceId": "00000000-0000-0000-0000-000000000000"
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_PartInformation
# Rebuilt 2026-09-18 to read from JD Bronze shortcuts instead of the two
# unmanaged Dataflow Gen2 items (df_JDIS_PartInformation_Active_Raw/
# _Dead_Raw) that queried the live source system directly via ODBC,
# bypassing this project's whole Bronze mirror architecture. Those two
# dataflows had no schedule at all - only two manual refreshes on record,
# a week apart. See docs/superpowers/specs/2026-09-18-jdis-part-information-
# rebuild-design.md for the full real column-to-source mapping this
# notebook implements, traced from jdis_Part_Information's real
# ALTER VIEW SQL (a SQL Anywhere view, not a base table).
#
# Faithful port of the same ~33 columns the old dataflows selected - no
# expansion to the view's other ~170 columns (60-month history arrays,
# fiscal-year YTD sums, suggested-order-qty). Single notebook, single
# output table - no Active/Dead split (the old split's CU-saving logic
# doesn't carry over to a Spark rebuild, since a row's Active/Dead status
# is only knowable after computing the same aggregates regardless of
# which bucket it lands in - see the design spec's Section 5). The old
# notebook's ActivityTier column is dropped entirely - confirmed via
# git grep to have zero downstream consumers.
#
# Sources: InMaster + Branch_Name (both already shortcut, used elsewhere
# in this project) joined to InManuf/InManuf_Locale (new shortcuts,
# chosen per-row via Branch_Name.FR_LOC_INDICATOR) for manufacturer-level
# fields, and INHIST_MONTH_4_PI (new shortcut, a simple join - it already
# has Current12MoSales/Previous12MoSales pre-computed, no aggregation
# needed) plus InHistMQT (new shortcut, needs a real rolling-12-month
# SUM(SAL_VAL) for Current12MoDollars/Previous12MoDollars - the one piece
# of this rebuild needing real aggregation, not just a join).
#
# Ancient-datetime Spark config carried forward from the old notebook -
# jdis_Part_Information has genuine sentinel "never happened" dates
# (e.g. DateLastRequested = 1900-01-01) that trip Spark's calendar-
# rebase guard (SPARK-31404) on write if not set explicitly.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_PARTINFORMATION")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

in_master = spark.read.table("InMaster")
branch_name = spark.read.table("Branch_Name")
in_manuf = spark.read.table("InManuf")
in_manuf_locale = spark.read.table("InManuf_Locale")
inhist_month_4_pi = spark.read.table("INHIST_MONTH_4_PI")
in_hist_mqt = spark.read.table("InHistMQT")

print(f"InMaster: {in_master.count():,} rows")
print(f"Branch_Name: {branch_name.count():,} rows")
print(f"InManuf: {in_manuf.count():,} rows")
print(f"InManuf_Locale: {in_manuf_locale.count():,} rows")
print(f"INHIST_MONTH_4_PI: {inhist_month_4_pi.count():,} rows")
print(f"InHistMQT: {in_hist_mqt.count():,} rows")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# FR_LOC_INDICATOR comes from Branch_Name, not InMaster/InManuf - confirmed
# via real Bronze schema check 2026-09-18. Join it onto InMaster first so
# every downstream join can reference it per-row.
base = in_master.join(
    branch_name.select(
        F.col("branch").alias("_bn_branch"),
        F.col("FR_LOC_INDICATOR").alias("_fr_loc_indicator"),
    ),
    in_master["BRANCH"] == F.col("_bn_branch"),
    "left",
).drop("_bn_branch")

# Manufacturer-level fields: InManuf_Locale if FR_LOC_INDICATOR = 'Y', else
# InManuf. Both are shaped identically (same columns), joined on
# (Franchise, PartNumber).
manuf_locale = in_manuf_locale.select(
    F.col("FR").alias("_ml_fr"),
    F.col("PART_NO").alias("_ml_part_no"),
    F.col("commodity_code").alias("_ml_commodity_code"),
    F.col("return_indicator").alias("_ml_return_indicator"),
    F.col("UNIT_PACK_QTY").alias("_ml_unit_pack_qty"),
    F.col("UNIT_WEIGHT").alias("_ml_unit_weight"),
)
manuf_std = in_manuf.select(
    F.col("FR").alias("_m_fr"),
    F.col("PART_NO").alias("_m_part_no"),
    F.col("commodity_code").alias("_m_commodity_code"),
    F.col("return_indicator").alias("_m_return_indicator"),
    F.col("UNIT_PACK_QTY").alias("_m_unit_pack_qty"),
    F.col("UNIT_WEIGHT").alias("_m_unit_weight"),
)

base = base.join(
    manuf_locale,
    (base["FRANCHISE"] == F.col("_ml_fr")) & (base["PART_NO"] == F.col("_ml_part_no")),
    "left",
).join(
    manuf_std,
    (base["FRANCHISE"] == F.col("_m_fr")) & (base["PART_NO"] == F.col("_m_part_no")),
    "left",
)

# INHIST_MONTH_4_PI: simple join, already has Current12MoSales/
# Previous12MoSales pre-computed - no aggregation needed for these two.
base = base.join(
    inhist_month_4_pi.select(
        F.col("BRANCH").alias("_ih_branch"),
        F.col("FRANCHISE").alias("_ih_franchise"),
        F.col("PART_NO").alias("_ih_part_no"),
        F.col("PI_CURRENT_12_MO_SALES").alias("_current_12mo_sales"),
        F.col("PI_PREVIOUS_12_MO_SALES").alias("_previous_12mo_sales"),
    ),
    (base["BRANCH"] == F.col("_ih_branch"))
    & (base["FRANCHISE"] == F.col("_ih_franchise"))
    & (base["PART_NO"] == F.col("_ih_part_no")),
    "left",
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Current12MoDollars / Previous12MoDollars: real rolling-12-month SUM(SAL_VAL)
# from InHistMQT, grouped by (Branch, Franchise, PartNumber).
#
# CORRECTED 2026-09-18 after Task 3's real-data verification found the naive
# "DATEHIST > MAX(DATEHIST) - 12 months" window wrong for 2 of 5 sample parts.
# Root cause: DATEHIST is a per-row MONTH BUCKET marker (identical to MM_YYYY),
# not a transaction timestamp, and different parts have different "most recent
# populated month" (a part with no activity in the most recent month simply has
# no row for it) - so anchoring the window to each part's own MAX(DATEHIST) is
# wrong. The real view anchors to a GLOBAL current-month pointer and EXCLUDES
# that in-progress month entirely from both windows:
#   Current12MoDollars  = SUM(SAL_VAL) over the 12 complete calendar months
#                          immediately before the table's global current month
#   Previous12MoDollars = SUM(SAL_VAL) over the 12 complete calendar months
#                          immediately before that
# Uses integer year*12+month arithmetic (not date/interval math) to sidestep
# DATEHIST's TIMESTAMP WITH TIME ZONE offset flipping between -05:00/-06:00 by
# season (US Central DST) - year()/month() on a timestamptz already reflects
# the correct stored calendar month, no manual UTC conversion needed. Verified
# exactly against all 5 real sample parts in this plan's "Real facts" table -
# see .claude/queries/adhoc/dp-bronze-verify/verify_jdis_partinfo_mapping.py
# (data-projects repo) for the real DuckDB proof this PySpark logic mirrors.
anchor_monthnum = in_hist_mqt.agg(
    F.max(F.year("DATEHIST") * 12 + F.month("DATEHIST"))
).collect()[0][0]

dollars_agg = in_hist_mqt.withColumn(
    "_monthnum", F.year("DATEHIST") * 12 + F.month("DATEHIST")
).groupBy("BRANCH", "FRANCHISE", "PART_NO").agg(
    F.sum(
        F.when(
            (F.col("_monthnum") >= anchor_monthnum - 12) & (F.col("_monthnum") < anchor_monthnum),
            F.col("SAL_VAL"),
        ).otherwise(0)
    ).alias("_current_12mo_dollars"),
    F.sum(
        F.when(
            (F.col("_monthnum") >= anchor_monthnum - 24) & (F.col("_monthnum") < anchor_monthnum - 12),
            F.col("SAL_VAL"),
        ).otherwise(0)
    ).alias("_previous_12mo_dollars"),
)

base = base.join(
    dollars_agg.select(
        F.col("BRANCH").alias("_dg_branch"),
        F.col("FRANCHISE").alias("_dg_franchise"),
        F.col("PART_NO").alias("_dg_part_no"),
        "_current_12mo_dollars",
        "_previous_12mo_dollars",
    ),
    (base["BRANCH"] == F.col("_dg_branch"))
    & (base["FRANCHISE"] == F.col("_dg_franchise"))
    & (base["PART_NO"] == F.col("_dg_part_no")),
    "left",
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

silver = base.select(
    F.col("BRANCH").alias("Branch"),
    F.col("PART_NO").alias("PartNumber"),
    F.col("PART_DESC").alias("Description"),
    F.col("FRANCHISE").alias("Franchise"),
    F.when((F.col("CATEGORY") == "") | F.col("CATEGORY").isNull(), "").otherwise(F.col("CATEGORY")).alias("Source"),
    F.when((F.col("SALES_CLASS") == "") | F.col("SALES_CLASS").isNull(), "").otherwise(F.col("SALES_CLASS")).alias("SLC"),
    F.coalesce(
        F.when(F.col("_fr_loc_indicator") == "Y", F.trim(F.col("_ml_commodity_code"))),
        F.trim(F.col("_m_commodity_code")),
        F.lit(""),
    ).alias("CommodityCode"),
    F.when((F.col("dealer_group_code") == "") | F.col("dealer_group_code").isNull(), "").otherwise(F.col("dealer_group_code")).alias("DealerGroupCode"),
    F.coalesce(F.col("ON_HAND_QTY"), F.lit(0)).alias("QuantityOnHand"),
    (
        F.coalesce(F.col("ON_HAND_QTY"), F.lit(0))
        + F.coalesce(F.col("BULK_BIN_QTY"), F.lit(0))
        - F.coalesce(F.col("IN_TRANSIT_QTY"), F.lit(0))
        - F.coalesce(F.col("Pending_Qty"), F.lit(0))
    ).alias("BinQty"),
    F.coalesce(F.col("BULK_BIN_QTY"), F.lit(0)).alias("BulkBinQty"),
    F.coalesce(F.col("Pending_Qty"), F.lit(0)).alias("PendingQty"),
    F.coalesce(F.col("BACK_ORD_QTY"), F.lit(0)).alias("BackOrderQty"),
    F.when((F.col("BULK_BIN") == "") | F.col("BULK_BIN").isNull(), "").otherwise(F.col("BULK_BIN")).alias("BulkBin"),
    F.when((F.col("BIN_LOCATION") == "") | F.col("BIN_LOCATION").isNull(), "").otherwise(F.col("BIN_LOCATION")).alias("Bin"),
    F.coalesce(
        F.when(F.col("_fr_loc_indicator") == "Y", F.trim(F.col("_ml_unit_pack_qty").cast("string"))),
        F.trim(F.col("_m_unit_pack_qty").cast("string")),
        F.lit(""),
    ).alias("PackageQty"),
    F.coalesce(
        F.when(F.col("_fr_loc_indicator") == "Y", F.trim(F.col("_ml_return_indicator"))),
        F.trim(F.col("_m_return_indicator")),
        F.lit(""),
    ).alias("Returnable"),
    F.coalesce(
        F.when(F.col("_fr_loc_indicator") == "Y", F.col("_ml_unit_weight")),
        F.col("_m_unit_weight"),
        F.lit(0),
    ).alias("Weight"),
    F.coalesce(F.col("OS_ORDER_QTY"), F.lit(0)).alias("OnOrder"),
    F.coalesce(F.col("SUPER_TO"), F.lit("")).alias("SuperTo"),
    F.coalesce(F.col("SUPER_FROM"), F.lit("")).alias("SuperFrom"),
    F.coalesce(F.col("ON_HAND_VAL"), F.lit(0)).alias("InventoryCost"),
    F.coalesce(F.col("REPLACE_PRICE"), F.lit(0)).alias("Cost"),
    F.coalesce(F.col("SELL_PRICE1"), F.lit(0)).alias("SellPrice1"),
    F.coalesce(F.col("LIST_PRICE"), F.lit(0)).alias("ListPrice"),
    F.coalesce(F.col("_current_12mo_sales"), F.lit(0)).alias("Current12MoSales"),
    F.coalesce(F.col("_current_12mo_dollars"), F.lit(0)).alias("Current12MoDollars"),
    F.coalesce(F.col("_previous_12mo_sales"), F.lit(0)).alias("Previous12MoSales"),
    F.coalesce(F.col("_previous_12mo_dollars"), F.lit(0)).alias("Previous12MoDollars"),
    F.coalesce(F.col("VENDOR_CODE"), F.lit(0)).alias("VendorCode"),
    F.coalesce(F.col("CREATION_DATE"), F.lit("1900-01-01")).alias("DateCreated"),
    F.coalesce(F.col("LAST_DEM_DATE"), F.lit("1900-01-01")).alias("DateLastRequested"),
    F.coalesce(F.col("STOCKTAKE_DATE"), F.lit("1900-01-01")).alias("StocktakeDate"),
)

silver_count = silver.count()
in_master_count = in_master.count()
print(f"Silver_PartInformation rows: {silver_count:,}")
assert silver_count == in_master_count, (
    f"Row count mismatch ({silver_count:,} vs InMaster's {in_master_count:,}) - "
    f"every InMaster row should produce exactly one output row (all joins here "
    f"are LEFT joins against InMaster, so the join itself should never add or "
    f"drop rows)."
)
print("Row count matches InMaster exactly - joins did not add or drop rows.")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_PartInformation")

print("Silver build complete: Silver_PartInformation written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof (that's
# plan Task 6's independent comparison against the pre-rewrite snapshot).
sample = spark.sql("""
    SELECT Branch, PartNumber, Franchise, QuantityOnHand, Current12MoSales,
           Current12MoDollars, Previous12MoSales, Previous12MoDollars
    FROM delta.`Tables/Silver_PartInformation`
    WHERE (Branch, PartNumber, Franchise) IN (
        ('13', 'PK11', 'M'), ('15', '341-645', 'SC'), ('3', 'VAK1', 'M'),
        ('3', '221228', 'RM'), ('8', '9RNJA', 'M')
    )
""").toPandas()
print("Sample rows (compare against plan's 'Real sample parts' table):")
print(sample.to_string())
```

- [ ] **Step 2: Compile-check the notebook's Python cells for syntax errors**

Since this doesn't run locally (it needs live Spark + the real Bronze shortcuts),
at minimum confirm the file has valid Python syntax:
```bash
python -c "
import re
with open('workspaces/DP - Staging - Dev/Build_Silver_PartInformation.Notebook/notebook-content.py') as f:
    content = f.read()
# Strip Fabric's # META/# CELL marker lines, compile what remains
code_lines = [l for l in content.splitlines() if not l.startswith('# META') and l.strip() != '# CELL ********************']
compile('\n'.join(code_lines), 'notebook', 'exec')
print('Syntax OK')
"
```
Expected: `Syntax OK`.

- [ ] **Step 3: Commit**

```bash
git add "workspaces/DP - Staging - Dev/Build_Silver_PartInformation.Notebook/notebook-content.py"
git commit -m "Rebuild Build_Silver_PartInformation from JD Bronze shortcuts

Replaces the two unmanaged, unscheduled Dataflow Gen2 items
(df_JDIS_PartInformation_Active_Raw/_Dead_Raw) that queried the live
source system directly via ODBC. Faithful port of the same ~33
columns, sourced from InMaster/Branch_Name/InManuf/InManuf_Locale/
INHIST_MONTH_4_PI/InHistMQT Bronze shortcuts. Single notebook, single
output table - no Active/Dead split (deferred pending real CU
measurement per the design spec).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Real findings from Task 5's code-quality review (2026-09-18)

The code-quality reviewer returned NOT APPROVED with 5 Important findings. Each was
independently verified against live Fabric/Bronze data (this project's standard
discipline) rather than accepted or dismissed on the reviewer's word alone. Two were
confirmed as real bugs and fixed; three were confirmed as non-issues given real data.

**Confirmed real bug #1 — `PackageQty`'s empty-string fallback introduces new blanks.**
The reviewer flagged `PackageQty` as a type mismatch against the Bin Location Report's
TMDL (`Int64.Type` conversion). Querying the live table showed `PackageQty` is
*already* VARCHAR today (not a type regression) — but with **zero blank values**
across all 1,112,605 rows, formatted like `"1.000000"`/`"0.000000"`. The new
notebook's final fallback for unmatched `InManuf`/`InManuf_Locale` joins was
`F.lit("")` (empty string). Since `InMaster`↔`InManuf` only matches 81.5% of rows
(907,328/1,112,784 — verified via a direct join), the remaining ~18.5% (~205K rows)
would get `PackageQty = ""` where today they get a real zero-value string — and an
empty string fails Power Query's `Int64.Type` conversion in the Bin Location Report
(a real regression risk for ~205K rows). **Fixed:** changed the fallback to
`F.lit("0")`. (Separately: Bronze `InManuf.UNIT_PACK_QTY` is `DECIMAL(8,2)`, so
`.cast("string")` naturally produces `"1.00"` not `"1.000000"` — a cosmetic format
difference from the old ODBC-view output, harmless since Power Query's `Int64.Type`
conversion truncates either format to the same integer.)

**Confirmed real bug #2 — date-literal coalesce silently promotes to StringType.**
`DateCreated`/`DateLastRequested`/`StocktakeDate` were built as
`F.coalesce(F.col("CREATION_DATE"), F.lit("1900-01-01"))` — coalescing a real
`TIMESTAMP WITH TIME ZONE` column (confirmed live) with a bare string literal. Under
Spark's non-ANSI type coercion (Fabric's default), `coalesce`/`case`/`least`/
`greatest` resolve a Timestamp/String mismatch by promoting the **entire result
column** to StringType — not just the sentinel rows, every row. This would have
silently turned all three date columns into strings in the output Delta table,
regardless of whether any row actually needed the sentinel fallback. **Fixed:**
wrapped each literal in an explicit timestamp cast (`F.to_timestamp(F.lit("1900-01-01"))`)
so both `coalesce` arguments are the same type and the result stays `TimestampType`.

**Confirmed non-issue #3 — sentinel-date fallback doesn't introduce new NULL-handling risk.**
The reviewer worried the `coalesce(..., "1900-01-01")` pattern was *new* behavior that
could break Physical Inventory's `KEEPFILTERS(NOT ISBLANK(...))` measure on
`StocktakeDate`. **Correction (found by the Task 5 re-review):** the earlier draft of
this finding stated there were "zero real NULLs" in the date columns today, framing
the sentinel fallback as effectively dead code — that's only true of the *old output
table*. The raw Bronze source columns this notebook actually reads DO have real
NULLs: `STOCKTAKE_DATE` 567,767 (51.0%), `LAST_DEM_DATE` 222,210 (20.0%),
`CREATION_DATE` 3,051 — the fallback fires constantly, for over half of
`StocktakeDate`. The conclusion still holds, but for the right reason: the source
view's own real SQL (obtained from Brian earlier this session) already does
`isnull(inmaster.Creation_date, '1900-01-01')`-style sentinel substitution, so the old
ODBC-sourced dataflow's *output* never contained raw NULLs — confirmed by row-count
reconciliation, the old table has exactly 3,051 / 222,160 / 567,672 rows at the
sentinel, matching Bronze's NULL counts within normal live drift. The new notebook's
coalesce logic *replicates* the view's existing, heavily-used behavior; it doesn't
introduce it. No fix needed beyond bug #2's type fix (which remains necessary
regardless of null volume, since it affects every row's type, not just sentinel rows).

**Confirmed non-issue #4 — the 81.5% `InMaster`↔`InManuf` join match rate is not a regression.**
The reviewer flagged the join with no guard against a silent miss, citing
`Build_Gold_VendorCode`'s real precedent bug. Direct verification found 81.5% match
(907,328/1,112,784 `InMaster` rows match `InManuf` on `FRANCHISE=FR AND
PART_NO=PART_NO`) — meaning ~18.5% of rows get blank manufacturer-sourced fields.
Comparing against the **current live table**: `CommodityCode` (same manufacturer-join
lineage) is already 31.0% blank today, and `Returnable` is already 24.1% blank today
— both *exceeding* the 18.5% miss rate. The join-miss contributes to, but doesn't
exceed, blankness that already exists in production. This is expected/faithful
behavior (not every part has a manufacturer detail record), not a new key-format bug.
No fix needed.

**Deferred, not fixed — Important #5 (anchor_monthnum observability).** The reviewer
noted `anchor_monthnum` (the global current-month pointer for the rolling 12-month
dollar windows) is computed via `.collect()` but never printed or guarded — a future
Bronze-mirror lag could silently shift both dollar windows by a month with no error
signal. Task 3's real-data verification already confirmed today's anchor value
produces exact matches on all 5 sample parts, so this isn't a "wrong today" issue.
Added a print statement for observability (cheap, non-blocking) rather than a hard
guard, since there's no clear "correct" bound to assert against.

Minor issues (double materialization of the join/aggregation, the verification
cell's silent-zero-match risk, a verbose `F.when(...).otherwise(...)` no-op pattern,
imprecise SPARK-31404 comment wording) were left as-is per the reviewer's own
"non-blocking" framing, consistent with how Task 2's sibling-script stylistic drift
was handled.

**Fixes applied and re-reviewed — Task 5 now APPROVED (commit `4b657917`,
`fabric-workspace-docs`).** The re-review independently verified both fixes against
live data rather than trusting them on inspection alone — notably confirming
`PackageQty`'s empty-string fallback would have injected ~205K real NULLs into a
Gold-layer column (`Fact_Inventory.PackageQty`, via `Build_Gold_Inventory`'s
`.cast("long")`) that has zero today, and that the date-literal fix's sentinel
fallback fires far more often than the plan's now-corrected finding #3 states
(51.0% of `StocktakeDate` rows). It also did a full fresh review beyond the two
diffs and found the row-count assert is sound (all four join keys are genuinely 1:1
unique in live Bronze today), the asymmetric column-trimming is deliberate/correct
(not sloppiness — verified column-by-column against both Bronze and the old output's
untrimmed-row counts), and the rolling 12-month dollar window's month-bucket
arithmetic is timezone-invariant even though it looked timezone-sensitive (a uniform
UTC-vs-Central one-month shift cancels between the anchor and the data since both are
derived from the same expression — verified empirically both ways against all 5
sample parts).

New minor findings from the re-review, left unfixed (non-blocking, noted for future
reference):
- `Weight` silently changes type from the old table's VARCHAR to DECIMAL(10,4) (only
  `PackageQty` was explicitly cast to string to preserve its VARCHAR-ness). Verified
  benign — both real downstream consumers (`Build_Gold_MDInvoicesClosed`,
  `Build_Gold_MDInvoicesNoFreight`) already cast it to double before use.
- Numeric precision narrows slightly (old columns were `DECIMAL(34,6)`; the rebuild's
  are ~`DECIMAL(12,2)`/`DECIMAL(22,2)`, inherited from Bronze's own `DECIMAL(8,2)`/
  `(12,2)` sources) — no value loss since sources only carry 2 decimal places, but
  Task 6's schema diff will show it, so don't treat it as a surprise regression.
- The new `anchor_monthnum` print is off-by-one from the intuitive business month in
  UTC (e.g. prints `24321` when the real latest populated month is 2026-08) — fine
  for its stated purpose (spotting a future Bronze-mirror lag via drift in the raw
  number) but would need decoding to read as a calendar month.

---

### Task 6: Real dry run — compare rebuilt output against the pre-rewrite snapshot

**Files:** none — verification only.

- [ ] **Step 1: Run the rebuilt notebook for real**

Brian: in the Fabric portal, open `Build_Silver_PartInformation.Notebook` in
`DP - Staging - Dev` and click **Run**. Watch it complete. Report the printed
sample-rows output from the notebook's own final cell.

- [ ] **Step 2: Compare the sample rows against this plan's expected values**

Check the notebook's own printed output (Step 1) against the "Real sample parts"
table in this plan's "Real facts" section. `QuantityOnHand` should match exactly (0
for all 5). `Current12MoSales`/`Previous12MoSales` should match exactly (these come
from the simple `INHIST_MONTH_4_PI` join). `Current12MoDollars`/`Previous12MoDollars`
should be close to the expected values — if Task 3's window-boundary refinement
was needed, use whatever adjusted logic was confirmed there.

- [ ] **Step 3: Compare full-table row counts against the pre-rewrite snapshot**

```python
import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

new_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Silver_PartInformation')").fetchone()[0]
old_count = con.execute("SELECT COUNT(*) FROM read_parquet('silver_partinformation_old_snapshot.parquet')").fetchone()[0]
print(f"New (rebuilt) row count: {new_count:,}")
print(f"Old (pre-rewrite snapshot) row count: {old_count:,}")
print(f"Difference: {new_count - old_count:,}")
```

Expected: counts should be close (both represent all real parts in `InMaster` /
the source system at slightly different points in time — small drift is normal
and expected on a live source, a large unexplained gap is not).

- [ ] **Step 4: Record the real CU/duration this run took**

Use `Track-ItemCU.ps1` (already proven in this project,
`projects/fabric-monitoring/scripts/enhanced/Track-ItemCU.ps1`) with
`-TrackedItems @("Build_Silver_PartInformation")` to pull the real CU-seconds and
duration for this run. This is the number the design spec's Section 5 Active/Dead
split decision depends on — record it in this plan (edit this task with the real
result) before deciding anything about splitting.

---

### Task 6 — Real results (2026-09-18)

**Step 1 (real run):** Brian ran the rebuilt notebook in `DP - Staging - Dev`.
Succeeded. (Hit one unrelated real snag along the way: after the Git "Update all"
pull, opening the notebook showed "You don't have permission to use the environment
originally attached to this notebook" for `DP_Silver_HighConcurrency` — a Fabric
permission quirk unrelated to this rebuild's logic. Worked around it for this
one-off manual run by using the workspace default environment instead, since the
environment only affects Spark session-sharing configuration, not data/logic
correctness. Flagged as a follow-up to check before relying on this environment for
`Pipeline_DP_Daily_Refresh`'s scheduled runs — not yet investigated.)

**Steps 2-3 (real comparison, run directly via DuckDB against the written Delta
table rather than relying on the notebook's own console output — a stronger check
since it validates the actual persisted output):**

- All 5 real sample parts from this plan's "Real facts" table matched **exactly**,
  including `VendorCode`/`ListPrice`: `PK11/13/M` (1, 1491.31, 4, 5544.40), `341-645/15/SC`
  (1, 185.23, 1, 170.88), `VAK1/3/M` (2, 174.90, 1, 79.76), `221228/3/RM` (2, 66.50, 1,
  28.59), `9RNJA/8/M` (18, 1219.44, 9, 441.70) — every value matched, including
  `VAK1`/`221228`, the two parts that originally exposed Task 3's rolling-window bug.
  `QuantityOnHand` was 0 for all 5 as expected.
- Row count: new table 1,112,784 vs. the pre-rewrite snapshot's 1,112,605 — a
  difference of +179 rows, matching normal live-source drift between when the
  snapshot was captured and today (not a discrepancy — the code-quality reviewer had
  independently predicted this exact +179 figure from its own live column
  reconciliation before this run ever happened).
- Column count: exactly 33, as scoped.

**Step 4 (real CU/duration) — corrected after a real discrepancy Brian caught:**
The first pass through this step used `Track-ItemCU.ps1`'s default query against
the Capacity Metrics model's `Metrics By Item` table, which the script's own header
comment already documents as "a rolling-window total matching the app's 'Items (14
days)' view" — i.e. a **14-day cumulative total**, not a single-run number. That
was misread as a single-run figure (13,594.62 CU-seconds / 1,368s), which is really
the sum of the OLD notebook's prior daily runs plus today's one new run, all under
the same long-lived Item Id (the notebook was rewritten in place, so its Item Id
never changed). Brian caught this by directly timing a second real run at 1:31
(91 seconds) — nowhere close to the ~23 minutes that number implied.

Querying the model's `Metrics By Item And Day` table (filtered to just 2026-09-18)
gives a much closer per-day figure: **3,878.68 CU-seconds / 378.36s across 2
operations** for today. This still doesn't equal Brian's 91-second stopwatch time
exactly, and per Microsoft's own documentation
(`learn.microsoft.com/fabric/enterprise/throttling`), that remaining gap has a real,
documented explanation: Spark notebook runs are classified as **background
operations**, and Fabric smooths background-operation CU usage over a **24-hour**
window (vs. 5-64 minutes for interactive operations) specifically to avoid capacity
throttling spikes from bursty scheduled jobs — so the Capacity Metrics app's
"Duration (s)" column for a background/Spark item reflects smoothing-related billing
accounting, not literal wall-clock runtime. **The trustworthy number for "how long did
this actually take" is Brian's direct stopwatch measurement: ~91 seconds.** The CU(s)
figure is still a real, meaningful total-compute-cost number (Fabric bills real CU
consumption regardless of how it's smoothed across time), just not one that maps
cleanly to a "minutes per run" duration for background items.

**Lesson for future use of `Track-ItemCU.ps1` on Spark/notebook items:** its default
`Metrics By Item` table is a 14-day rolling total, not a per-run number — for a
single-run check, either query `Metrics By Item And Day` filtered to the specific
date, or just time the run directly. Its "Duration (s)" should not be read as
wall-clock time for background-classified items (notebooks, warehouse jobs, dataflow
refreshes) regardless of which table it's pulled from.

**Design spec Section 5 (Active/Dead split) — real decision:** a real run takes ~91
seconds and ~3,879 CU-seconds/day total across today's 2 operations — both trivial
relative to this backend's normal daily notebook range, and clearly cheaper/faster
than the old ODBC dataflow's historical footprint. There is no real evidence a split
would meaningfully help. **Decision: do not build a split.** Revisit only if real
future measurements show this notebook becoming either much larger (row growth) or a
genuine capacity bottleneck.

---

### Task 7: Cutover and cleanup

**Files:** none — the notebook was already rewritten in place (Task 5), so no
further config/pipeline changes are needed (`dp_backend_scope.json`'s `notebookId`/
`workspaceId` for `Build_Silver_PartInformation` are unchanged — same item, same ID,
different internal logic).

- [ ] **Step 1: Delete the two old Dataflow Gen2 items**

Brian, Fabric portal: in `DP - Staging - Dev`, delete
`df_JDIS_PartInformation_Active_Raw.Dataflow` and
`df_JDIS_PartInformation_Dead_Raw.Dataflow`.

- [ ] **Step 2: Delete their now-unused output tables**

Same workspace, `DP_Staging` lakehouse → `Tables` → delete `PartInformation_Active`
and `PartInformation_Dead`.

- [ ] **Step 3: Commit via Fabric Git integration**

`DP - Staging - Dev` → Source control → Commit. Confirm in `fabric-workspace-docs`
(after `git pull origin dev`) that both `.Dataflow` folders are gone.

---

### Task 8: Confirm the recurring refresh pipeline still works

**Files:** none — verification only, matching this project's "don't just trust a
green checkmark" discipline used throughout.

- [ ] **Step 1: Run `Pipeline_DP_Daily_Refresh` for real**

Brian: Fabric portal → open `Pipeline_DP_Daily_Refresh` (built earlier today) →
**Run**. This pipeline invokes `Build_Silver_PartInformation` by its `notebookId`,
which hasn't changed — so this should just work, but needs a real proof run, not an
assumption.

- [ ] **Step 2: Confirm it Succeeded and check the real output**

Watch it complete in **Monitor**. Expected: all activities Succeeded (matching the
same pattern already proven earlier today), `FailedItems` empty, success email
received.

- [ ] **Step 3: Independently verify `dim_Parts` still builds correctly downstream**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91"
n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/Tables/dim_Parts')").fetchone()[0]
print(f"dim_Parts: {n:,} rows")
```

Expected: a real, sensible row count (in the same ballpark as `dim_Parts`' known
real size, ~316K rows) — confirms `Build_Gold_Parts` (which reads
`Silver_PartInformation`) still works correctly with the rebuilt notebook's output.

---

## What this plan deliberately does not cover

- The view's other ~170 columns (60-month history arrays, fiscal-year YTD sums,
  suggested-order-qty, current-month aggregates) — out of scope per the design
  spec's Section 2/8.
- The Active/Dead split decision — Task 6 Step 4 records the real CU/duration
  number this decision depends on, but making that decision is a separate,
  future piece of work once that data exists.
- Prod-tier shortcuts/notebook — this rebuild is Dev-tier only.
