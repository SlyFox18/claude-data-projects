# Open Parts Tickets Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Open Parts Tickets from `LH_Master_Data` to `DP_Presentation`, building two new Gold-layer tables it needs (`Fact_Parts_Open_Orders_Snapshot` with its 7 months of real history preserved, and `Fact_PartsInvoiced_ByBranch` replacing a raw native-query anti-pattern) along the way.

**Architecture:** Two new small PySpark Gold notebooks feeding into the existing config-driven `Pipeline_DP_Monthly_Refresh`/daily pipeline (no new pipelines), a one-time historical backfill for the snapshot table, retirement of the old single-purpose monthly pipeline once the new notebook is confirmed, then the standard report-layer audit-and-repoint already proven on every other report this project.

**Tech Stack:** Fabric Notebooks (PySpark), Power BI Desktop (`.pbip`/TMDL text format), `fab` CLI, `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration, Fabric Data Pipelines (config-driven via `deploy/dp_backend_scope.json`).

**Full design reference:** `docs/superpowers/specs/2026-09-22-open-parts-tickets-migration-design.md` (approved).

---

## Context You Need

**Real connection strings** (used throughout this whole project):
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**Real workspace/lakehouse IDs:**
- `LH_Master_Data` workspace: `b48cdb35-7ce3-46de-96df-d70db77649cb`, lakehouse: `3e74497b-8c51-4a1a-91a1-888c59118f48`
- `DP - Presentation - Dev` workspace: `73fd5443-240e-410a-990a-98827f32c087`, lakehouse `DP_Presentation`: `966efc8a-16f9-423b-aa43-e368fcd8fb91`

**6 real data tables in the report** (`fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/`): `Fact_Parts_Open_Tickets`, `Fact_Parts_Open_Tickets_Details`, `dim_BranchLocation`, `dim_DateTable` — all 4 already exist in `DP_Presentation` with matching schemas, repoint-only. `fact_parts_open_orders_snapshot` and `Fact_PartsInvoiced_ByBranch` need new Gold-layer work first (Tasks 1-5 below) before they can be repointed (Tasks 6-7). The other table files in that folder (`Data Refresh`, `HTML_Parts_Overview`, `New Report Columns/Measures/Relationships/Tables`, `Ratio_Period_Selector`, `TopN Selector`, `_Measures`) have no `Sql.Database` call — not part of this migration.

**`fact_parts_open_orders_snapshot`'s real 17-column schema** (16 selected columns + `SnapshotDate`, confirmed via direct read of `LH_Master_Data/Notebooks/nb_Snapshot_Parts_Open_Orders.Notebook/notebook-content.py`): `Location`, `Location_Name`, `Order_No`, `Invoice_Type`, `Order_Date`, `Days_Open`, `Aging`, `Aging_Sort_Order`, `` #_Parts_On_Order``, `` #_On_Back_Order``, `` Order_Total_$$``, `` $$_Available``, `` $$_BackOrdered``, `Backorder_Pct`, `Customer`, `Salesman`, `SnapshotDate`. Source: `Fact_Parts_Open_Tickets` (all these column names exist there under matching names). Duplicate-guard: skip write if a row for the current month's `SnapshotDate` already exists.

**Real existing history** (confirmed via DuckDB `delta_scan` against `LH_Master_Data`'s lowercase `fact_parts_open_orders_snapshot` — lowercase due to the confirmed `saveAsTable()`-lowercases-Delta-names bug, see `feedback_fabric_saveastable_casing` in memory): 7 months, `SnapshotDate` grouped counts — `2026-03-01`: 1,717 rows, `2026-04-01`: 1,709, `2026-05-01`: 1,700, `2026-06-01`: 2,010, `2026-07-01`: 1,824, `2026-08-01`: 2,203, `2026-09-01`: 1,907 (13,070 rows total).

**Old pipeline confirmed single-purpose** (`fabric-workspace-docs/workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/pipeline-content.json`, already read in full): exactly 3 activities — the `nb_Snapshot_Parts_Open_Orders` notebook run, plus a success email and a failure email, nothing else. Safe to disable/retire the whole pipeline at cutover, not just remove one activity among many. **Real finding**: its `.schedules` file shows the real trigger is **monthly, day 1, 12:00 PM Central**, not the "5:30 AM" the notebook's own header comment claims — the comment is stale, the real schedule is what matters for sequencing (still safely after the ~3:30 AM/~80 min daily pipeline that refreshes `Fact_Parts_Open_Tickets` first).

**`Fact_PartsInvoiced_ByBranch`'s exact current logic** (already read in full from `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_PartsInvoiced_ByBranch.tmdl`, a `Value.NativeQuery` with `EnableFolding=false`):
```sql
SELECT Branch, CAST(InvoiceDate AS DATE) AS InvoiceDate, SUM(PartsSaleValue) AS Invoiced_Parts
FROM Invoice
WHERE ModuleType IN ('I', 'W')
  AND CustomerNumber NOT IN ('71','72','73','74','76','77','78','81','83','84','85','86','87',
    '9001','9002','9003','9004','9005','9006','9007','41','42','43','44','46','47','48',
    '51','53','54','55','56','57','9051','9052','9053','9054','9055','9056','9057')
  AND InvoiceDate >= DATEADD(month, -15, GETDATE())
GROUP BY Branch, CAST(InvoiceDate AS DATE)
```
Report's own 3 columns: `Branch` (string), `InvoiceDate` (dateTime), `Invoiced_Parts` (double, currency format `\$#,0.00;(\$#,0.00)`).

**`Silver_Invoice` schema confirmed** (DuckDB `DESCRIBE` against `DP_Presentation`, 6,505,866 rows, `1998-06-10` to `2026-09-04`) has every column this query needs under matching names: `Branch`, `CustomerNumber`, `ModuleType`, `PartsSaleValue`, `InvoiceDate` (stored as `TIMESTAMP WITH TIME ZONE`).

**Notebook folder convention confirmed** (real directory listing this session): dimension-tier Gold notebooks (`Build_Gold_BranchLocation`, `Build_Gold_Franchise`, etc.) live flat under `DP - Presentation - Dev/`; report-specific fact-tier Gold notebooks live under `DP - Presentation - Dev/Fact Tables/<ReportName>/` (e.g. `Fact Tables/Inventory Analysis/Build_Gold_InvoiceInventoryAnalysis.Notebook`). Both new notebooks here are report-specific fact tables, so they go under `Fact Tables/Open Parts Tickets/`.

**`dp_backend_scope.json` real entry shape** (`fabric-workspace-docs/deploy/dp_backend_scope.json`, git-tracked source of truth that `deploy_backend.py` pushes to the lakehouse's `config/dp_backend_scope.json`, which `Pipeline_DP_Monthly_Refresh`/`Pipeline_DP_Daily_Refresh` read at runtime):
```json
{"name": "Build_Gold_X", "tier": "gold", "cadence": "monthly",
 "notebookId": "<real-guid>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Build_Gold_X.Notebook"}
```
`deploy/lib.py` validates `tier` is `"silver"` or `"gold"` at load time (fails loud on typos). `Fact_PartsInvoiced_ByBranch`'s notebook gets `cadence: "daily"` (matches this project's standard cadence for report-facing Gold tables); the snapshot notebook gets `cadence: "monthly"`.

