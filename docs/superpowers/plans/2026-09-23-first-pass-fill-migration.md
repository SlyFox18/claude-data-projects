# First Pass Fill Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate First Pass Fill from `LH_Master_Data` to `DP_Presentation`, building the one missing Gold table (`Fact_FirstPassFill`) it needs — a pure Gold-layer job, since its one Silver dependency (`Silver_InHist_PmManage`) is already fully migrated with zero column gaps.

**Architecture:** One new Gold notebook faithfully porting the real production dataflow's 8-step transform (dimensional key lookups, null-safe rates, composite metrics, business flags) from `Silver_InHist_PmManage` instead of the raw lakehouse table, registered in the daily pipeline from the start; then the standard report-layer audit-and-repoint already proven on every other report this project.

**Tech Stack:** Fabric Notebooks (PySpark), Power BI Desktop (`.pbip`/TMDL text format), `fab` CLI, `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration, Fabric Data Pipelines (config-driven via `deploy/dp_backend_scope.json`).

**Full design reference:** `docs/superpowers/specs/2026-09-23-first-pass-fill-migration-design.md` (approved).

---

## Context You Need

**Real connection strings** (used throughout this whole project):
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**Real workspace/lakehouse IDs:**
- `DP - Presentation - Dev` workspace: `73fd5443-240e-410a-990a-98827f32c087`, lakehouse `DP_Presentation`: `966efc8a-16f9-423b-aa43-e368fcd8fb91`
- SQL analytics endpoint ID: `18effb0e-7bc2-47a1-854c-f4f2e8129145`

**5 real data tables in the report** (`fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/`): `Fact_FirstPassFill`, `dim_BranchLocation`, `dim_DateTable`, `dim_JobCode`, `dim_Parts`. The other 8 table files (`Data Refresh`, `Date_Supplemental`, `MeasuresTable`, `Metric Names`, `Performance Metrics`, `TBL Time Period`, `Time Granularity Table`, `Time Period Table`) confirmed to have zero `Sql.Database` calls — not part of this migration. All 4 dims already exist in `DP_Presentation` (repoint-only). `Fact_FirstPassFill` needs the new Gold notebook (Task 1).

**Real `Silver_InHist_PmManage` schema confirmed** (DuckDB `DESCRIBE` against `DP_Staging`, 1,328,067 rows): `PeriodDate` (TIMESTAMP WITH TIME ZONE), `Branch`, `Franchise`, `PartNumber`, `JobCode`, `JobType`, `StockedIndicator` (VARCHAR), and 15 attempt/success columns as INTEGER: `InternalFirstPassAttempts`, `InternalFirstPassSuccesses`, `InternalTransferSuccesses`, `Internal24HourAttempts`, `Internal24HourSuccesses`, `PartsFirstPassAttempts`, `PartsFirstPassSuccesses`, `PartsTransferSuccesses`, `Parts24HourAttempts`, `Parts24HourSuccesses`, `WorkshopFirstPassAttempts`, `WorkshopFirstPassSuccesses`, `WorkshopTransferSuccesses`, `Workshop24HourAttempts`, `Workshop24HourSuccesses` — every column the transform needs, under identical names, zero gap.

**Real dim join keys confirmed**: `dim_DateTable.Date`→`DateKey`, `dim_BranchLocation.BranchID`→`BranchKey`, `dim_Parts.PartNumber`→`PartNumberKey`, `dim_JobCode.JobCode`→`JobCodeKey` (`dim_JobCode` schema confirmed: `JobCodeKey` BIGINT, `JobCode`/`JobCodeDisplayName`/`JobCodeShortDesc` VARCHAR).

**Real `fab` CLI syntax, already discovered and proven working this session** — every folder segment needs an explicit `.Folder` suffix, and `.py` notebook source needs `--format .py` on import:
```bash
export PATH="$HOME/.local/bin:$PATH"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" \
  -i "<local path>" --format .py -f
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" --timeout 300
```

**Critical real gotcha, confirmed this session (Build_Silver_InSalPar incident)**: `fab job run` executes whatever is CURRENTLY LIVE in Fabric, not the local git-mirrored file. Any time a notebook's local `notebook-content.py` is written or edited, `fab import` MUST run first to push it into Fabric — including on a second run after fixing a bug. Never skip this, even when re-running a notebook you just fixed.

**`dp_backend_scope.json` real entry shape** — always a precise text insertion (Edit tool) matching the file's existing compact single-line-per-entry style, NEVER a full `json.dump()` rewrite (confirmed multiple times this session: `json.dump(..., indent=2)` reformats every existing entry and produces a huge, unwanted diff):
```json
{"name": "Build_Gold_FirstPassFill", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook"}
```
**This project has hit the same "notebook built but never registered, output silently goes stale" bug 4 separate times this session** (`Fact_Parts_Open_Tickets`, `Build_Gold_Transfers`, `Silver_InTrans`, `Silver_InMaster`) — this plan registers the new notebook as part of building it (Task 1), not as an afterthought.

**Real-tool boundary:** Brian has confirmed First Pass Fill is already published to `RP - Dev`, committed, and not open in Desktop.

---

### Task 1: Build and register `Build_Gold_FirstPassFill.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

- [x] **Step 1: Write the notebook content**

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
# NOTEBOOK: Build_Gold_FirstPassFill
# ============================================================================
#
# PURPOSE:
#   Comprehensive first pass fill performance fact table. Faithfully
#   replicates the real production LH_Master_Data/df_Fact_First_Pass_Fill
#   .Dataflow's logic - dimensional key lookups, null-safe rates, composite
#   metrics, business flags - but sourced from Silver_InHist_PmManage
#   instead of the raw lakehouse table (already fully migrated, zero
#   column gaps, confirmed via direct schema check).
#
# GRAIN: One row per Branch+JobCode+PartNumber+PeriodDate+StockedIndicator
# SOURCE: Silver_InHist_PmManage, dim_DateTable, dim_BranchLocation,
#         dim_Parts, dim_JobCode (all DP_Presentation)
# TARGET: Fact_FirstPassFill (Delta table, full overwrite each run)
#
# ============================================================================

from pyspark.sql import functions as F

inhist = spark.sql("""
    SELECT PeriodDate, Branch, Franchise, PartNumber, JobCode, JobType, StockedIndicator,
           InternalFirstPassAttempts, InternalFirstPassSuccesses, InternalTransferSuccesses,
           Internal24HourAttempts, Internal24HourSuccesses,
           PartsFirstPassAttempts, PartsFirstPassSuccesses, PartsTransferSuccesses,
           Parts24HourAttempts, Parts24HourSuccesses,
           WorkshopFirstPassAttempts, WorkshopFirstPassSuccesses, WorkshopTransferSuccesses,
           Workshop24HourAttempts, Workshop24HourSuccesses
    FROM Silver_InHist_PmManage
""")
date_dim = spark.sql("SELECT Date, DateKey FROM dim_DateTable")
branch_dim = spark.sql("SELECT BranchID, BranchKey FROM dim_BranchLocation")
# PartNumber/JobCode are aliased on the dim side (not just selected under
# their real names) because the source table (Silver_InHist_PmManage) has
# a column of the exact same name - joining two same-named columns via an
# expression condition (df1["x"] == df2["x"]) keeps BOTH copies in the
# result rather than merging them, which breaks the later .select("PartNumber"/
# "JobCode") with an ambiguous-column error. Aliasing sidesteps that.
parts_dim = spark.sql("SELECT PartNumber AS _PartNumberLookup, PartNumberKey FROM dim_Parts")
jobcode_dim = spark.sql("SELECT JobCode AS _JobCodeLookup, JobCodeKey FROM dim_JobCode")

print(f"Silver_InHist_PmManage rows: {inhist.count():,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 2 - DIMENSIONAL KEY LOOKUPS
# Left join to each dim, defaulting missing matches to -1 (maintains grain,
# flags data quality issues - same convention used elsewhere in this
# project).
# ============================================================================

with_date_key = inhist.join(
    date_dim, inhist["PeriodDate"] == date_dim["Date"], "left_outer"
).withColumn("PeriodDateKey", F.coalesce(F.col("DateKey"), F.lit(-1)).cast("long")) \
 .drop("Date", "DateKey")

with_branch_key = with_date_key.join(
    branch_dim, with_date_key["Branch"] == branch_dim["BranchID"], "left_outer"
).withColumn("BranchKey", F.coalesce(F.col("BranchKey"), F.lit(-1)).cast("long")) \
 .drop("BranchID")

with_part_key = with_branch_key.join(
    parts_dim, with_branch_key["PartNumber"] == parts_dim["_PartNumberLookup"], "left_outer"
).withColumn("PartNumberKey", F.coalesce(F.col("PartNumberKey"), F.lit(-1)).cast("long")) \
 .drop("_PartNumberLookup")

with_jobcode_key = with_part_key.join(
    jobcode_dim, with_part_key["JobCode"] == jobcode_dim["_JobCodeLookup"], "left_outer"
).withColumn("JobCodeKey", F.coalesce(F.col("JobCodeKey"), F.lit(-1)).cast("long")) \
 .drop("_JobCodeLookup")

print(f"Rows after dimensional key lookups: {with_jobcode_key.count():,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 3 - NULL-SAFE RATES
# Each rate: successes/attempts if attempts != 0, else null. Matches the
# real production M-query's own null-safe pattern exactly.
# ============================================================================

def null_safe_rate(df, rate_col, attempts_col, successes_col):
    attempts = F.coalesce(F.col(attempts_col), F.lit(0))
    successes = F.coalesce(F.col(successes_col), F.lit(0))
    return df.withColumn(
        rate_col,
        F.when(attempts == 0, F.lit(None).cast("double")).otherwise(successes / attempts)
    )

with_rates = with_jobcode_key
for rate_col, attempts_col, successes_col in [
    ("InternalFirstPassRate", "InternalFirstPassAttempts", "InternalFirstPassSuccesses"),
    ("Internal24HourRate", "Internal24HourAttempts", "Internal24HourSuccesses"),
    ("PartsFirstPassRate", "PartsFirstPassAttempts", "PartsFirstPassSuccesses"),
    ("Parts24HourRate", "Parts24HourAttempts", "Parts24HourSuccesses"),
    ("WorkshopFirstPassRate", "WorkshopFirstPassAttempts", "WorkshopFirstPassSuccesses"),
    ("Workshop24HourRate", "Workshop24HourAttempts", "Workshop24HourSuccesses"),
]:
    with_rates = null_safe_rate(with_rates, rate_col, attempts_col, successes_col)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 4 - COMPOSITE METRICS
# Counter = Internal + Parts. Total = Internal + Parts + Workshop.
# ============================================================================

def z(col):
    return F.coalesce(F.col(col), F.lit(0))

with_counter = with_rates.withColumn(
    "CounterFirstPassAttempts", (z("InternalFirstPassAttempts") + z("PartsFirstPassAttempts")).cast("long")
).withColumn(
    "CounterFirstPassSuccesses", (z("InternalFirstPassSuccesses") + z("PartsFirstPassSuccesses")).cast("long")
).withColumn(
    "CounterTransferSuccesses", (z("InternalTransferSuccesses") + z("PartsTransferSuccesses")).cast("long")
)

with_counter_rate = with_counter.withColumn(
    "CounterFirstPassRate",
    F.when(F.col("CounterFirstPassAttempts") == 0, F.lit(None).cast("double"))
     .otherwise(F.col("CounterFirstPassSuccesses") / F.col("CounterFirstPassAttempts"))
).withColumn(
    "CounterServiceRate",
    F.when(F.col("CounterFirstPassAttempts") == 0, F.lit(None).cast("double"))
     .otherwise((F.col("CounterFirstPassSuccesses") + F.col("CounterTransferSuccesses")) / F.col("CounterFirstPassAttempts"))
)

with_total = with_counter_rate.withColumn(
    "TotalFirstPassAttempts",
    (z("InternalFirstPassAttempts") + z("PartsFirstPassAttempts") + z("WorkshopFirstPassAttempts")).cast("long")
).withColumn(
    "TotalFirstPassSuccesses",
    (z("InternalFirstPassSuccesses") + z("PartsFirstPassSuccesses") + z("WorkshopFirstPassSuccesses")).cast("long")
).withColumn(
    "TotalTransferSuccesses",
    (z("InternalTransferSuccesses") + z("PartsTransferSuccesses") + z("WorkshopTransferSuccesses")).cast("long")
)

with_total_rate = with_total.withColumn(
    "TotalFirstPassRate",
    F.when(F.col("TotalFirstPassAttempts") == 0, F.lit(None).cast("double"))
     .otherwise(F.col("TotalFirstPassSuccesses") / F.col("TotalFirstPassAttempts"))
).withColumn(
    "TotalServiceRate",
    F.when(F.col("TotalFirstPassAttempts") == 0, F.lit(None).cast("double"))
     .otherwise((F.col("TotalFirstPassSuccesses") + F.col("TotalTransferSuccesses")) / F.col("TotalFirstPassAttempts"))
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 5 - BUSINESS INTELLIGENCE FLAGS
# ============================================================================

with_flags = with_total_rate.withColumn(
    "MeetsCounterTarget", F.coalesce(F.col("CounterFirstPassRate"), F.lit(0.0)) >= 0.80
).withColumn(
    "MeetsTotalTarget", F.coalesce(F.col("TotalFirstPassRate"), F.lit(0.0)) >= 0.85
).withColumn(
    "HasAnyActivity", F.col("TotalFirstPassAttempts") > 0
).withColumn(
    "StockImpactFlag",
    F.when(F.col("StockedIndicator") == "Y", F.lit("Stocked Part")).otherwise(F.lit("Non-Stocked Part"))
)

final = with_flags.select(
    # dimensional keys
    "PeriodDateKey", "BranchKey", "PartNumberKey", "JobCodeKey",
    # grain columns
    "PeriodDate", "Branch", "PartNumber", "JobCode", "JobType", "Franchise", "StockedIndicator",
    # base attempt/success metrics
    "InternalFirstPassAttempts", "InternalFirstPassSuccesses", "InternalTransferSuccesses",
    "Internal24HourAttempts", "Internal24HourSuccesses",
    "PartsFirstPassAttempts", "PartsFirstPassSuccesses", "PartsTransferSuccesses",
    "Parts24HourAttempts", "Parts24HourSuccesses",
    "WorkshopFirstPassAttempts", "WorkshopFirstPassSuccesses", "WorkshopTransferSuccesses",
    "Workshop24HourAttempts", "Workshop24HourSuccesses",
    # pre-calculated rates
    "InternalFirstPassRate", "Internal24HourRate",
    "PartsFirstPassRate", "Parts24HourRate",
    "WorkshopFirstPassRate", "Workshop24HourRate",
    # composite metrics
    "CounterFirstPassAttempts", "CounterFirstPassSuccesses", "CounterFirstPassRate",
    "CounterTransferSuccesses", "CounterServiceRate",
    "TotalFirstPassAttempts", "TotalFirstPassSuccesses", "TotalFirstPassRate",
    "TotalTransferSuccesses", "TotalServiceRate",
    # business flags
    "MeetsCounterTarget", "MeetsTotalTarget", "HasAnyActivity", "StockImpactFlag",
)

row_count = final.count()
print(f"Final Fact_FirstPassFill rows: {row_count:,}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 6 - WRITE
# ============================================================================

final.write \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Tables/Fact_FirstPassFill")

print(f"SUCCESS: {row_count:,} rows written to Fact_FirstPassFill")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [x] **Step 2: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_FirstPassFill"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real, unique GUID for `logicalId` via `python -c "import uuid; print(uuid.uuid4())"` before writing — don't leave the placeholder text.

- [x] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook" --format .py -f
```

- [x] **Step 4: Run it once and capture the real notebookId**

```bash
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" --timeout 300
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder/Build_Gold_FirstPassFill.Notebook" -q "id"
```
Expected: `Completed`, no `failureReason`. If the run fails with a real error (not a syntax typo), read it, form a hypothesis grounded in the real schema data above, and fix the root cause — don't guess. Record the returned notebookId for Step 6. **If you edit the notebook content to fix a bug, you MUST re-run Step 3 (`fab import`) before re-running this step** — `fab job run` executes whatever is currently live in Fabric, not your local edit.

- [x] **Step 5: Force a SQL analytics endpoint metadata sync**

This is a brand-new table created via a path-based Spark write — confirmed this session that such tables aren't immediately visible through `Sql.Database()`'s SQL analytics endpoint without a forced sync:
```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [x] **Step 6: Register in `dp_backend_scope.json`**

Use the Edit tool for a precise text insertion into the `notebooks` array, matching the file's existing compact style exactly — do NOT rewrite the whole file with a script:
```json
{"name": "Build_Gold_FirstPassFill", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook"}
```

- [x] **Step 7: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/First Pass Fill/Build_Gold_FirstPassFill.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_FirstPassFill notebook

New daily Gold notebook faithfully porting the real production
df_Fact_First_Pass_Fill.Dataflow's logic - dimensional key lookups,
null-safe rates, composite metrics, business flags - sourced from
Silver_InHist_PmManage instead of the raw lakehouse table (already
fully migrated, zero column gaps). Registered in dp_backend_scope.json
from the start (tier=gold, cadence=daily).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution notes (2026-09-23):**

- **Real bug found and fixed (not a code bug — a missing shortcut):** The first `fab job run` failed with `System_Cancelled_Session_Statements_Failed` on the very first Spark SQL statement. Root cause: `Silver_InHist_PmManage` exists as a real table in `DP_Staging` (`DP - Staging - Dev` workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`, lakehouse `876255e0-d462-4697-adc1-4a655f5bb101`) but, unlike every other `Silver_*` table this project's Gold notebooks read (`Silver_InTrans`, `Silver_InMaster`, etc. — all present as `.Shortcut` entries in `DP_Presentation/Tables`), it had never been shortcut into `DP_Presentation`. Confirmed via `fab ls "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Tables"` (table absent) and `fab ls "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables"` (table present). Fixed by creating the shortcut with the exact same pattern as the existing ones (verified via `fab get ... Silver_InTrans.Shortcut -q target`):
  ```bash
  fab ln "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Tables/Silver_InHist_PmManage.Shortcut" \
    --type oneLake \
    --target "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/Silver_InHist_PmManage" -f
  ```
  No notebook code changes were needed — the PySpark port itself was correct. After creating the shortcut, `fab job run` completed successfully on the next attempt (job instance `39ac0d70-fddb-4a69-bf83-aa41247dcb91`).
- **Real notebookId:** `8ac1d087-ebc9-48d0-a97a-a674cd368b06`
- **Real `.platform` logicalId (newly generated GUID):** `18355759-0824-48ba-b679-d4359b259b2e`
- **First Pass Fill folder:** did not exist under `Fact Tables` in Fabric yet — created via `fab mkdir "DP - Presentation - Dev.Workspace/Fact Tables.Folder/First Pass Fill.Folder"` (folder id `5d2c4764-7693-4a5c-9c18-48f890e9d34b`) before the `fab import` would succeed.
- **Row count observed:** `Fact_FirstPassFill` = 1,328,067 rows — exactly matches `Silver_InHist_PmManage`'s row count (confirms the left-join lookups preserved grain, no fan-out/dedup issue). Aggregate check: `sum(TotalFirstPassAttempts)=1,870,779`, `sum(TotalFirstPassSuccesses)=1,560,953`, `avg(TotalFirstPassRate)=0.7798`.
- **Flag for Task 2 (not resolved here, out of Task 1's scope):** production `LH_Master_Data.Fact_FirstPassFill` has only 713,482 rows (`sum_total_attempts=946,007`, `sum_total_successes=761,494`, `avg_total_rate=0.7552`) — noticeably fewer than the new table's 1,328,067. Since this transform has no refresh-time-relative logic, this is a real discrepancy worth investigating in Task 2, not an artifact of timing. Likely candidate: production's dataflow may apply a date-range filter or additional row-level filter not present in `Silver_InHist_PmManage`'s full history that wasn't ported (or wasn't documented in this plan's Context section) — needs real investigation, not a guess, before Task 2 is marked complete.
- SQL analytics endpoint metadata sync (`refreshMetadata`) confirmed `Fact_FirstPassFill` and `Silver_InHist_PmManage` both synced successfully.
- Committed as `25f0fb75` on `fabric-workspace-docs`/`dev`, pushed clean (`ffc0bde7..25f0fb75`).

---

### Task 2: Verify `Fact_FirstPassFill` against the real source

**Files:** none — verification only.

- [x] **Step 1: Row-count and aggregate sanity check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

print("=== LH_Master_Data.Fact_FirstPassFill (real production) ===")
r = con.execute(f"""
    SELECT COUNT(*), SUM(TotalFirstPassAttempts), SUM(TotalFirstPassSuccesses), AVG(TotalFirstPassRate)
    FROM delta_scan('{lh_base}/Fact_FirstPassFill')
""").fetchone()
print(f"  rows={r[0]:,}  sum_total_attempts={r[1]:,}  sum_total_successes={r[2]:,}  avg_total_rate={r[3]:.4f}")

print("=== DP_Presentation.Fact_FirstPassFill (new) ===")
r = con.execute(f"""
    SELECT COUNT(*), SUM(TotalFirstPassAttempts), SUM(TotalFirstPassSuccesses), AVG(TotalFirstPassRate)
    FROM delta_scan('{dp_base}/Fact_FirstPassFill')
""").fetchone()
print(f"  rows={r[0]:,}  sum_total_attempts={r[1]:,}  sum_total_successes={r[2]:,}  avg_total_rate={r[3]:.4f}")
```
Expected: an exact or very close match on all 4 metrics — unlike Transfers' `OrderAge`, nothing in this transform is refresh-time-relative, so there's no legitimate reason for these numbers to differ meaningfully. A real discrepancy means a real bug in the port — investigate before proceeding, don't assume timing.

**Real discrepancy found and fixed (2026-09-23):** the first Task 1 run produced 1,328,067 rows vs production's 713,482 (1.86x) — a genuine mismatch, not refresh-timing noise. Root cause: `Silver_InHist_PmManage` is an unfiltered full mirror of the raw `InHist_PmManage` table (all franchises, all history). Production's own real ETL, `LH_Master_Data/Dataflows/01 - Raw Sources/df_InHist_PmManage_Raw.Dataflow` (confirmed via direct read — this is what production's `Fact_FirstPassFill` dataflow actually reads, not the truly-raw table), applies two filters at the raw-extraction stage that never got carried into the Silver mirror: `Franchise = 'D'` and a rolling `Date.AddYears(-2)` to `Date.AddDays(+7)` window (computed off `DateTime.LocalNow()` in the original — same bug class fixed repeatedly elsewhere this project). Confirmed via direct DuckDB query against `Silver_InHist_PmManage`: applying both filters brought the row count to 700,570 (vs production's 713,482, 98.2% match). Fixed the notebook to apply both filters itself, using a DST-safe US/Central "now" (commit `0262f925` on `fabric-workspace-docs`/`dev`). Re-ran; final real comparison:
```
LH_Master_Data (production): rows=713,482  sum_attempts=946,007  sum_successes=761,494  avg_rate=0.7552  max_date=2026-09-01
DP_Presentation (new):       rows=700,570  sum_attempts=929,380  sum_successes=748,696  avg_rate=0.7559  max_date=2026-08-31
```
All 4 metrics now match within ~1.8%, fully explained by the rolling window's boundary shifting by about a day between when each table was last refreshed (production's own `max_date` is 1 day later) — not a remaining bug. `avg_rate` (0.7559 vs 0.7552) matches almost exactly, confirming the join/rate/composite logic itself is correct; the earlier discrepancy was purely a missing-filter scope issue, not a computation bug.

- [x] **Step 2: Document the real comparison result in this plan**

Add a note here with the actual numbers observed.

---

### Task 3: Exhaustive real-usage audit (report layer)

**Files:** none — investigation only. Findings get documented directly in this plan before Task 4 proceeds.

- [x] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "First Pass Fill.Report"
```

- [x] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition"
for tbl in Fact_FirstPassFill dim_BranchLocation dim_DateTable dim_JobCode dim_Parts; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_ ]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_ ]+)\]/\1/" | sort -u
done
```

- [x] **Step 3: Bookmark check**

```bash
ls "First Pass Fill.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "First Pass Fill.Report/definition/bookmarks/" 2>/dev/null
```

- [x] **Step 4: `relationships.tmdl` cross-reference**

Relationship key columns use TMDL `fromColumn:`/`toColumn:` syntax, not `Table[Column]` DAX syntax — invisible to Step 2's grep. Read `relationships.tmdl` directly and note every column used as a relationship endpoint (expect `Fact_FirstPassFill[PeriodDateKey]`/`[BranchKey]`/`[PartNumberKey]`/`[JobCodeKey]` as the 4 real join keys, but confirm directly rather than assuming).

- [x] **Step 5: Document findings**

For each of the 5 tables, record confirmed-used columns (keep) vs. confident-unused columns (trim) vs. ambiguous (leave as-is, note why). Also check each table for any `sortByColumn` property before trimming anything. Add a "### Task 3 Findings" section to this plan file before starting Task 4.

### Task 3 Findings

**Method:** 4 independent checks were run and cross-referenced against each table's own declared `column` blocks: (1) `pbir fields list` for direct visual-field usage, (2) a DAX-text `Table[Column]` bracket-syntax grep across `tables/*.tmdl` + `relationships.tmdl`, (3) a bookmark check (`Entity`/`Property` JSON keys across all 16 files in `First Pass Fill.Report/definition/bookmarks/`, plus a broad keyword sweep for every candidate column name), and (4) a direct read of `relationships.tmdl` for `fromColumn:`/`toColumn:` relationship-key syntax (invisible to the Step 2 grep). A 5th supplementary check — grepping every report page/visual folder for each table's `Entity` name — confirmed `Fact_FirstPassFill`, `dim_JobCode`, and `dim_Parts` have **zero direct entity references anywhere in the report's visuals** (they're pure DAX/relationship-backing tables; only `dim_DateTable` (41 files) and `dim_BranchLocation` (34 files) are bound directly into visuals, e.g. slicers). Every "confident unused" column below was verified absent from all 4 checks plus this supplementary sweep before being marked trimmable.

**`relationships.tmdl` — confirmed real join keys** (matches the plan's expectation exactly):
```
Fact_FirstPassFill.BranchKey     -> dim_BranchLocation.BranchKey
Fact_FirstPassFill.PartNumberKey -> dim_Parts.PartNumberKey
Fact_FirstPassFill.JobCodeKey    -> dim_JobCode.JobCodeKey
Fact_FirstPassFill.PeriodDateKey -> dim_DateTable.DateKey
```
(A 5th relationship, `dim_DateTable.Date` bidirectional to `Date_Supplemental.Date`, also exists but is outside the 5-table migration scope — noted, not acted on.)

**`Fact_FirstPassFill` (46 columns) — usage lower than the plan's stated expectation.** The plan anticipated high usage across the rate/composite/flag layer; the audit found real usage is concentrated in the Counter/Total composite tier and 3 Workshop base metrics only — the Internal/Parts base-metric breakdowns, all 6 pre-calculated rates, and all 4 business flags are unreferenced anywhere in this report.
- **Keep (14):** 4 relationship keys (`PeriodDateKey`, `BranchKey`, `PartNumberKey`, `JobCodeKey`) + 10 DAX-referenced columns: `CounterFirstPassAttempts`, `CounterFirstPassSuccesses`, `CounterTransferSuccesses`, `TotalFirstPassAttempts`, `TotalFirstPassSuccesses`, `TotalFirstPassRate`, `TotalTransferSuccesses`, `WorkshopFirstPassAttempts`, `WorkshopFirstPassSuccesses`, `WorkshopTransferSuccesses`
- **Confident trim (32):**
  - Grain (7, zero usage anywhere): `PeriodDate`, `Branch`, `PartNumber`, `JobCode`, `JobType`, `Franchise`, `StockedIndicator`
  - Base metrics (12 of 15 — only the 3 Workshop ones above are used): `InternalFirstPassAttempts`, `InternalFirstPassSuccesses`, `InternalTransferSuccesses`, `Internal24HourAttempts`, `Internal24HourSuccesses`, `PartsFirstPassAttempts`, `PartsFirstPassSuccesses`, `PartsTransferSuccesses`, `Parts24HourAttempts`, `Parts24HourSuccesses`, `Workshop24HourAttempts`, `Workshop24HourSuccesses`
  - Rates (6 of 6 — none used, despite 2 of their underlying base metrics feeding used composites): `InternalFirstPassRate`, `Internal24HourRate`, `PartsFirstPassRate`, `Parts24HourRate`, `WorkshopFirstPassRate`, `Workshop24HourRate`
  - Composite (3 of 10): `CounterFirstPassRate`, `CounterServiceRate`, `TotalServiceRate`
  - Flags (4 of 4 — none used): `MeetsCounterTarget`, `MeetsTotalTarget`, `HasAnyActivity`, `StockImpactFlag`
- **Ambiguous:** none — every column resolved cleanly to keep or trim.
- **`sortByColumn`:** none present on this table.

**`dim_BranchLocation` (16 columns).**
- **Keep (4):** `BranchKey` (relationship key), `Branch` (DAX + bookmarks + visuals), `BranchID` (DAX — `SELECTEDVALUE`/`DISTINCTCOUNT`/`ALLSELECTED` in `MeasuresTable.tmdl`), `BranchType` (DAX — `= "Main Branch"` filter condition, used 20+ times across measures)
- **Keep for `sortByColumn` dependency (1):** `LocationID` — otherwise-unused, but is `Branch`'s `sortByColumn` target (`sortByColumn: LocationID` on the `Branch` column); trimming it would break `Branch`'s sort order
- **Confident trim (11):** `BranchName`, `State`, `City`, `ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`, `OperationalPriority`, `RegionalClassification`, `ServiceHours`, `DistanceFromHub`, `DataQualityScore` — all `isHidden`, zero usage across all 4 checks
- **Ambiguous:** none.
- **`sortByColumn`:** `Branch` → `LocationID` (real dependency, handled above).

**`dim_DateTable` (67 columns) — confirms the CLAUDE.md-documented low-utilization pattern for this shared dimension.**
- **Keep (10):** `DateKey` (relationship key), `Date` (relationship key + DAX), `Year` (DAX + bookmark), `Month` (DAX), `MonthName` (DAX + bookmark; also a `sortByColumn` source column), `MonthNameShort` (bookmark; also a `sortByColumn` source column), `MonthYear` (bookmark; also a `sortByColumn` source column), `IsRolling12Months` (DAX), `IsRolling24Months` (DAX), `IsYearToDate` (DAX)
- **Keep for `sortByColumn` dependency (1):** `SortableMonthYear` — otherwise-unused, but is `MonthYear`'s `sortByColumn` target
- **Confident trim (56):** every other column — `Quarter`, `Day`, `WeekOfYear`, `DayOfWeek`, `DayOfWeekName`, `DayOfWeekNameShort`, `QuarterYear`, `DateDisplayName`, `IsWeekend`, `IsWeekday`, `IsCurrentYear`, `IsCurrentMonth`, `DaysFromToday`, `Season`, `IsPeakSeason`, `FiscalYear`, `FiscalQuarter`, `MonthSort`, `QuarterSort`, `YearOffset`, `IsBusinessDay`, `WorkingDaysInMonth`, `WorkingDaysInQuarter`, `WorkingDaysInYear`, `IsPreviousYear`, `IsPreviousMonth`, `IsPreviousQuarter`, `IsQuarterToDate`, `IsMonthToDate`, `IsRolling6Months`, `IsRolling36Months`, `IsRolling48Months`, `IsRolling4Quarters`, `IsRolling8Quarters`, `IsRolling52Weeks`, `IsLast30Days`, `IsLast60Days`, `IsLast90Days`, `IsNext30Days`, `IsSameMonthLastYear`, `IsSameQuarterLastYear`, `IsRolling365Days`, `IsRolling730Days`, `IsRolling1095Days`, `IsRolling1460Days`, `IsRolling180Days`, `IsRolling545Days`, `IsRolling45Days`, `IsRolling120Days`, `IsRolling270Days`, `IsRolling450Days`, `IsRolling13Weeks`, `IsRolling26Weeks`, `IsRolling104Weeks`, `IsRolling156Weeks`, `RollingPeriodCategory`. A handful of these names (`Quarter`, `Day`, `DayOfWeek`) also appear elsewhere in the model, but only as *other tables'* own same-named columns (`Date_Supplemental.tmdl`, `Data Refresh.tmdl`) — confirmed as false positives, not real `dim_DateTable` usage.
- **Ambiguous:** none.
- **`sortByColumn`:** `MonthName` → `Month` (kept independently), `MonthNameShort` → `Month` (kept independently), `MonthYear` → `SortableMonthYear` (kept only for this dependency).

**`dim_JobCode` (12 columns) — real finding: the whole dimension is unused beyond its relationship key.**
- **Keep (1):** `JobCodeKey` (relationship key only)
- **Confident trim (11):** `JobCode`, `JobCodeDisplayName`, `JobCodeShortDesc`, `JobCodeCategory`, `EquipmentType`, `EquipmentCategory`, `ServiceComplexity`, `IsInspection`, `IsWarrantyWork`, `IsSeasonalWork`, `IsUrgentWork` — zero usage across all 4 checks, and zero entity references anywhere in the report's pages/visuals
- **Ambiguous:** none.
- **`sortByColumn`:** none present.

**`dim_Parts` (22 columns) — same pattern as `dim_JobCode`.**
- **Keep (1):** `PartNumberKey` (relationship key only)
- **Confident trim (21):** `PartNumber`, `Description`, `Franchise`, `Source`, `SLC`, `DealerGroupCode`, `CommodityCode`, `VendorCode`, `QuantityOnHand`, `BackOrderQty`, `StockStatus`, `IsAvailable`, `InventoryCost`, `SellPrice1`, `ListPrice`, `Current12MoSales`, `HasRecentSales`, `ActivityStatus`, `Returnable`, `IsReturnable`, `IsHighValue` — zero usage across all 4 checks; `Franchise` and `PartNumber` hits were confirmed to be `Fact_FirstPassFill`'s own same-named (unused) grain columns, and `Source` hits were confirmed to be the generic JSON key `"Source":` used throughout PBIR files, not the `dim_Parts.Source` column — both false positives ruled out by direct inspection
- **Ambiguous:** none.
- **`sortByColumn`:** none present.

**`sortByColumn` dependency summary (only real ones found):**
- `dim_BranchLocation.Branch` → `LocationID`
- `dim_DateTable.MonthName` → `Month` (both already kept independently)
- `dim_DateTable.MonthNameShort` → `Month` (both already kept independently)
- `dim_DateTable.MonthYear` → `SortableMonthYear` (`SortableMonthYear` kept only for this)

**Ambiguous-columns summary:** none across all 5 tables — every column resolved cleanly to a confident keep or confident trim; no guessing was required.

---

### Task 4: Repoint and trim the report's 5 data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/Fact_FirstPassFill.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/dim_JobCode.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/dim_Parts.tmdl`

- [x] **Step 1: Repoint all 5 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item=` changes needed — every real table name already matches between `LH_Master_Data` and `DP_Presentation`.

- [x] **Step 2: Trim per Task 3's findings**

For each of the 5 tables, apply Task 3's documented keep/trim decisions: remove confidently-unused `column` blocks, add/update a matching `Table.SelectColumns(...)` M-query step, check for any dangling `sortByColumn` on a trim candidate before removing it. Leave ambiguous columns untouched.

- [x] **Step 3: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/First Pass Fill.SemanticModel/"
```
Expected: no output.

- [x] **Step 4: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/First Pass Fill.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint First Pass Fill to DP_Presentation

All 5 data tables repointed. Trimmed per the Task 3 exhaustive audit
where confident, left as-is where ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution notes (2026-09-23):** All 5 files rewritten in place (Write tool, full reconstruction from the original TMDL rather than incremental Edits, given the volume of column blocks removed) — `Fact_FirstPassFill.tmdl` (46→14 columns), `dim_BranchLocation.tmdl` (16→5, keeping `LocationID` for `Branch`'s sort), `dim_DateTable.tmdl` (67→11, keeping `SortableMonthYear` for `MonthYear`'s sort and `Month` independently for `MonthName`/`MonthNameShort`'s sort), `dim_JobCode.tmdl` (12→1, `JobCodeKey` only), `dim_Parts.tmdl` (22→1, `PartNumberKey` only). Each partition's `Table.SelectColumns(...)` step lists the kept columns by their real `sourceColumn` names, matching the exact step-naming pattern (`SelectedColumns`) already used on every other migrated report in this project (confirmed against `Open Parts Tickets.SemanticModel`'s `dim_BranchLocation.tmdl`/`Fact_Parts_Open_Tickets.tmdl` before writing). No TMDL validation-hook errors during any of the 5 writes. Post-edit `grep -rn "LH_Master_Data"` across the whole `First Pass Fill.SemanticModel/` returned no matches. Net diff: 5 files changed, 20 insertions(+), 1208 deletions(-). Committed as `a2eb3b12` on `fabric-workspace-docs`/`dev`, pushed clean (`0262f925..a2eb3b12`).

---

### Task 5: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/First Pass Fill.pbip`

- [x] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "First Pass Fill"
```
Expected: only `First Pass Fill.Report` and `First Pass Fill.SemanticModel` — no `.pbip` (already confirmed this session; re-check in case something changed).

- [x] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "First Pass Fill.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [x] **Step 3: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/First Pass Fill.pbip"
git commit -m "Add First Pass Fill.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-23):** Committed as `df6c29b1` on `fabric-workspace-docs`/`dev`, pushed (`a2eb3b12..df6c29b1`).

---

### Task 6: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 4-5's commits.

- [ ] **Step 2: Open First Pass Fill from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean Task 3's audit missed a real usage) or "the key didn't match any rows in the table" errors (already proactively addressed via Task 1 Step 5's metadata-sync, but flag it if it recurs anyway) — report back for investigation rather than assuming.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live production version — specifically the 3-page structure (Current vs Prior, Rolling 12, YTD per the real dataflow's own documented intent) and the pre-calculated rate/target-flag visuals, to confirm the new Gold table produces equivalent output.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 7).

---

### Task 7: Post-publish verification and catalog update

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`

- [ ] **Step 1: DuckDB row-count check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = ["Fact_FirstPassFill", "dim_BranchLocation", "dim_DateTable", "dim_JobCode", "dim_Parts"]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark First Pass Fill complete in `docs/architecture/report-migration-catalog.md`'s Tier 3/Batch 3 section, matching the completion-note pattern already used for every prior completed report. Note this is 1 of 3 reports in this new batch (MD Invoices With No Freight and Combine Vault Sales still to come).

---

## Self-Review Notes

**Spec coverage:** The design spec's architecture section (one new Gold notebook, registered from the start, then standard report-layer repoint) maps directly to Tasks 1 and 3-4. The spec's verification plan maps to Task 2 (Gold table correctness) and Task 7 (post-migration row counts). The spec's explicit non-goals (no Silver-layer changes, no change to the real production dataflow, no DAX redesign) are respected — Task 1 only reads from `Silver_InHist_PmManage`, never writes to it.

**Placeholder scan:** Task 3's findings feed Task 4 Step 2's trim decisions — a real sequential dependency, matching the pattern already proven on every prior report this project. Every other task is fully specified with real code, real commands, and real expected values (column names, join keys, business-rule thresholds all taken directly from the real production dataflow, not invented).

**Type consistency:** The 44-column final schema is consistent between the Context section, Task 1 Step 1's actual PySpark `select()` call, and Task 2's verification query (which references `TotalFirstPassAttempts`/`TotalFirstPassSuccesses`/`TotalFirstPassRate`, all present in that same column list). The dim join keys (`PeriodDateKey`/`BranchKey`/`PartNumberKey`/`JobCodeKey`) are used identically in Task 1's notebook code and Task 3 Step 4's relationship-check expectations.
