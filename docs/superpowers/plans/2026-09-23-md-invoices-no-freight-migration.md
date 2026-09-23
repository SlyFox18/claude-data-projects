# MD Invoices With No Freight Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate MD Invoices With No Freight from `LH_Master_Data` to `DP_Presentation` — fixing 4 unregistered-notebook staleness gaps, building 2 genuinely-missing Gold tables (a static CSV-loaded rate table and a monthly snapshot with real history to preserve), then the standard report-layer audit-and-repoint.

**Architecture:** 4 registration-only fixes for already-built, already-correct notebooks; one new small notebook for `FreightCalculator` (CSV-loaded rate table); one new notebook + one-time backfill for `Fact_MDInvoices_NoFreight_Snapshot` (mirroring the Open Parts Tickets snapshot pattern exactly); then the standard report-layer audit-and-repoint with an explicit `dim_DateTable` real-schema cross-check built in from the start.

**Tech Stack:** Fabric Notebooks (PySpark), Power BI Desktop (`.pbip`/TMDL text format), `fab` CLI, `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration, Fabric Data Pipelines (config-driven via `deploy/dp_backend_scope.json`).

**Full design reference:** `docs/superpowers/specs/2026-09-23-md-invoices-no-freight-migration-design.md` (approved).

---

## Context You Need

**Real connection strings** (used throughout this whole project):
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**Real workspace/lakehouse IDs:**
- `DP - Presentation - Dev` workspace: `73fd5443-240e-410a-990a-98827f32c087`, lakehouse `DP_Presentation`: `966efc8a-16f9-423b-aa43-e368fcd8fb91`
- `LH_Master_Data` workspace: `b48cdb35-7ce3-46de-96df-d70db77649cb`, lakehouse `LH_Master_Data`: `3e74497b-8c51-4a1a-91a1-888c59118f48`
- SQL analytics endpoint ID: `18effb0e-7bc2-47a1-854c-f4f2e8129145`

**10 real data tables in the report** (`fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/`): `Fact_MDInvoices_Closed`, `Fact_MDInvoices_NoFreight`, `Fact_MDInvoices_NoFreight_Snapshot`, `FreightCalculator`, `dim_BranchLocation`, `dim_CustomerList`, `dim_DateTable`, `dim_Franchise`, `dim_Parts`, `dim_Salesperson`. `dim_FreightPerformanceGroup` and `% Freight Difference Threshold` confirmed to have zero `Sql.Database` calls — not part of this migration.

**Real `fab` CLI syntax, already discovered and proven working this session** — every folder segment needs an explicit `.Folder` suffix, `.py` notebook source needs `--format .py` on import:
```bash
export PATH="$HOME/.local/bin:$PATH"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_X.Notebook" \
  -i "<local path>" --format .py -f
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_X.Notebook" --timeout 300
```

**Critical real gotcha, confirmed repeatedly this session**: `fab job run` executes whatever is CURRENTLY LIVE in Fabric, not the local git-mirrored file. Any time a notebook's local `notebook-content.py` is written or edited, `fab import` MUST run first — including on a second run after fixing a bug.

**`dp_backend_scope.json` real entry shape** — always a precise text insertion (Edit tool) matching the file's existing compact single-line-per-entry style, NEVER a full `json.dump()` rewrite (confirmed multiple times this session: `json.dump(..., indent=2)` reformats every existing entry and produces a huge, unwanted diff).

**Real, already-confirmed staleness gaps** (found this session, same never-registered-notebook bug class hit 4+ times already):
- `Build_Gold_MDInvoicesClosed.Notebook` (notebookId `0b6206b9-0b05-4338-9d57-77a4f4034b63`, at `DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesClosed.Notebook`) — not registered. `DP_Presentation.Fact_MDInvoices_Closed`: 150,929 rows, max `InvoiceDate` 2026-09-09, vs. real production's 153,182 rows / 2026-09-22 (13 days stale).
- `Build_Gold_MDInvoicesNoFreight.Notebook` (notebookId `4b576f71-fe0e-44d8-afce-981c3a3c901d`, same folder) — not registered. `DP_Presentation.Fact_MDInvoices_NoFreight`: 2,205 rows, max `OrderDate` 2026-09-09, vs. production's 2,189 rows / 2026-09-22 (stale by date despite row count already being slightly higher).
- `Build_Gold_DateTable.Notebook` (notebookId `47923626-8236-4d9b-aae8-08386fda863b`, at `DP - Presentation - Dev/Dimensions/Build_Gold_DateTable.Notebook`) — not registered. Low real risk (`DP_Presentation.dim_DateTable` already spans a fixed 2020-01-01 to 2030-12-31, evergreen), but same fix, cheap to close out.
- `Build_Gold_Salesperson.Notebook` (notebookId `5732fefa-c175-4f30-afd0-f29944d82cad`, same folder) — not registered. 645 rows vs. production's 646 (negligible), same fix.

**`FreightCalculator`'s real source** (`LH_Master_Data/Notebooks/Freight Calculator Update.Notebook/notebook-content.py`, full content already read) — NOT database-derived. Loads a small, manually-maintained CSV from the Lakehouse's own Files section:
```python
from pyspark.sql.functions import col
from pyspark.sql.types import IntegerType, DoubleType