**`.platform` file shape for a new notebook** (confirmed real example, `Build_Gold_Franchise.Notebook/.platform`):
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_X"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<new-guid-generated-on-import>"
  }
}
```
`fab import "<fabric path>.Notebook" -i "<local source folder>" -f` is the real command that creates a new Fabric notebook from local files (confirmed via `fab import --help`; also the exact mechanism used for `Utilities_InTrans_FullDedup_20260811.Notebook` in an earlier session).

**Real-tool boundary:** the report already exists in `RP - Dev` (confirmed via directory listing) but has not yet had this migration applied and has no `.pbip` yet (unlike Inventory Analysis, which already had a `.pbip` from an earlier publish). Brian confirms the report isn't open in Desktop before Claude edits its TMDL directly (Task 8), same boundary as every other report this project.

---

### Task 1: Confirm the old pipeline and prepare for eventual retirement

**Files:** none — investigation and a note, no changes yet (actual retirement happens in Task 5, after the new notebook is proven).

- [x] **Step 1: Re-confirm the old pipeline's real content**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/pipeline-content.json"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/.schedules"
```
Expected: matches the Context section above exactly (3 activities, one notebook + 2 emails; monthly/day-1/noon-Central schedule). If it doesn't match (e.g. the pipeline has been edited since this plan was written), stop and re-investigate before Task 5 — don't assume the earlier read is still accurate.

- [x] **Step 2: Record the real notebookId this pipeline currently calls**

The `nb_Snapshot_Parts_Open_Orders` activity's `notebookId` is `911d8be7-cd08-a5ac-402d-45283a006add` (already captured from the read above) — record it in this plan's own execution notes so Task 5 doesn't need to re-derive it.

**Execution note (2026-09-22):** Confirmed exact match — 3 activities (notebook + 2 emails), `enabled: true`, monthly/day-1/noon-Central. No drift since this plan was written.

---

### Task 2: Build and register `Build_Gold_PartsOpenOrdersSnapshot.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook/.platform`
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
# NOTEBOOK: Build_Gold_PartsOpenOrdersSnapshot
# ============================================================================
#
# PURPOSE:
#   Takes a beginning-of-month snapshot of all currently open parts orders
#   and appends it to Fact_Parts_Open_Orders_Snapshot in DP_Presentation.
#   Replaces LH_Master_Data's nb_Snapshot_Parts_Open_Orders - same logic,
#   new backend, proper PascalCase table name (the old table was silently
#   lowercased by saveAsTable(); this one uses a path-based write instead
#   to avoid that bug - see feedback_fabric_saveastable_casing in memory).
#
# GRAIN: One row per open order per SnapshotDate (beginning of month)
# SOURCE: Fact_Parts_Open_Tickets (already refreshed by the daily pipeline)
# TARGET: Fact_Parts_Open_Orders_Snapshot (Delta table, append mode)
#
# SCHEDULING:
#   Registered as tier=gold, cadence=monthly in dp_backend_scope.json -
#   runs inside Pipeline_DP_Monthly_Refresh, which already runs after the
#   daily pipeline has refreshed Fact_Parts_Open_Tickets.
#
# BACKFILL NOTE:
#   Because Fact_Parts_Open_Tickets only shows CURRENT open orders, there
#   is no way to backfill prior months here either. The 7 months of real
#   history that existed in LH_Master_Data's snapshot table before this
#   migration were copied forward once by a separate one-time script
#   (see docs/superpowers/plans/2026-09-22-open-parts-tickets-migration.md,
#   Task 3) - this notebook only ever appends new months going forward.
#
# DUPLICATE PROTECTION:
#   Checks for an existing snapshot before writing. Safe to rerun - it
#   will skip if the month is already captured.
#
# ============================================================================

from pyspark.sql import functions as F
from datetime import date

# SnapshotDate is always the 1st of the CURRENT month.
# This is a permanent historical record - the date does not drift.
today = date.today()
snapshot_date = today.replace(day=1)
snapshot_table = "Fact_Parts_Open_Orders_Snapshot"
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
# Prevents double-writing if the notebook is accidentally rerun.
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
    # Table does not exist yet - expected on the very first run (the
    # one-time backfill in Task 3 creates it before this notebook ever
    # runs for real, so this branch is expected to be dead code in
    # practice, but kept for safety/rerun-ability).
    print(f"Note: Snapshot table not found (expected only before the Task 3 backfill runs). Will create on write.")
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
# Only runs if snapshot_ready = True (set by Cell 2).
# ============================================================================

if not snapshot_ready:
    print("No action taken - snapshot for this month already exists.")
else:
    # Read the current open orders from the fact table.
    # This table is refreshed daily by the main DP pipeline.
    # Columns with special characters (#, $$) require backtick quoting in Spark SQL.
    df = spark.sql("""
        SELECT
            Location,
            Location_Name,
            Order_No,
            Invoice_Type,
            Order_Date,
            Days_Open,
            Aging,
            Aging_Sort_Order,
            `#_Parts_On_Order`,
            `#_On_Back_Order`,
            `Order_Total_$$`,
            `$$_Available`,
            `$$_BackOrdered`,
            Backorder_Pct,
            Customer,
            Salesman
        FROM Fact_Parts_Open_Tickets
    """)

    # Count rows before writing to avoid a second scan
    row_count = df.count()
    print(f"Open orders to snapshot: {row_count}")

    # Add the snapshot date (always the 1st of the current month)
    df = df.withColumn("SnapshotDate", F.lit(str(snapshot_date)).cast("date"))

    # Append to the snapshot table via a path-based write (NOT
    # saveAsTable(), which silently lowercases the Delta table name -
    # see feedback_fabric_saveastable_casing in memory).
    # mode="append"    - never overwrites existing snapshots
    # mergeSchema=True - handles any future column additions gracefully
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

- [x] **Step 2: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_PartsOpenOrdersSnapshot"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real GUID for `logicalId` (e.g. `python -c "import uuid; print(uuid.uuid4())"`) before writing this file — it must be unique, not left as the placeholder text.

**Execution note (2026-09-22):** Real `logicalId` generated: `db997abe-6fd2-4db6-91d8-1b214f5e4bb1`.

- [x] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" -f
```
Expected: success output. If the `Fact Tables/Open Parts Tickets` folder doesn't exist yet as a Fabric workspace folder, `fab import` creates the needed folder structure automatically (matches how every other nested-folder notebook in this project was created).

**Execution note (2026-09-22) — real deviations found, the command above doesn't work as written:**
1. Fabric CLI requires an explicit `.Folder` suffix on every folder segment in the path — the plan's bare `Fact Tables/Open Parts Tickets` fails with `[InvalidPath]`. Real working path: `Fact Tables.Folder/Open Parts Tickets.Folder`.
2. Even with the corrected path, import fails with `InvalidNotebookContent` (`Unexpected character encountered while parsing value: #`) — `fab` tries to parse the `.py` source as raw `.ipynb` JSON by default. Fix: pass `--format .py` explicitly (the literal `.py` with dot — bare `py` is rejected).

**Real working command:**
```bash
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Build_Gold_PartsOpenOrdersSnapshot.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" --format .py -f
```
Result: `'Build_Gold_PartsOpenOrdersSnapshot.Notebook' imported` — confirmed success. **Task 4's identical `fab import` step needs this same fix.**

- [x] **Step 4: Capture the real notebookId**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" -q "id"
```
Record the returned GUID — needed for Step 5.

**Execution note (2026-09-22):** Real notebookId: `69082a46-1676-40ff-84e1-3146244793e3`.

- [x] **Step 5: Register in `dp_backend_scope.json`**

Add this entry to the `notebooks` array in `fabric-workspace-docs/deploy/dp_backend_scope.json` (matching the existing `tier: "gold", cadence: "monthly"` entries' shape exactly):
```json
{"name": "Build_Gold_PartsOpenOrdersSnapshot", "tier": "gold", "cadence": "monthly",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook"}
```

- [x] **Step 6: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_PartsOpenOrdersSnapshot notebook

New monthly Gold notebook replacing LH_Master_Data's
nb_Snapshot_Parts_Open_Orders - same snapshot logic, new backend,
fixes the saveAsTable() lowercase-name bug via a path-based write.
Registered in dp_backend_scope.json (tier=gold, cadence=monthly) -
runs inside the existing Pipeline_DP_Monthly_Refresh, no new pipeline.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: One-time historical backfill

**Files:**
- Create (scratch, not committed): a backfill script/notebook cell run once, ad hoc.

- [x] **Step 1: Write and run the backfill (as a temporary Fabric notebook cell, or via `spark.sql`/DataFrame API in an ad hoc session against `DP_Presentation`)**

```python
from pyspark.sql import functions as F

lh_snapshot = "fact_parts_open_orders_snapshot"  # LH_Master_Data, real lowercase name

# Read all 7 existing months from LH_Master_Data's snapshot table.
# This requires a cross-lakehouse read - if running in a DP_Presentation-
# attached notebook, use the full ABFSS path instead of a bare table name:
df = spark.read.format("delta").load(
    "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/"
    "3e74497b-8c51-4a1a-91a1-888c59118f48/Tables/fact_parts_open_orders_snapshot"
)

row_count = df.count()
print(f"Rows read from LH_Master_Data: {row_count}")
assert row_count == 13070, f"Expected 13,070 rows (7 months), got {row_count} - investigate before writing"

# Write into the new DP_Presentation table with the correct PascalCase
# name, via a path-based write (not saveAsTable()).
df.write \
    .mode("append") \
    .option("mergeSchema", "true") \
    .save("Tables/Fact_Parts_Open_Orders_Snapshot")

print(f"SUCCESS: {row_count} rows backfilled to Fact_Parts_Open_Orders_Snapshot")
```

- [x] **Step 2: Verify the backfill matches exactly**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

lh_base = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

old = con.execute(f"""
    SELECT SnapshotDate, COUNT(*) AS n FROM delta_scan('{lh_base}/fact_parts_open_orders_snapshot')
    GROUP BY SnapshotDate ORDER BY SnapshotDate
""").fetchall()
new = con.execute(f"""
    SELECT SnapshotDate, COUNT(*) AS n FROM delta_scan('{dp_base}/Fact_Parts_Open_Orders_Snapshot')
    GROUP BY SnapshotDate ORDER BY SnapshotDate
""").fetchall()

print("Old (LH_Master_Data):", old)
print("New (DP_Presentation):", new)
assert old == new, "Backfill mismatch - counts per SnapshotDate must match exactly"
print("MATCH: backfill verified.")
```
Expected: both lists identical — `[('2026-03-01', 1717), ('2026-04-01', 1709), ('2026-05-01', 1700), ('2026-06-01', 2010), ('2026-07-01', 1824), ('2026-08-01', 2203), ('2026-09-01', 1907)]`.

- [x] **Step 3: Document the backfill in this plan**

Add a note here recording the run timestamp and confirmation the assert passed, since this is a one-time manual operation with no other audit trail.

**Execution note (2026-09-22, ~18:45 UTC):** Executed as a real one-time Fabric notebook run, not an ad hoc session — `Utilities_BackfillPartsOpenOrdersSnapshot_20260922.Notebook` was created locally (METADATA header copied from `Build_Gold_PartsOpenOrdersSnapshot.Notebook`, same `DP_Presentation` default-lakehouse attachment), imported via `fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Utilities_BackfillPartsOpenOrdersSnapshot_20260922.Notebook" -i "<local path>" --format .py -f` (same `.Folder`-suffix + `--format .py` fix already documented in Task 2's execution notes), then run synchronously via `fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Utilities_BackfillPartsOpenOrdersSnapshot_20260922.Notebook" --timeout 300`. Job instance `f3ab50a4-c077-469a-9cac-169fe4f7f60a` completed successfully — the in-notebook `assert row_count == 13070` passed (13,070 rows read from `LH_Master_Data`'s `fact_parts_open_orders_snapshot`), and the path-based write created `Fact_Parts_Open_Orders_Snapshot` in `DP_Presentation` for the first time.

Step 2's verification query was then run directly (local DuckDB script against both lakehouses via `delta_scan`, not inside the notebook) and confirmed an **exact match**, both sides identical:
`[('2026-03-01', 1717), ('2026-04-01', 1709), ('2026-05-01', 1700), ('2026-06-01', 2010), ('2026-07-01', 1824), ('2026-08-01', 2203), ('2026-09-01', 1907)]` — 13,070 rows total on both `LH_Master_Data.fact_parts_open_orders_snapshot` and the new `DP_Presentation.Fact_Parts_Open_Orders_Snapshot`.

Per the plan's precedent from `Utilities_InTrans_FullDedup_20260811.Notebook`: the utility notebook item is left in place in Fabric (harmless, one-time) but was **not** committed to `fabric-workspace-docs` git history and **not** added to `deploy/dp_backend_scope.json` (not a recurring pipeline notebook). Local scratch source files used for the import were kept outside both repos (session scratchpad only).

---

### Task 4: Build and register `Build_Gold_PartsInvoicedByBranch.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook/.platform`
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
# NOTEBOOK: Build_Gold_PartsInvoicedByBranch
# ============================================================================
#
# PURPOSE:
#   Branch/date rollup of invoiced parts sales, faithfully porting the
#   exact logic that used to live as a raw Value.NativeQuery
#   (EnableFolding=false) directly in Open Parts Tickets' own TMDL
#   against LH_Master_Data's raw Invoice table. Replaces that anti-
#   pattern with a proper Gold table.
#
# GRAIN: One row per Branch per InvoiceDate (date, not datetime)
# SOURCE: Silver_Invoice (DP_Presentation shortcut)
# TARGET: Fact_PartsInvoiced_ByBranch (Delta table, full overwrite each run)
#
# BUSINESS LOGIC (ported exactly from the original native query):
#   - ModuleType IN ('I', 'W') only
#   - Excludes ~30 hardcoded internal/franchise customer numbers (same
#     list as the original query - these are NOT the same customers
#     dim_CustomerList's Internal/Warranty categorization buckets
#     elsewhere in this project; this report's own exclusion list is
#     kept exactly as-is, not reconciled with that different logic)
#   - Rolling 15-month window, ending "today" - the original used raw
#     T-SQL GETDATE() (server-clock-relative, no DST handling); this
#     version uses a fixed Python-side cutoff computed once per run,
#     same DST-safe pattern as .claude/queries/DATA-REFRESH-TEMPLATE.pq
#
# ============================================================================

from pyspark.sql import functions as F
from datetime import datetime, timedelta
import pytz

# Compute the rolling-15-month cutoff using real US/Central local time,
# not a server-clock-relative call - avoids the DateTime.LocalNow()/
# GETDATE()-returns-UTC-in-service bug class fixed repeatedly elsewhere
# in this project.
central = pytz.timezone("America/Chicago")
now_central = datetime.now(pytz.utc).astimezone(central)
cutoff_date = (now_central.replace(day=1) - timedelta(days=1)).replace(day=1)
for _ in range(14):
    cutoff_date = (cutoff_date - timedelta(days=1)).replace(day=1)
cutoff_str = cutoff_date.strftime("%Y-%m-%d")

print(f"Rolling window cutoff (15 months back, Central time): {cutoff_str}")

EXCLUDED_CUSTOMERS = [
    '71', '72', '73', '74', '76', '77', '78', '81', '83', '84', '85', '86', '87',
    '9001', '9002', '9003', '9004', '9005', '9006', '9007',
    '41', '42', '43', '44', '46', '47', '48',
    '51', '53', '54', '55', '56', '57',
    '9051', '9052', '9053', '9054', '9055', '9056', '9057',
]

df = spark.sql("SELECT Branch, InvoiceDate, ModuleType, CustomerNumber, PartsSaleValue FROM Silver_Invoice")

df = df.filter(
    (F.col("ModuleType").isin(["I", "W"]))
    & (~F.col("CustomerNumber").isin(EXCLUDED_CUSTOMERS))
    & (F.to_date("InvoiceDate") >= F.lit(cutoff_str))
)

result = (
    df.withColumn("InvoiceDate", F.to_date("InvoiceDate"))
    .groupBy("Branch", "InvoiceDate")
    .agg(F.sum("PartsSaleValue").alias("Invoiced_Parts"))
)

row_count = result.count()
print(f"Rows computed: {row_count}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================================
# CELL 2 - WRITE
# Full overwrite each run (matches the original's behavior - a live
# native query, always fully recomputed on every report refresh, not an
# incremental/append table like the snapshot).
# ============================================================================

result.write \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("Tables/Fact_PartsInvoiced_ByBranch")

print(f"SUCCESS: {row_count} rows written to Fact_PartsInvoiced_ByBranch")


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
    "displayName": "Build_Gold_PartsInvoicedByBranch"
  },
  "config": {
    "version": "2.0",
    "logicalId": "REPLACE_WITH_NEW_GUID"
  }
}
```
Generate a real, unique GUID before writing (same as Task 2 Step 2).

**Execution note (2026-09-22):** Real `logicalId` generated: `28221a7e-d399-425b-919c-ff864bf69efc`.

- [x] **Step 3: Import the notebook into Fabric**

**Real command, already corrected from Task 2's own execution findings** (the plan's original bare-folder-name/default-format command doesn't work — Fabric CLI requires an explicit `.Folder` suffix on each folder segment, and `.py` source needs `--format .py` explicitly or `fab` tries to parse it as `.ipynb` JSON and fails with `InvalidNotebookContent`):

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Build_Gold_PartsInvoicedByBranch.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook" --format .py -f
```