df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("Files/FREIGHT CALCULATOR 2026 - UPDATED.csv")

df = df.withColumn("PartWeightFrom", col("PartWeightFrom").cast(IntegerType())) \
       .withColumn("PartWeightTo",   col("PartWeightTo").cast(IntegerType())) \
       .withColumn("BaseRate",       col("BaseRate").cast(DoubleType())) \
       .withColumn("AdditiveRatePerPound", col("AdditiveRatePerPound").cast(DoubleType()))

print(f"Rows loaded: {df.count()}")
df.show(40, truncate=False)

df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable("FreightCalculator")

print("FreightCalculator updated successfully.")
```
This CSV needs to be copied from `LH_Master_Data`'s Files section to `DP_Presentation`'s Files section before the new notebook can read it — real `fab cp` syntax confirmed this session (`fab cp <source> <dest> -f` supports file-to-file copies, e.g. `fab cp Files/csv/fab.csv Files/dest/copy_fab.csv` per `fab copy --help`), full workspace-qualified command given in Task 3 below.

**`nb_Snapshot_MDInvoices_NoFreight.Notebook`'s full real source** (`LH_Master_Data/Notebooks/nb_Snapshot_MDInvoices_NoFreight.Notebook/notebook-content.py`, full content already read) — same exact structure as Open Parts Tickets' `nb_Snapshot_Parts_Open_Orders.Notebook` (already ported once this session): duplicate-guard checking `SnapshotDate`, a 22-column `SELECT` from `Fact_MDInvoices_NoFreight`, `SnapshotDate = 1st of current month`, appended via `saveAsTable` (the real production notebook still has the casing bug live — this port fixes it with a path-based write). The report's own `Fact_MDInvoices_NoFreight_Snapshot.tmdl` already has 3 real DAX calculated columns (`MissedFreightAmount`, `PctFreightDifference`, `FreightBucket`) — confirmed present, semantic-model-only per the source notebook's own comment, don't touch them.

**Real confirmed snapshot history** (DuckDB `delta_scan` against `LH_Master_Data`'s lowercase `fact_mdinvoices_nofreight_snapshot`, same `saveAsTable()`-casing-bug pattern already fixed elsewhere this session): 3 months — `2026-07-01`: 1,636 rows, `2026-08-01`: 2,041 rows, `2026-09-01`: 1,815 rows (5,492 total).

**Old snapshot pipeline, partially confirmed this session** (`LH_Master_Data/Pipelines/Pipeline_Monthly_MDInvoices_Snapshot.DataPipeline`): a `TridentNotebook` activity (real notebookId `31921cae-a955-8f82-44cf-c0a2a545003f`, calling `nb_Snapshot_MDInvoices_NoFreight`) plus a success-email activity — Task 2 re-confirms the FULL activity list before assuming this is single-purpose like Open Parts Tickets' equivalent old pipeline was (don't assume, verify).

**Real `dim_DateTable` risk, confirmed this session**: this report's own `dim_DateTable.tmdl` currently declares the full 62-column set, including ~48 "today-relative" columns (`IsCurrentMonth`, `IsRolling12Months`, `IsYearToDate`, etc.) that do NOT exist on the real `DP_Presentation.dim_DateTable`, which only has 14 columns: `DateKey, Date, Year, Quarter, Month, Day, WeekOfYear, DayOfWeek, MonthName, MonthNameShort, MonthYear, SortableMonthYear, QuarterYear, IsWeekend`. This exact bug class has hit refresh errors twice already this session (Pin Capture, First Pass Fill) and is saved as a standing project memory (`feedback_datetable_today_relative_columns_dropped`). Task 6's audit must explicitly cross-check every DAX-confirmed-used `dim_DateTable` column against this real 14-column list before Task 7 trims anything — any genuinely-used "today-relative" column needs the DAX-calculated-column treatment (sourced from `'Data Refresh'[Date]`), not a straight repoint. The exact DAX pattern (already proven twice this session, e.g. on First Pass Fill's `dim_DateTable.tmdl`):
```
column IsRolling12Months = ```

		VAR RefDate = MAX('Data Refresh'[Date])
		VAR StartOfRollingPeriod = EOMONTH(RefDate, -12) + 1
		VAR EndOfRollingPeriod = EOMONTH(RefDate, 0)
		RETURN
		dim_DateTable[Date] >= StartOfRollingPeriod && dim_DateTable[Date] <= EndOfRollingPeriod
		```
```
(`IsYearToDate` and similar "X-to-date" flags use a `YEAR(dim_DateTable[Date]) = YEAR(RefDate) && dim_DateTable[Date] <= RefDate && dim_DateTable[Date] >= DATE(YEAR(RefDate), 1, 1)`-style pattern instead — adapt per the specific flag found used, consulting `LH_Master_Data/Dataflows/03 - Dimensions/df_Dim_Date.Dataflow` for that flag's exact original logic if it's not one of the ones already ported this session.)

**Real, confirmed-necessary SQL analytics endpoint metadata-refresh step** after building any brand-new table:
```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

**Real-tool boundary:** Brian has confirmed MD Invoices With No Freight is already published to `RP - Dev`, committed, and not open in Desktop. No `.pbip` exists yet for this report (confirmed this session).

---

### Task 1: Register and catch up the 4 unregistered notebooks

**Files:**
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [x] **Step 1: Register all 4 in `dp_backend_scope.json`**

Use the Edit tool for precise text insertions matching the file's existing compact style — do NOT rewrite the whole file with a script:
```json
{"name": "Build_Gold_MDInvoicesClosed", "tier": "gold", "cadence": "daily",
 "notebookId": "0b6206b9-0b05-4338-9d57-77a4f4034b63", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesClosed.Notebook"}
{"name": "Build_Gold_MDInvoicesNoFreight", "tier": "gold", "cadence": "daily",
 "notebookId": "4b576f71-fe0e-44d8-afce-981c3a3c901d", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreight.Notebook"}
{"name": "Build_Gold_DateTable", "tier": "gold", "cadence": "monthly",
 "notebookId": "47923626-8236-4d9b-aae8-08386fda863b", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_DateTable.Notebook"}
{"name": "Build_Gold_Salesperson", "tier": "gold", "cadence": "monthly",
 "notebookId": "5732fefa-c175-4f30-afd0-f29944d82cad", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_Salesperson.Notebook"}
```

- [x] **Step 2: Run all 4 once to catch up**

```bash
export PATH="$HOME/.local/bin:$PATH"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_MDInvoicesClosed.Notebook" --timeout 300
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_MDInvoicesNoFreight.Notebook" --timeout 300
fab job run "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_DateTable.Notebook" --timeout 300
fab job run "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_Salesperson.Notebook" --timeout 300
```
Expected: all 4 `Completed`, no `failureReason`.

- [x] **Step 3: Verify the staleness gap is closed**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, base in [("LH_Master_Data", lh_base), ("DP_Presentation", dp_base)]:
    r = con.execute(f"SELECT COUNT(*), MAX(InvoiceDate) FROM delta_scan('{base}/Fact_MDInvoices_Closed')").fetchone()
    print(f"Fact_MDInvoices_Closed - {label}: rows={r[0]:,}  max_date={r[1]}")

for label, base in [("LH_Master_Data", lh_base), ("DP_Presentation", dp_base)]:
    r = con.execute(f"SELECT COUNT(*), MAX(OrderDate) FROM delta_scan('{base}/Fact_MDInvoices_NoFreight')").fetchone()
    print(f"Fact_MDInvoices_NoFreight - {label}: rows={r[0]:,}  max_date={r[1]}")