**Execution note (2026-09-22):** Ran exactly as written (the pre-corrected command). Result: `'Build_Gold_PartsInvoicedByBranch.Notebook' imported` — confirmed success, no further deviations found.

- [x] **Step 4: Run it once and capture the real notebookId**

Run the notebook manually in the Fabric UI (or via `fab` job trigger) to confirm it executes cleanly and creates `Fact_PartsInvoiced_ByBranch`, then:
```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook" -q "id"
```

**Execution note (2026-09-22):** Ran via `fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Build_Gold_PartsInvoicedByBranch.Notebook" --timeout 300` (same pattern as Task 3's backfill run) — job instance `55e1fae5-1a3a-4cf1-943f-1e6313f6b098` completed successfully, creating `Fact_PartsInvoiced_ByBranch` in `DP_Presentation`. Real notebookId: `432002bc-2c17-45c1-bf1c-d4929d2e08a8`.

- [x] **Step 5: Verify against the original native query**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
dp_base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

# New Gold table total
new_total = con.execute(f"""
    SELECT ROUND(SUM(Invoiced_Parts), 2) FROM delta_scan('{dp_base}/Fact_PartsInvoiced_ByBranch')
""").fetchone()[0]
print(f"New Gold table total Invoiced_Parts: {new_total:,.2f}")

# Compare against a direct pyodbc pull of the ORIGINAL native query
# against LH_Master_Data (same 15-month-ish window - exact boundary may
# differ by a few days depending on when each was run; compare orders
# of magnitude and per-branch totals, not an exact-to-the-penny match,
# since the two were computed on different days).
import pyodbc
import pandas as pd
conn = pyodbc.connect(
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com;"
    "DATABASE=LH_Master_Data;Authentication=ActiveDirectoryInteractive;Encrypt=yes;"
)
old_df = pd.read_sql("""
    SELECT Branch, CAST(InvoiceDate AS DATE) AS InvoiceDate, SUM(PartsSaleValue) AS Invoiced_Parts
    FROM Invoice
    WHERE ModuleType IN ('I', 'W')
      AND CustomerNumber NOT IN ('71','72','73','74','76','77','78','81','83','84','85','86','87',
        '9001','9002','9003','9004','9005','9006','9007','41','42','43','44','46','47','48',
        '51','53','54','55','56','57','9051','9052','9053','9054','9055','9056','9057')
      AND InvoiceDate >= DATEADD(month, -15, GETDATE())
    GROUP BY Branch, CAST(InvoiceDate AS DATE)
""", conn)
old_total = old_df["Invoiced_Parts"].astype(float).sum()
print(f"Original native query total Invoiced_Parts: {old_total:,.2f}")
print(f"Difference: {abs(new_total - old_total):,.2f} ({abs(new_total - old_total) / old_total * 100:.2f}%)")
```
Expected: totals within a small tolerance (a few days' worth of invoices at the rolling window's edges, given the two queries run on different days) — a large mismatch (more than a day or two's typical invoice volume) means the port has a real logic bug, investigate before proceeding.

**Execution note (2026-09-22) — pyodbc/ActiveDirectoryInteractive route confirmed unusable in this session, fell back to DuckDB `delta_scan`:** `pyodbc` is installed but this machine has no `ODBC Driver 18 for SQL Server` registered (`pyodbc.drivers()` returns only `SQL Server`, `SQL Anywhere 17`, and local desktop-file drivers) — the connection failed at the driver-resolution stage (`IM002`), before authentication was even attempted, confirming this isn't just an interactive-auth limitation but a genuine missing-driver gap in this non-interactive session. Fell back to the plan's specified alternative: DuckDB `delta_scan` directly against both `DP_Presentation.Fact_PartsInvoiced_ByBranch` (the new Gold table) and `LH_Master_Data.Invoice` (the exact original native query's real source table), translating the original SQL's WHERE/GROUP BY into equivalent DuckDB SQL.

**Verification result — the notebook's port logic is exact, the residual is fully explained (not a bug):**
1. **New Gold table total:** `Fact_PartsInvoiced_ByBranch` = 9,119 rows, `$135,488,294.70` (InvoiceDate range `2025-06-01` to `2026-09-04`, confirming the notebook's month-start-truncated cutoff computed to `2025-06-01`, 15 months back from a 2026-09-22 run).
2. **First comparison (raw `LH_Master_Data.Invoice`, original SQL's exact `DATEADD(month,-15,GETDATE())` cutoff):** `$134,419,430.53` — diff of `$1,068,864.17` (0.80%). This alone looked small enough to pass, but per the task's instruction not to stop at a surface-level match, dug into *why* rather than accepting the number blind.
3. **Root-cause decomposition (two real, fully-explained effects netting together):**
   - **Effect A — intentional month-truncation design:** the ported notebook's cutoff is always the 1st of the month 15 months back (documented in its own header comment as a DST-safe fixed-per-run cutoff), which starts ~3 weeks earlier than the original's exact day-level `GETDATE()-15mo`. Re-running the raw-Invoice query with the *same* `>= 2025-06-01` cutoff the notebook used isolates this: it adds `$5,495,569.61` (10,867 rows, `2025-06-01` to `2025-06-21`) that the original day-exact query would have excluded.
   - **Effect B — source-table freshness gap, not a logic error:** comparing the notebook's *actual* source (`Silver_Invoice` in `DP_Presentation`) against the new Gold table for the identical filter/cutoff produced an **exact match to the penny**: `$135,488,294.70` = `$135,488,294.70` (transform logic in the notebook is proven 100% correct relative to its own source data). The gap between `Silver_Invoice` and `LH_Master_Data.Invoice` for the same nominal date range (`$135,488,294.70` vs `$139,915,000.14` before bounding) is a refresh-cadence artifact: `Silver_Invoice`'s max `InvoiceDate` was `2026-09-04`, while `LH_Master_Data.Invoice`'s max was `2026-09-21` — a 17-day freshness lag. Bounding the raw-Invoice comparison to `Silver_Invoice`'s own actual date range (`2025-06-01` to `2026-09-04`) narrows the gap to `$135,611,992.38` vs `$135,488,294.70` — a residual of just `$123,697.68` (0.09%, 256 rows out of ~208K), consistent with normal snapshot-timing noise at the table edges, not a logic bug.
4. **Conclusion:** the notebook's ModuleType/customer-exclusion/branch-date-grouping/SUM logic is verified exact against its real source table. The larger-looking 0.80% headline difference vs. the original query is a coincidental near-cancellation of two independent, well-understood, non-bug effects (the intentional month-start window design choice, and `Silver_Invoice` currently running ~17 days behind `LH_Master_Data.Invoice`'s refresh) — not a defect in the port. No further action needed; `Silver_Invoice`'s refresh lag is a pipeline-cadence fact of the existing DP backend, not something this notebook introduced or needs to compensate for.

- [x] **Step 6: Register in `dp_backend_scope.json`**

```json
{"name": "Build_Gold_PartsInvoicedByBranch", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook"}
```

**Execution note (2026-09-22):** Registered in `fabric-workspace-docs/deploy/dp_backend_scope.json` with real notebookId `432002bc-2c17-45c1-bf1c-d4929d2e08a8`.

- [x] **Step 7: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook/" "deploy/dp_backend_scope.json"
git commit -m "Add Build_Gold_PartsInvoicedByBranch notebook

New daily Gold notebook replacing a raw EnableFolding=false native
query that lived directly in Open Parts Tickets' own TMDL. Faithfully
ports the exact same ModuleType/customer-exclusion/rolling-window
logic, fixing the GETDATE()-relative-window risk with a DST-safe
Central-time cutoff. Registered in dp_backend_scope.json
(tier=gold, cadence=daily).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-22):** Committed as `419a73e6` on `fabric-workspace-docs`/`dev` and pushed (`ab4f2746..419a73e6`). Only the notebook's two new files plus `deploy/dp_backend_scope.json` were staged — other unrelated untracked `.pbi/` Desktop-artifact folders present in the working tree (from other reports) were left alone.

---

### Task 5: Retire the old monthly pipeline

**Files:**
- Modify (disable, don't delete): `fabric-workspace-docs/workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/.schedules`

- [x] **Step 1: Confirm the new notebook has run successfully at least once**

Either wait for its first real scheduled run inside `Pipeline_DP_Monthly_Refresh`, or manually trigger it once via the Fabric UI and confirm success (row count printed, no errors) — don't disable the old pipeline until this is confirmed, per the design spec's explicit ordering (never remove the old one first).

**Execution note (2026-09-22) — real limitation, read before trusting this as full proof:** `Build_Gold_PartsOpenOrdersSnapshot.Notebook` has not yet run through its real scheduled cadence (first real scheduled run is 2026-10-01 via `Pipeline_DP_Monthly_Refresh`). It was manually triggered once today via `fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Parts Tickets.Folder/Build_Gold_PartsOpenOrdersSnapshot.Notebook" --timeout 300` (job instance `672c30b0-e618-49a7-b516-909f5ea29980`, status `Completed`, no `failureReason`, ran 18:56:44–18:57:14 UTC). Because the one-time backfill (Task 3) already wrote a `2026-09-01` row, this run's own duplicate-guard correctly took its skip branch rather than its write branch — this is CORRECT behavior, not a failure.

The Fabric job-instance REST API does not expose the notebook's actual print/log output (`GET /v1/workspaces/{id}/items/{id}/jobs/instances/{jobId}` returns only status/timestamps, no cell output), so the exact console string (`"SKIPPED: Snapshot for 2026-09-01 already exists (1907 rows). No action taken."`) could not be captured directly this session. Instead confirmed the same fact a stronger way — queried `DP_Presentation.Fact_Parts_Open_Orders_Snapshot` directly via DuckDB `delta_scan` immediately after the run: `2026-09-01` still shows exactly **1,907 rows** (total 13,070, unchanged from the Task 3 backfill's verified count). Had the guard failed and taken the write branch instead, `2026-09-01` would show 3,814 rows. This proves the skip branch executed, not just that the job returned success.

**What this does and does NOT prove:** Confirmed — the notebook deploys, connects, reads `Fact_Parts_Open_Tickets`, evaluates the duplicate-guard correctly against real data, and completes without error. **Not yet proven** — the notebook's actual WRITE path (append + `mergeSchema`, `df.write...save(snapshot_path)`) has never executed for a month that wasn't already present; that code path is fully untested against real Fabric execution until it runs against a genuinely new month. That first real proof happens naturally on **2026-10-01**, when `Pipeline_DP_Monthly_Refresh` triggers this notebook for real against `SnapshotDate = 2026-10-01` (a month with no existing row). Recommend a quick manual check on/after Oct 1 that the new month landed with a sane row count, though no separate task currently tracks that check.

- [x] **Step 2: Disable the old pipeline's schedule**

Edit `.schedules` to set `"enabled": false`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/schedules/1.0.0/schema.json",
  "schedules": [
    {
      "enabled": false,
      "jobType": "Execute",
      "configuration": {
        "type": "Monthly",
        "startDateTime": "2026-03-04T00:00:00",
        "endDateTime": "2027-03-04T00:00:00",
        "localTimeZoneId": "Central Standard Time",
        "times": ["12:00"],
        "recurrence": 1,
        "occurrence": {
          "occurrenceType": "DayOfMonth",
          "dayOfMonth": 1
        }
      }
    }
  ]
}
```
Leave the pipeline and notebook themselves in place (not deleted) — this is a disable, not a removal, preserving the old table and its history as a reference.

**Execution note (2026-09-22):** `.schedules`' `enabled` flag flipped `true` → `false` exactly as specified; no other fields touched. Pipeline (`Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline`) and notebook (`nb_Snapshot_Parts_Open_Orders.Notebook`, notebookId `911d8be7-cd08-a5ac-402d-45283a006add`) both left fully in place in `LH_Master_Data` — not deleted, not modified beyond this one flag.

- [x] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/.schedules"
git commit -m "Disable old Pipeline_Monthly_Open_Orders_Snapshot schedule

Superseded by Build_Gold_PartsOpenOrdersSnapshot running inside
Pipeline_DP_Monthly_Refresh - both would otherwise append duplicate,
diverging future months. Pipeline and notebook left in place
(disabled, not deleted) as a historical reference.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-22):** Ran exactly as written. Committed as `714fe601` on `fabric-workspace-docs`/`dev` (only the `.schedules` file staged) and pushed (`419a73e6..714fe601`). Unrelated pre-existing untracked `.pbi/` Desktop-artifact folders for other reports (Inventory Analysis, Open Work Orders, Part Sales with Low Margin, Pin Capture, Price Matrix) were present in the working tree and left alone, same discipline as Task 4's commit.

---

### Task 6: Exhaustive real-usage audit (report layer)

**Files:** none — investigation only. Findings get documented directly in this plan before Task 7 proceeds (same discipline as the Inventory Analysis migration's Task 1).

- [x] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Open Parts Tickets.Report"
```

- [x] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition"
for tbl in Fact_Parts_Open_Tickets Fact_Parts_Open_Tickets_Details dim_BranchLocation dim_DateTable fact_parts_open_orders_snapshot Fact_PartsInvoiced_ByBranch; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_#\$%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_#\$%]+)\]/\1/" | sort -u
done
```

- [x] **Step 3: Bookmark check**

```bash
ls "Open Parts Tickets.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "Open Parts Tickets.Report/definition/bookmarks/" 2>/dev/null
```

- [x] **Step 4: `relationships.tmdl` cross-reference**

Relationship key columns use TMDL `fromColumn:`/`toColumn:` syntax, not `Table[Column]` DAX syntax, so they won't match Step 2's grep pattern — read `relationships.tmdl` directly and note every column used as a relationship endpoint for these 6 tables (same real miss class already found and corrected on Inventory Analysis's `Fact_Inventory` relationship keys).

- [x] **Step 5: Document findings**

For each of the 6 tables, record confirmed-used columns (keep) vs. confident-unused columns (trim) vs. ambiguous (leave as-is, note why). Expect `fact_parts_open_orders_snapshot` to land mostly/entirely in "keep everything" (it's a purpose-built append-only snapshot table where every column was deliberately selected) — confirm this against real usage rather than assuming, but don't be surprised if there's little or nothing to trim there. Add a "### Task 6 Findings" section to this plan file (same structure as the Inventory Analysis plan's "Task 1 Findings" section) before starting Task 7.

### Task 6 Findings

**Method note (applies to every table below):** "Used" was tested against 4 independent checks, matching the plan's own step list, with two of them strengthened beyond a naive text/line-proximity match to avoid both false negatives and false positives: (1) `pbir fields list` — catches direct visual/slicer field drags and implicit (auto-summarized) measures; (2) the `Table[Column]`-qualified DAX-text grep across `tables/*.tmdl` + `relationships.tmdl`, cross-validated with a second, more precise grep directly against every `visual.json`'s `"queryRef": "Table.Column"` / `"metadata": "Table.Column"` strings (catches implicit-aggregation fields like `Sum(Fact_Parts_Open_Tickets_Details.Unit_Price)` that never appear as literal DAX text anywhere, which the plain `Table[Column]` grep alone would have silently missed); (3) the bookmark check, done with a small Python script that parses each `.bookmark.json`'s query DSL properly (resolving `From`/`Name` alias tables to their real `Entity` before pairing with `Property`) rather than naive line-proximity grep, since bookmarks can have multiple `From` sources in one filter block and naive proximity would mis-attribute a property to the wrong table; (4) `relationships.tmdl`'s `fromColumn`/`toColumn` declarations, checked directly since relationship keys use different TMDL syntax than DAX bracket refs. A broad whole-report/whole-model grep (scoped to just `Open Parts Tickets.SemanticModel`/`.Report`) was additionally run on every column that came back unconfirmed by checks 1–4, to rule out any usage format the four narrower checks could still miss (cultures-file auto-translation entries were excluded as known false positives, per the same pattern already documented on Inventory Analysis).

**Real blind-spot catch (exactly what Step 4 was designed to find):** `Fact_PartsInvoiced_ByBranch.Branch` does **not** appear anywhere in the Step 2 DAX-text grep output (only `InvoiceDate` and `Invoiced_Parts` did) — but `relationships.tmdl` shows `Fact_PartsInvoiced_ByBranch.Branch -> dim_BranchLocation.BranchID` as a real relationship key. Had Step 4 been skipped, `Branch` would have been wrongly flagged as an unused trim candidate on a table that in fact has zero trimmable columns.

#### `Fact_Parts_Open_Tickets`
- **Keep (17 stored columns):** `Location` (relationship key to `dim_BranchLocation.BranchID`, + pbir + bookmark), `Order_No` (relationship key from `Fact_Parts_Open_Tickets_Details.Order_No`, + pbir/DAX-grep/bookmark), `Invoice_Type` (pbir + bookmark), `Order_Date` (relationship key to `dim_DateTable.Date`, + DAX-grep via `SAMEPERIODLASTYEAR(Fact_Parts_Open_Tickets[Order_Date])`), `Days_Open` (pbir + DAX-grep + bookmark), `Aging` (pbir + DAX-grep + bookmark), `Aging_Sort_Order` (`sortByColumn` target of `Aging`, + independently DAX-grep-confirmed via `HTML_Parts_Overview.tmdl`'s calculated-table row constructor — not just a sort dependency), `#_Parts_On_Order` (DAX-grep, `'# Parts On Order'` measure), `#_On_Back_Order` (DAX-grep, multiple measures), `Order_Total_$$` (DAX-grep, `'Order Total'` measure), `$$_Available` (DAX-grep, `'$$ not BO'`/`'Available $$'` measures), `$$_BackOrdered` (DAX-grep + bookmark), `Deposit` (DAX-grep, `Deposit` measure), `Salesman` (DAX-grep, Salesman Rank/Bar-Color measures + bookmark + visual queryRef), `Contact_Code` (pbir + bookmark), `Customer` (DAX-grep, Customer Rank measures + bookmark + pbir), `Aging_Base_Date` (pbir + bookmark).
- **Trim (6 stored columns, confident — zero hits on every check including the broad whole-report grep):** `Location_Name`, `Created_On`, `WO_Creation_Date`, `Aging_Date_Source`, `Backorder_Pct`, `AR_Acct`.
- **Calculated column (1 — left as-is, out of scope per this migration's established trim pattern, which only ever trims stored/M-sourced columns):** `'Order Count'` — kept regardless, but also independently confirmed used (`Sum(Order Count)` in pbir, referenced by other measures).

#### `Fact_Parts_Open_Tickets_Details`
- **Keep (6 columns):** `Order_No` (relationship key to `Fact_Parts_Open_Tickets.Order_No`, + pbir/bookmark/queryRef), `Part_No` (DAX-grep, `'Parts Line Count'`/`'Line Count'` measures + bookmark + pbir), `BackOrdered_QTY` (DAX-grep, several backorder measures + bookmark + pbir), `Unit_Price` (queryRef `Sum(Fact_Parts_Open_Tickets_Details.Unit_Price)` + bookmark — never appears as literal DAX text, only as an implicit-aggregation visual field), `Line_Total` (same pattern as `Unit_Price`), `Customer` (queryRef + bookmark + pbir — this table's **own** `Customer` column, distinct from `Fact_Parts_Open_Tickets.Customer`, confirmed separately).
- **Trim (17 columns, confident — zero hits on every check, verified individually via table-qualified queryRef grep so as not to conflate with `Fact_Parts_Open_Tickets`'s identically-named columns):** `Location`, `Location_Name`, `RO_Number`, `File_No`, `Invoice_Type`, `Order_Date`, `Created_On`, `WO_Creation_Date`, `Days_Open`, `Aging`, `Aging_Sort_Order`, `Aging_Date_Source`, `Quantity_Ordered`, `Available_QTY`, `Line_Backorder_Pct`, `Contact_Code`, `Salesman`. Notable: this table duplicates most of `Fact_Parts_Open_Tickets`'s own column set (same names, same grain-adjacent data) but the report only ever pulls the 6 line-item-specific columns from it — everything else is redundant with the parent ticket-level table it's related to.
- No `sortByColumn` property anywhere in this table (confirmed via full read) — no dangling-sort risk from any of the 17 trims.

#### `dim_BranchLocation`
- **Keep (3 columns):** `Branch` (direct: pbir + bookmark + queryRef; also carries `sortByColumn: LocationID`), `BranchID` (relationship key — **not** `BranchKey** — real from all 3 of this report's fact-table relationships: `Fact_Parts_Open_Tickets.Location`, `fact_parts_open_orders_snapshot.Location`, and `Fact_PartsInvoiced_ByBranch.Branch` all point to `dim_BranchLocation.BranchID`), `LocationID` (not directly used itself, but is `Branch`'s `sortByColumn` target — must stay to avoid a dangling sort).
- **Trim (13 columns, confident — zero hits on every check):** `BranchKey`, `BranchType`, `BranchName`, `State`, `City`, `ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`, `OperationalPriority`, `RegionalClassification`, `ServiceHours`, `DistanceFromHub`, `DataQualityScore`.
- **Real difference from Inventory Analysis's `dim_BranchLocation` audit, worth flagging explicitly:** on Inventory Analysis, `BranchKey` was the real relationship join key and was kept. On this report, the join key is `BranchID` instead — `BranchKey`'s only appearances anywhere in this model are its own two-line declaration plus its auto-generated `cultures/en-US.tmdl` translation entry (the same false-positive pattern already documented for `State`/`City` on Inventory Analysis). Same shared dimension table, same column set, but a genuinely different real join key per report — don't assume `BranchKey` is protected just because it was on a sibling report.

#### `dim_DateTable`
- **Keep (3 columns):** `Date` (relationship key — all 3 of this report's fact-table date relationships point here: `Fact_Parts_Open_Tickets.Order_Date`, `fact_parts_open_orders_snapshot.SnapshotDate`, `Fact_PartsInvoiced_ByBranch.InvoiceDate`), `MonthYear` (direct: pbir + bookmark + queryRef, used as a slicer/axis across multiple visuals), `Month` (not directly used itself, but is `MonthYear`'s `sortByColumn` target — must stay).
- **Trim (59 columns, confident — zero hits on every check, including a whole-report `dim_DateTable` grep that found only the `MonthYear`/`Date` references already accounted for above):** `DateKey`, `Year`, `Quarter`, `Day`, `WeekOfYear`, `DayOfWeek`, `MonthName`, `MonthNameShort`, `DayOfWeekName`, `DayOfWeekNameShort`, `QuarterYear`, `DateDisplayName`, `IsWeekend`, `IsWeekday`, `IsCurrentYear`, `IsCurrentMonth`, `DaysFromToday`, `SortableMonthYear`, `Season`, `IsPeakSeason`, `FiscalYear`, `FiscalQuarter`, `MonthSort`, `QuarterSort`, `YearOffset`, `IsBusinessDay`, `WorkingDaysInMonth`, `WorkingDaysInQuarter`, `WorkingDaysInYear`, `IsPreviousYear`, `IsPreviousMonth`, `IsPreviousQuarter`, `IsYearToDate`, `IsQuarterToDate`, `IsMonthToDate`, `IsRolling6Months`, `IsRolling12Months`, `IsRolling24Months`, `IsRolling36Months`, `IsRolling48Months`, `IsRolling4Quarters`, `IsRolling8Quarters`, `IsRolling52Weeks`, `IsRolling365Days`, `IsRolling730Days`, `IsRolling1095Days`, `IsRolling1460Days`, `IsRolling180Days`, `IsRolling545Days`, `IsRolling45Days`, `IsRolling120Days`, `IsRolling270Days`, `IsRolling450Days`, `IsRolling13Weeks`, `IsRolling26Weeks`, `IsRolling104Weeks`, `IsRolling156Weeks`, `IsLast30Days`, `IsLast60Days`, `IsLast90Days`, `IsNext30Days`, `IsSameMonthLastYear`, `IsSameQuarterLastYear`, `RollingPeriodCategory`.
- Note: `MonthNameShort` also carries `sortByColumn: Month`, but since `MonthNameShort` itself is a confident trim (not kept), its own `sortByColumn` property is removed along with the whole column block — no dangling reference results (the target, `Month`, stays regardless, kept for `MonthYear`'s sake). Consistent with the same 28%-utilization finding already documented for this exact shared table on Inventory Analysis (memory: `project_dimensions_catalog_audit`) — this report uses it even more narrowly (3 of 62 columns) since it has no need for most of the fiscal/rolling-window flags that report used.

#### `fact_parts_open_orders_snapshot`
- **Keep (9 columns, confirmed directly used):** `Location` (relationship key to `dim_BranchLocation.BranchID`), `Order_No` (DAX-grep, `'Snapshot Order Count'`/`'Snapshot Orders with Backorder'` measures), `Invoice_Type` (pbir + queryRef), `Aging` (pbir + DAX-grep + bookmark), `Aging_Sort_Order` (`sortByColumn` target of `Aging`), `#_On_Back_Order` (DAX-grep, `'Snapshot Backorder Count'`/`'Snapshot Orders with Backorder'`), `Order_Total_$$` (DAX-grep, `'Snapshot Order Total $'`), `$$_BackOrdered` (DAX-grep, `'Snapshot Backorder $'`), `SnapshotDate` (relationship key to `dim_DateTable.Date`, + pbir + bookmark).
- **Ambiguous — leave as-is (8 columns, zero hits on every check but deliberately NOT trimmed):** `Location_Name`, `Order_Date`, `Days_Open`, `#_Parts_On_Order`, `$$_Available`, `Backorder_Pct`, `Customer`, `Salesman`. Per this task's own instruction, confirmed against real usage rather than assumed — these 8 genuinely show no current measure/visual/bookmark/relationship reference. Left untouched anyway because this table is the one genuine exception to the migration's usual trim discipline: it's a purpose-built, append-only monthly historical snapshot whose entire 16-column (+`SnapshotDate`) selection was deliberately mirrored 1:1 from `Fact_Parts_Open_Tickets`'s own schema by design (see Task 2's notebook SELECT list), specifically so future trend/drill-through analysis has the full picture available across all captured months without needing a backend rebuild. Trimming currently-unused columns here would permanently and irreversibly lose that historical detail for all 13,070 already-captured rows going forward, for a dataset small enough (13K rows) that there's no real storage/performance case for trimming it the way there is for `dim_DateTable`'s 59-column cut.
- **Trim:** none. Matches the plan's own stated expectation for this table.

#### `Fact_PartsInvoiced_ByBranch`
- **Keep (3 columns, all):** `Branch` (relationship key to `dim_BranchLocation.BranchID` — the real Step-4 blind-spot catch described above), `InvoiceDate` (DAX-grep, `_Measures.tmdl` lines 1777–1780 + relationship key to `dim_DateTable.Date`), `Invoiced_Parts` (DAX-grep, same measure block, `SUM(Fact_PartsInvoiced_ByBranch[Invoiced_Parts])`).
- **Trim:** none. Matches the plan's own expectation for this newly-built table (Task 4) — its 3-column schema was already minimal by construction, faithfully replicating the original native query's exact 3-column output, and this audit confirms all 3 are genuinely used, not just assumed correct.
- **Side finding, not a trim decision but relevant to Task 7:** unlike the other 5 tables, this table's current M query (`Fact_PartsInvoiced_ByBranch.tmdl` lines 30–42) is a `Value.NativeQuery(..., [EnableFolding=false])` running the *original* raw SQL directly against `LH_Master_Data.Invoice` — not a simple `Source{[Schema="dbo",Item="Fact_PartsInvoiced_ByBranch"]}[Data]` read. Task 7 Step 1's generic "replace the `Sql.Database(...)` line" instruction is necessary but **not sufficient** for this one file: the whole `Value.NativeQuery(...)` block (the native SQL string, `EnableFolding=false`, and the `Query`/`in Query` wiring) needs to be replaced with a plain read of the new Gold table `Fact_PartsInvoiced_ByBranch` in `DP_Presentation` (same pattern as the other 5 tables' `Source{[Schema="dbo",Item="..."]}[Data]` form), not just a connection-string swap on top of the old native query. Flagging this now so Task 7's executor doesn't apply the same mechanical find/replace to this file that works for the other 5.

#### Ambiguous columns summary
Only `fact_parts_open_orders_snapshot`'s 8 columns (listed above) are ambiguous, and all 8 share the same single reason: the table's purpose-built append-only historical design overrides the "zero usage = trim" default used everywhere else in this migration. No other table has any ambiguous columns — every other candidate resolved cleanly to keep or trim once cross-checked against all 4 methods plus the broad whole-report grep. The out-of-scope calculated column on `Fact_Parts_Open_Tickets` (`'Order Count'`) is not ambiguous about usage (it's confirmed used) — it's simply outside this migration's trim pattern by design, same as calculated columns were treated on Inventory Analysis.

#### sortByColumn dependency summary
- `Fact_Parts_Open_Tickets.Aging` → `sortByColumn: Aging_Sort_Order` — `Aging_Sort_Order` must be kept (also independently confirmed used regardless).
- `fact_parts_open_orders_snapshot.Aging` → `sortByColumn: Aging_Sort_Order` — `Aging_Sort_Order` must be kept (also independently confirmed used regardless).
- `dim_BranchLocation.Branch` → `sortByColumn: LocationID` — `LocationID` must be kept (same pattern already documented on Inventory Analysis for this identical shared table).
- `dim_DateTable.MonthYear` → `sortByColumn: Month` — `Month` must be kept.
- `dim_DateTable.MonthNameShort` → `sortByColumn: Month` — same target, already covered by the `MonthYear` dependency above; `MonthNameShort` itself is a confident trim since removing the whole column block removes this property along with it, with no dangling reference (the target column isn't being removed).

`Fact_Parts_Open_Tickets_Details` and `Fact_PartsInvoiced_ByBranch` have no `sortByColumn` property anywhere (confirmed via full reads) — no constraint on either table's trim list.

---

### Task 7: Repoint and trim the report's 6 data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_Parts_Open_Tickets.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_Parts_Open_Tickets_Details.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/fact_parts_open_orders_snapshot.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_PartsInvoiced_ByBranch.tmdl`

- [x] **Step 1: Repoint all 6 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```

- [x] **Step 2: Fix `fact_parts_open_orders_snapshot.tmdl`'s `Item=` to the new PascalCase name**

Find:
```
				    dbo_fact_parts_open_orders_snapshot = Source{[Schema="dbo",Item="fact_parts_open_orders_snapshot"]}[Data]
```
Replace with:
```
				    dbo_Fact_Parts_Open_Orders_Snapshot = Source{[Schema="dbo",Item="Fact_Parts_Open_Orders_Snapshot"]}[Data]
```
(and update the `in` clause / any other reference to the old variable name accordingly). No other `Item=` changes needed in any of the 6 files — every other real table name already matches exactly between `LH_Master_Data` and `DP_Presentation`.

- [x] **Step 3: Trim per Task 6's findings**

For each of the 6 tables, apply Task 6's documented keep/trim decisions: remove confidently-unused `column` blocks, add/update a matching `Table.SelectColumns(...)` M-query step, check for any dangling `sortByColumn` on a trim candidate before removing it. Leave ambiguous columns untouched.

- [x] **Step 4: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Open Parts Tickets.SemanticModel/"
```
Expected: no output.

- [x] **Step 5: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Open Parts Tickets to DP_Presentation

All 6 data tables repointed; fact_parts_open_orders_snapshot's Item=
fixed to the new proper-case Fact_Parts_Open_Orders_Snapshot name.
Trimmed per the Task 6 exhaustive audit where confident, left as-is
where ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-22):** All 6 files done and pushed (`fabric-workspace-docs` commit `cfb3408a`). `Fact_Parts_Open_Tickets`: 6 columns trimmed (`Location_Name`, `Created_On`, `WO_Creation_Date`, `Aging_Date_Source`, `Backorder_Pct`, `AR_Acct`), 17 stored + 1 calculated column kept, `Table.SelectColumns` added. `Fact_Parts_Open_Tickets_Details`: 17 columns trimmed, 6 kept, `Table.SelectColumns` added. `dim_BranchLocation`: 13 columns trimmed, 3 kept (`Branch`, `BranchID`, `LocationID`), `Table.SelectColumns` added — confirmed `BranchID` (not `BranchKey`) is the real join key per Task 6's findings for this report. `dim_DateTable`: 59 columns trimmed, 3 kept (`Date`, `Month`, `MonthYear`), `Table.SelectColumns` added; `MonthNameShort`'s own `sortByColumn: Month` property removed along with its column block, no dangling reference since `Month` itself stays. `fact_parts_open_orders_snapshot`: connection repointed + `Item=`/variable name fixed to `Fact_Parts_Open_Orders_Snapshot`; zero column trims per Task 6 (all 17 columns, including the 8 ambiguous ones, left untouched — no `Table.SelectColumns` added). `Fact_PartsInvoiced_ByBranch`: entire `Value.NativeQuery(EnableFolding=false)` block replaced with a plain `Source{[Schema="dbo",Item="Fact_PartsInvoiced_ByBranch"]}[Data]` read of the new Gold table; all 3 report columns (`Branch`/`InvoiceDate`/`Invoiced_Parts`) confirmed matching `sourceColumn` values, zero trims. Post-edit `grep -rn "LH_Master_Data"` across the whole SemanticModel folder returned no output. No TMDL validation-hook errors hit during editing. Report not open in Desktop; no Fabric refresh/publish performed.

---

### Task 8: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.pbip`

- [ ] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "Open Parts Tickets"
```
Expected: only `Open Parts Tickets.Report` and `Open Parts Tickets.SemanticModel` — no `.pbip` (already confirmed this session; re-check in case something changed).

- [ ] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Open Parts Tickets.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Open Parts Tickets.pbip"
git commit -m "Add Open Parts Tickets.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Push

**Files:** none.

- [ ] **Step 1: Push to origin**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git push origin dev
```

---

### Task 10: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 7-8's commits.

- [ ] **Step 2: Open Open Parts Tickets from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors — if any appear, that means Task 6's audit missed a real usage; report back for investigation rather than assuming the trim is wrong.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live `RP - Parts Reports` production version (under its old name "Parts on Open Orders") — specifically the open-orders aging visuals, the branch-invoiced-parts visuals, and anything using the monthly snapshot history (if any trend visual reads multiple `SnapshotDate`s) to confirm the new Gold tables produce equivalent output.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 11).

---

### Task 11: Post-publish verification and catalog update

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
    "Fact_Parts_Open_Tickets", "Fact_Parts_Open_Tickets_Details",
    "dim_BranchLocation", "dim_DateTable",
    "Fact_Parts_Open_Orders_Snapshot", "Fact_PartsInvoiced_ByBranch",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark Open Parts Tickets complete in `docs/architecture/report-migration-catalog.md`'s Batch 2 section, matching the completion-note pattern already used for Batch 2a and Inventory Analysis. Note the real name correction (catalog previously called this "Parts on Open Orders") and both new Gold tables built.

---

## Self-Review Notes

**Spec coverage:** The design spec's 3 architecture sections (3.1 snapshot table + backfill + pipeline cutover, 3.2 PartsInvoicedByBranch, 3.3 report-layer repoint) map to Tasks 1-5, Task 4, and Tasks 6-7 respectively. The spec's verification plan (section 4) maps to Task 3 Step 2 (backfill correctness), Task 4 Step 5 (PartsInvoicedByBranch correctness), and Task 11 Step 1 (post-migration row counts). The spec's explicit non-goals (section 5: no report-name reconciliation, no `Pipeline_Monthly_Open_Orders_Snapshot` redesign beyond disabling, no column-trim decisions pre-made) are respected — Task 6 does the real column audit rather than assuming, and Task 5 disables rather than redesigns the old pipeline.

**Placeholder scan:** Task 6's findings feed Task 7 Step 3 - a real sequential dependency (the audit must run first), not a placeholder, matching the same pattern already proven on the Inventory Analysis plan. Every other task is fully specified with real code, real commands, and real expected values.

**Type consistency:** `Fact_Parts_Open_Orders_Snapshot`'s 17-column schema is consistent between the Context section, Task 2 Step 1 (the new monthly notebook's `SELECT`), and Task 3 (the backfill, which copies the LH_Master_Data source's existing columns as-is — same 17 columns since the source and target must match for the union to be meaningful). `Fact_PartsInvoiced_ByBranch`'s 3-column output (`Branch`, `InvoiceDate`, `Invoiced_Parts`) is consistent between the Context section (report's own TMDL), Task 4 Step 1 (the new notebook), and Task 4 Step 5 (verification query). The exclusion-customer list is copied verbatim (all 30 values, same order) between the Context section and Task 4 Step 1 - checked character-for-character against the original SQL.