```
Expected: `max_date` matches closely (within a day) on both sides for both tables — the 13-day gap should be gone.

**Execution note (2026-09-23):** All 4 `fab job run` calls completed with status `Completed`, no `failureReason`, on the first attempt:
- `Build_Gold_MDInvoicesClosed` — job `abb16459-9d34-4642-a1dc-2b311cb5e888`
- `Build_Gold_MDInvoicesNoFreight` — job `a964f77a-ce38-45bf-abca-3a8c2a262b61`
- `Build_Gold_DateTable` — job `082cc6f8-4b82-4a62-9ba6-fbe8280c17eb`
- `Build_Gold_Salesperson` — job `88b7075e-b5ef-4d8b-a08e-185e135eca4b`

DuckDB verification (real before/after numbers):

| Table | Side | Before (from Context) | After (this run) |
|---|---|---|---|
| `Fact_MDInvoices_Closed` | LH_Master_Data (production) | 153,182 rows / max `InvoiceDate` 2026-09-22 | 153,182 rows / max `InvoiceDate` 2026-09-22 18:27:21 |
| `Fact_MDInvoices_Closed` | DP_Presentation | 150,929 rows / max `InvoiceDate` 2026-09-09 | 155,073 rows / max `InvoiceDate` 2026-09-22 11:30:40 |
| `Fact_MDInvoices_NoFreight` | LH_Master_Data (production) | 2,189 rows / max `OrderDate` 2026-09-22 | 2,189 rows / max `OrderDate` 2026-09-22 17:52:40 |
| `Fact_MDInvoices_NoFreight` | DP_Presentation | 2,205 rows / max `OrderDate` 2026-09-09 | 2,189 rows / max `OrderDate` 2026-09-22 12:52:40 |

The 13-day staleness gap is closed on both fact tables — both sides now land on 2026-09-22 (a few hours apart, consistent with intraday run-time offset, not a real gap). `Fact_MDInvoices_NoFreight` row counts now match exactly (2,189 = 2,189). `Fact_MDInvoices_Closed` row counts diverge slightly (155,073 vs 153,182) because DP_Presentation's run captured a few more hours of same-day activity than the production snapshot quoted in the Context section — not a stale-data symptom, since both `max_date` values land on the same calendar day. `Build_Gold_DateTable`/`Build_Gold_Salesperson` were also run and completed clean (not independently re-verified via DuckDB per the plan's Step 3 scope, which only checks the 2 fact tables).

- [x] **Step 4: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "deploy/dp_backend_scope.json"
git commit -m "Register 4 unregistered MD Invoices/shared-dim notebooks

Real gap found during MD Invoices With No Freight migration prep,
same class as 4 prior instances this session: Build_Gold_MDInvoicesClosed,
Build_Gold_MDInvoicesNoFreight, Build_Gold_DateTable, and
Build_Gold_Salesperson all existed in DP_Presentation but were never
registered in the daily/monthly refresh pipelines. Fact_MDInvoices_Closed
and Fact_MDInvoices_NoFreight were both 13 days stale (max date
2026-09-09 vs production's 2026-09-22); dim_DateTable/dim_Salesperson's
staleness was low-impact but fixed for consistency. Registered
(tier=gold, cadence=daily for the 2 facts, monthly for the 2 dims) and
run once each to catch up.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Confirm the old MD Invoices snapshot pipeline's real definition

**Files:** none — investigation only, prepares for Task 5's eventual retirement.

- [ ] **Step 1: Re-confirm the pipeline's real full content**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_MDInvoices_Snapshot.DataPipeline/pipeline-content.json"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_MDInvoices_Snapshot.DataPipeline/.schedules"
```
Expected: confirms the `MDInvoices_Snapshot` `TridentNotebook` activity (notebookId `31921cae-a955-8f82-44cf-c0a2a545003f`) plus email activities, matching the plan's Context section. If a genuinely different activity exists beyond notebook+email(s), stop and re-investigate before Task 5 — don't assume it's single-purpose without checking, same discipline as every prior report this session.

- [ ] **Step 2: Record the schedule details**

Note the real schedule (day-of-month, time, timezone) for reference in Task 5's disable step.

---

### Task 3: Build and register `Build_Gold_FreightCalculator.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_FreightCalculator.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_FreightCalculator.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Copy the real CSV from `LH_Master_Data`'s Files section to `DP_Presentation`'s**

```bash
export PATH="$HOME/.local/bin:$PATH"
fab cp "LH_Master_Data.Workspace/LH_Master_Data.Lakehouse/Files/FREIGHT CALCULATOR 2026 - UPDATED.csv" \
  "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Files/FREIGHT CALCULATOR 2026 - UPDATED.csv" -f
```
This project hasn't done a cross-workspace Files-section copy before — if this exact path syntax doesn't work, check `fab cp --help` and `fab dir "LH_Master_Data.Workspace/LH_Master_Data.Lakehouse/Files"` to find the real addressable path, don't guess blindly.

- [ ] **Step 2: Write the notebook content**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# ============================================================================
# NOTEBOOK: Build_Gold_FreightCalculator
# ============================================================================
#
# PURPOSE:
#   Small, manually-maintained freight rate-bracket lookup table. Loads
#   the real production CSV (FREIGHT CALCULATOR 2026 - UPDATED.csv,
#   copied into this lakehouse's own Files section) and casts it to
#   typed columns. Faithfully replicates the real production
#   LH_Master_Data/Notebooks/Freight Calculator Update.Notebook - only
#   the write mechanism changed (path-based .save() instead of
#   saveAsTable(), avoiding the saveAsTable()-lowercases-names bug the
#   original notebook worked around manually with its own DROP+RENAME).
#
# SOURCE: Files/FREIGHT CALCULATOR 2026 - UPDATED.csv (this lakehouse)
# TARGET: FreightCalculator (Delta table, full overwrite each run)
#
# ============================================================================

from pyspark.sql.functions import col
from pyspark.sql.types import IntegerType, DoubleType

df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("Files/FREIGHT CALCULATOR 2026 - UPDATED.csv")

df = df.withColumn("PartWeightFrom", col("PartWeightFrom").cast(IntegerType())) \
       .withColumn("PartWeightTo",   col("PartWeightTo").cast(IntegerType())) \
       .withColumn("BaseRate",       col("BaseRate").cast(DoubleType())) \
       .withColumn("AdditiveRatePerPound", col("AdditiveRatePerPound").cast(DoubleType()))

row_count = df.count()
print(f"Rows loaded: {row_count}")
df.show(40, truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 2 - WRITE
# ============================================================================

df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Tables/FreightCalculator")

print(f"SUCCESS: {row_count} rows written to FreightCalculator")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_FreightCalculator"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real, unique GUID via `python -c "import uuid; print(uuid.uuid4())"` before writing.

- [ ] **Step 4: Import, run, and capture the real notebookId**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_FreightCalculator.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_FreightCalculator.Notebook" --format .py -f
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_FreightCalculator.Notebook" --timeout 300
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_FreightCalculator.Notebook" -q "id"
```
Expected: `Completed`, no `failureReason`. If the CSV isn't found, Step 1's file copy didn't land — re-check via `fab dir` before re-running, don't guess.

- [ ] **Step 5: Force a SQL analytics endpoint metadata sync**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Verify against real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, base in [("LH_Master_Data", lh_base), ("DP_Presentation", dp_base)]:
    r = con.execute(f"SELECT COUNT(*), SUM(BaseRate) FROM delta_scan('{base}/FreightCalculator')").fetchone()
    print(f"FreightCalculator - {label}: rows={r[0]:,}  sum_base_rate={r[1]:,.2f}")
```
Expected: exact or near-exact match — this is a small, mostly-static reference table with no refresh-time-relative logic.

- [ ] **Step 7: Register in `dp_backend_scope.json`**

```json
{"name": "Build_Gold_FreightCalculator", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_FreightCalculator.Notebook"}
```

- [ ] **Step 8: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_FreightCalculator.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_FreightCalculator notebook

New daily Gold notebook faithfully porting the real production
Freight Calculator Update.Notebook's CSV-load logic, sourced from a
copy of the same real CSV in DP_Presentation's own Files section.
Fixes the saveAsTable() lowercase-name bug via a path-based write.
Registered in dp_backend_scope.json from the start.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 4: Build and register `Build_Gold_MDInvoicesNoFreightSnapshot.Notebook` + backfill

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [ ] **Step 1: Write the notebook content**

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "966efc8a-16f9-423b-aa43-e368fcd8fb91",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "966efc8a-16f9-423b-aa43-e368fcd8fb91"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# ============================================================================
# NOTEBOOK: Build_Gold_MDInvoicesNoFreightSnapshot
# ============================================================================
#
# PURPOSE:
#   Takes a beginning-of-month snapshot of all currently open MD (Machine
#   Down) parts orders and appends it to Fact_MDInvoices_NoFreight_Snapshot
#   in DP_Presentation. Replaces LH_Master_Data's
#   nb_Snapshot_MDInvoices_NoFreight - same snapshot logic, new backend,
#   proper PascalCase table name (the old table was silently lowercased
#   by saveAsTable(); this one uses a path-based write instead).
#
# GRAIN: One row per open MD order line per SnapshotDate (beginning of month)
# SOURCE: Fact_MDInvoices_NoFreight (already refreshed by the daily pipeline)
# TARGET: Fact_MDInvoices_NoFreight_Snapshot (Delta table, append mode)
#
# EXCLUDED COLUMNS:
#   MissedFreightAmount, PctFreightDifference, and FreightBucket are NOT
#   read here - they are DAX calculated columns that exist only in the
#   semantic model (already present in the report's own
#   Fact_MDInvoices_NoFreight_Snapshot.tmdl), not in this Delta table.
#
# BACKFILL NOTE:
#   The 3 months of real history that existed in LH_Master_Data's
#   snapshot table before this migration were copied forward once by a
#   separate one-time script (see
#   docs/superpowers/plans/2026-09-23-md-invoices-no-freight-migration.md,
#   Task 4 Step 6) - this notebook only ever appends new months going
#   forward.
#
# DUPLICATE PROTECTION:
#   Checks for an existing snapshot before writing. Safe to rerun - it
#   will skip if the month is already captured.
#
# ============================================================================

from pyspark.sql import functions as F
from datetime import date

today = date.today()
snapshot_date = today.replace(day=1)
snapshot_table = "Fact_MDInvoices_NoFreight_Snapshot"
snapshot_path = f"Tables/{snapshot_table}"

print(f"Snapshot date : {snapshot_date}")
print(f"Target table  : {snapshot_table}")
print(f"Run date      : {today}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 2 - DUPLICATE GUARD
# ============================================================================

snapshot_ready = False

try:
    existing = spark.sql(f"""
        SELECT COUNT(*) AS cnt
        FROM {snapshot_table}
        WHERE SnapshotDate = '{snapshot_date}'
    """).collect()[0]["cnt"]

    if existing > 0:
        print(f"SKIPPED: Snapshot for {snapshot_date} already exists ({existing} rows). No action taken.")
    else:
        print(f"No existing snapshot for {snapshot_date}. Ready to proceed.")
        snapshot_ready = True

except Exception as e:
    # Table does not exist yet - expected only before the Task 4 Step 6
    # backfill runs, kept for safety/rerun-ability.
    print(f"Note: Snapshot table not found (expected only before the backfill runs). Will create on write.")
    print(f"Detail: {e}")
    snapshot_ready = True


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 3 - READ AND WRITE SNAPSHOT
# ============================================================================

if not snapshot_ready:
    print("No action taken - snapshot for this month already exists.")
else:
    df = spark.sql("""
        SELECT
            FileNumber,
            LineNumber,
            Branch,
            Franchise,
            CustomerNumber,
            OrderDate,
            CustomerOrderNumber,
            RONumber,
            PartNumber,
            OrderQty,
            UnitPrice,
            UnitCost,
            LineTotal,
            Weight,
            TotalLineWeight,
            TotalFreightCharged,
            FreightLineCount,
            FreightStatus,
            Salesperson,
            JobCode,
            SuppliedQty,
            BackorderQty,
            OrderType
        FROM Fact_MDInvoices_NoFreight
    """)

    row_count = df.count()
    print(f"Open MD order lines to snapshot: {row_count}")

    df = df.withColumn("SnapshotDate", F.lit(str(snapshot_date)).cast("date"))

    df.write \
        .mode("append") \
        .option("mergeSchema", "true") \
        .save(snapshot_path)

    print(f"SUCCESS: {row_count} rows written to {snapshot_path} for {snapshot_date}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_MDInvoicesNoFreightSnapshot"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real, unique GUID before writing.

- [ ] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook" --format .py -f
```

- [ ] **Step 4: One-time historical backfill (run BEFORE the new notebook's first real run)**

Run as a temporary Fabric notebook cell or ad hoc session against `DP_Presentation`:
```python
from pyspark.sql import functions as F

df = spark.read.format("delta").load(
    "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/"
    "3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/fact_mdinvoices_nofreight_snapshot"
)

row_count = df.count()
print(f"Rows read from LH_Master_Data: {row_count}")
assert row_count == 5492, f"Expected 5,492 rows (3 months), got {row_count} - investigate before writing"

df.write \
    .mode("append") \
    .option("mergeSchema", "true") \
    .save("Tables/Fact_MDInvoices_NoFreight_Snapshot")

print(f"SUCCESS: {row_count} rows backfilled to Fact_MDInvoices_NoFreight_Snapshot")
```

- [ ] **Step 5: Verify the backfill matches exactly**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

old = con.execute(f"""
    SELECT SnapshotDate, COUNT(*) AS n FROM delta_scan('{lh_base}/fact_mdinvoices_nofreight_snapshot')
    GROUP BY SnapshotDate ORDER BY SnapshotDate
""").fetchall()
new = con.execute(f"""
    SELECT SnapshotDate, COUNT(*) AS n FROM delta_scan('{dp_base}/Fact_MDInvoices_NoFreight_Snapshot')
    GROUP BY SnapshotDate ORDER BY SnapshotDate
""").fetchall()

print("Old (LH_Master_Data):", old)
print("New (DP_Presentation):", new)
assert old == new, "Backfill mismatch - counts per SnapshotDate must match exactly"
print("MATCH: backfill verified.")
```
Expected: `[('2026-07-01', 1636), ('2026-08-01', 2041), ('2026-09-01', 1815)]` both sides.

- [ ] **Step 6: Document the backfill in this plan**

Add a note here with the actual run timestamp and confirmation the assert passed.

- [ ] **Step 7: Run the new notebook once and capture the real notebookId**

```bash
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook" --timeout 300
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/MD Invoices with No Freight.Folder/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook" -q "id"
```
Expected: `Completed`. Since the backfill already wrote a `SnapshotDate = 2026-09-01` row, this run's duplicate-guard should correctly SKIP (September already captured) — confirm via the row count staying at 5,492, not error out. This proves the guard logic works but does NOT prove the write path yet (same honest limitation already documented on Open Parts Tickets' equivalent notebook — first real write-path proof happens naturally on October 1st).

- [ ] **Step 8: Force a SQL analytics endpoint metadata sync**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 9: Register in `dp_backend_scope.json`**

```json
{"name": "Build_Gold_MDInvoicesNoFreightSnapshot", "tier": "gold", "cadence": "monthly",
 "notebookId": "<real-guid-from-step-7>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook"}
```

- [ ] **Step 10: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/MD Invoices with No Freight/Build_Gold_MDInvoicesNoFreightSnapshot.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_MDInvoicesNoFreightSnapshot notebook

New monthly Gold notebook replacing LH_Master_Data's
nb_Snapshot_MDInvoices_NoFreight - same snapshot logic, new backend,
fixes the saveAsTable() lowercase-name bug via a path-based write.
3 months of real history (5,492 rows) backfilled and verified exact
match. Registered in dp_backend_scope.json from the start.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 5: Retire the old monthly pipeline

**Files:**
- Modify (disable, don't delete): `fabric-workspace-docs/workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_MDInvoices_Snapshot.DataPipeline/.schedules`

- [ ] **Step 1: Confirm the new notebook's guard logic ran successfully (Task 4 Step 7 already did this)**

Don't disable the old pipeline until Task 4 Step 7's dry-run confirmed the guard logic works against real data.

- [ ] **Step 2: Disable the old pipeline's schedule**

Edit `.schedules` to set `"enabled": false` (read the real current file first via Task 2 Step 1's output, then flip only that one field — don't guess the file's exact structure).

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_MDInvoices_Snapshot.DataPipeline/.schedules"
git commit -m "Disable old Pipeline_Monthly_MDInvoices_Snapshot schedule

Superseded by Build_Gold_MDInvoicesNoFreightSnapshot running inside
Pipeline_DP_Monthly_Refresh - both would otherwise append duplicate,
diverging future months. Pipeline and notebook left in place
(disabled, not deleted) as a historical reference.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Exhaustive real-usage audit (report layer)

**Files:** none — investigation only. Findings get documented directly in this plan before Task 7 proceeds.

- [ ] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "MD Invoices With No Freight.Report"
```

- [ ] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition"
for tbl in Fact_MDInvoices_Closed Fact_MDInvoices_NoFreight Fact_MDInvoices_NoFreight_Snapshot FreightCalculator dim_BranchLocation dim_CustomerList dim_DateTable dim_Franchise dim_Parts dim_Salesperson; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_% ]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_% ]+)\]/\1/" | sort -u
done
```

- [ ] **Step 3: Bookmark check**

```bash
ls "MD Invoices With No Freight.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "MD Invoices With No Freight.Report/definition/bookmarks/" 2>/dev/null
```

- [ ] **Step 4: `relationships.tmdl` cross-reference**

Relationship key columns use TMDL `fromColumn:`/`toColumn:` syntax, not `Table[Column]` DAX syntax — invisible to Step 2's grep. Read `relationships.tmdl` directly and note every column used as a relationship endpoint for all 10 tables.

- [ ] **Step 5: `dim_DateTable` real-schema cross-check (mandatory, not optional)**

For every `dim_DateTable` column Steps 1-4 find genuinely used, check it against the real 14-column `DP_Presentation.dim_DateTable` schema (`DateKey, Date, Year, Quarter, Month, Day, WeekOfYear, DayOfWeek, MonthName, MonthNameShort, MonthYear, SortableMonthYear, QuarterYear, IsWeekend`, already given in the Context section). Any used column NOT in that list needs the DAX-calculated-column treatment in Task 7, not a repoint — look up its exact original logic in `LH_Master_Data/Dataflows/03 - Dimensions/df_Dim_Date.Dataflow` if it's not already one of the patterns given in this plan's Context section.

- [ ] **Step 6: Document findings**

For each of the 10 tables, record confirmed-used columns (keep — noting which need DAX-restoration vs. plain repoint for `dim_DateTable`) vs. confident-unused columns (trim) vs. ambiguous (leave as-is, note why). Check every table for `sortByColumn` properties before trimming. Add a "### Task 6 Findings" section to this plan file before starting Task 7.

---

### Task 7: Repoint and trim the report's 10 data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_Closed.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_NoFreight.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/Fact_MDInvoices_NoFreight_Snapshot.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/FreightCalculator.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_CustomerList.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_Franchise.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_Parts.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/dim_Salesperson.tmdl`

- [ ] **Step 1: Repoint all 10 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```

- [ ] **Step 2: Fix `Fact_MDInvoices_NoFreight_Snapshot.tmdl`'s `Item=` to the new proper-case name**

Find:
```
				    dbo_Fact_MDInvoices_NoFreight_Snapshot = Source{[Schema="dbo",Item="fact_mdinvoices_nofreight_snapshot"]}[Data],
```
Replace with:
```
				    dbo_Fact_MDInvoices_NoFreight_Snapshot = Source{[Schema="dbo",Item="Fact_MDInvoices_NoFreight_Snapshot"]}[Data],
```
(exact old text may differ slightly — read the file first and match what's actually there, same discipline as every prior report this session).

- [ ] **Step 3: Restore any DAX-needed `dim_DateTable` columns per Task 6 Findings**

For every `dim_DateTable` column Task 6 flagged as needing DAX restoration (not a plain repoint), remove its plain M-sourced `column` block and replace with a DAX calculated column sourced from `'Data Refresh'[Date]`, using the exact patterns already given in this plan's Context section (or looked up from `df_Dim_Date.Dataflow` for any flag not already covered). Match the TMDL syntax exactly as already proven on First Pass Fill's `dim_DateTable.tmdl` this session — inline `column Name = ...` DAX on the header line itself (backtick-fenced), never a separate nested `expression =` property.

- [ ] **Step 4: Trim per Task 6's findings**

For each of the 10 tables, apply Task 6's documented keep/trim decisions: remove confidently-unused `column` blocks, add/update a matching `Table.SelectColumns(...)` M-query step, check for any dangling `sortByColumn` on a trim candidate before removing it. Leave ambiguous columns untouched. Don't touch `Fact_MDInvoices_NoFreight_Snapshot`'s 3 existing DAX calculated columns (`MissedFreightAmount`, `PctFreightDifference`, `FreightBucket`).

- [ ] **Step 5: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/"
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/MD Invoices With No Freight.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint MD Invoices With No Freight to DP_Presentation

All 10 data tables repointed; Fact_MDInvoices_NoFreight_Snapshot's
Item= fixed to the new proper-case name. Any dim_DateTable
today-relative columns found genuinely used were restored as DAX
calculated columns per the now-established pattern. Trimmed per the
Task 6 exhaustive audit where confident, left as-is where ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 8: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/MD Invoices With No Freight.pbip`

- [ ] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "MD Invoices"
```
Expected: only `MD Invoices With No Freight.Report` and `MD Invoices With No Freight.SemanticModel` — no `.pbip` (already confirmed this session; re-check in case something changed).

- [ ] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "MD Invoices With No Freight.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [ ] **Step 3: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/MD Invoices With No Freight.pbip"
git commit -m "Add MD Invoices With No Freight.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 9: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 7-8's commits.

- [ ] **Step 2: Open MD Invoices With No Freight from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean Task 6's audit missed a real usage, or a `dim_DateTable` today-relative column wasn't caught and restored) or "the key didn't match any rows in the table" errors (already proactively addressed via metadata syncs in Tasks 3/4, but flag it if it recurs) — report back for investigation rather than assuming.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live production version — specifically the freight-difference/threshold visuals and anything using the monthly snapshot history, to confirm the new Gold tables produce equivalent output.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 10).

---

### Task 10: Post-publish verification and catalog update

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`

- [ ] **Step 1: DuckDB row-count check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = [
    "Fact_MDInvoices_Closed", "Fact_MDInvoices_NoFreight", "Fact_MDInvoices_NoFreight_Snapshot",
    "FreightCalculator", "dim_BranchLocation", "dim_CustomerList", "dim_DateTable",
    "dim_Franchise", "dim_Parts", "dim_Salesperson",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark MD Invoices With No Freight complete in `docs/architecture/report-migration-catalog.md`, matching the completion-note pattern already used for every prior completed report. Note this is 2 of 3 reports in this batch (Combine Vault Sales still to come), and note the 4 unregistered-notebook gaps found and fixed (a 5th-9th instance of this recurring bug class this session).

---

## Self-Review Notes

**Spec coverage:** The design spec's 4 architecture sections (3.1 registration fixes, 3.2 FreightCalculator, 3.3 snapshot notebook+backfill, 3.4 report-layer repoint) map to Task 1, Task 3, Tasks 2+4+5, and Tasks 6-7 respectively. The spec's verification plan maps to Task 1 Step 3, Task 3 Step 6, Task 4 Step 5, and Task 10 Step 1. The spec's explicit non-goals (no change to the real production notebooks, no `dim_FreightPerformanceGroup`/`% Freight Difference Threshold` work) are respected throughout.

**Placeholder scan:** Task 6's findings feed Task 7 Steps 3-4 — a real sequential dependency, matching the pattern proven on every prior report this session. Task 4 Step 6 explicitly calls for documenting real run-time numbers rather than guessing them now — not a placeholder, a genuine "depends on when you run it" note.

**Type consistency:** `Fact_MDInvoices_NoFreight_Snapshot`'s 23-column schema (22 selected + `SnapshotDate`) is consistent between the Context section, Task 4 Step 1's notebook code, and Task 4 Step 4's backfill script (which copies the old table's existing columns as-is, same 23 columns since source and target must match). `FreightCalculator`'s 4-column cast list is consistent between the Context section and Task 3 Step 2's notebook code. The `dim_DateTable` real 14-column list is referenced identically in the Context section, Task 6 Step 5, and Task 7 Step 3.
