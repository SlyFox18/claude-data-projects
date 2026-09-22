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

- [ ] **Step 1: Re-confirm the old pipeline's real content**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/pipeline-content.json"
cat "workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/.schedules"
```
Expected: matches the Context section above exactly (3 activities, one notebook + 2 emails; monthly/day-1/noon-Central schedule). If it doesn't match (e.g. the pipeline has been edited since this plan was written), stop and re-investigate before Task 5 — don't assume the earlier read is still accurate.

- [ ] **Step 2: Record the real notebookId this pipeline currently calls**

The `nb_Snapshot_Parts_Open_Orders` activity's `notebookId` is `911d8be7-cd08-a5ac-402d-45283a006add` (already captured from the read above) — record it in this plan's own execution notes so Task 5 doesn't need to re-derive it.

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

- [ ] **Step 2: Write the `.platform` file**

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

- [ ] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" -f
```
Expected: success output. If the `Fact Tables/Open Parts Tickets` folder doesn't exist yet as a Fabric workspace folder, `fab import` creates the needed folder structure automatically (matches how every other nested-folder notebook in this project was created).

- [ ] **Step 4: Capture the real notebookId**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook" -q "id"
```
Record the returned GUID — needed for Step 5.

- [ ] **Step 5: Register in `dp_backend_scope.json`**

Add this entry to the `notebooks` array in `fabric-workspace-docs/deploy/dp_backend_scope.json` (matching the existing `tier: "gold", cadence: "monthly"` entries' shape exactly):
```json
{"name": "Build_Gold_PartsOpenOrdersSnapshot", "tier": "gold", "cadence": "monthly",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsOpenOrdersSnapshot.Notebook"}
```

- [ ] **Step 6: Commit**

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

- [ ] **Step 1: Write and run the backfill (as a temporary Fabric notebook cell, or via `spark.sql`/DataFrame API in an ad hoc session against `DP_Presentation`)**

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

- [ ] **Step 2: Verify the backfill matches exactly**

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

- [ ] **Step 3: Document the backfill in this plan**

Add a note here recording the run timestamp and confirmation the assert passed, since this is a one-time manual operation with no other audit trail.

---

### Task 4: Build and register `Build_Gold_PartsInvoicedByBranch.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook/.platform`
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

- [ ] **Step 2: Write the `.platform` file**

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

- [ ] **Step 3: Import the notebook into Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook" -f
```

- [ ] **Step 4: Run it once and capture the real notebookId**

Run the notebook manually in the Fabric UI (or via `fab` job trigger) to confirm it executes cleanly and creates `Fact_PartsInvoiced_ByBranch`, then:
```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook" -q "id"
```

- [ ] **Step 5: Verify against the original native query**

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

- [ ] **Step 6: Register in `dp_backend_scope.json`**

```json
{"name": "Build_Gold_PartsInvoicedByBranch", "tier": "gold", "cadence": "daily",
 "notebookId": "<real-guid-from-step-4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
 "path": "workspaces/DP - Presentation - Dev/Fact Tables/Open Parts Tickets/Build_Gold_PartsInvoicedByBranch.Notebook"}
```

- [ ] **Step 7: Commit**

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

---

### Task 5: Retire the old monthly pipeline

**Files:**
- Modify (disable, don't delete): `fabric-workspace-docs/workspaces/LH_Master_Data/Pipelines/Pipeline_Monthly_Open_Orders_Snapshot.DataPipeline/.schedules`

- [ ] **Step 1: Confirm the new notebook has run successfully at least once**

Either wait for its first real scheduled run inside `Pipeline_DP_Monthly_Refresh`, or manually trigger it once via the Fabric UI and confirm success (row count printed, no errors) — don't disable the old pipeline until this is confirmed, per the design spec's explicit ordering (never remove the old one first).

- [ ] **Step 2: Disable the old pipeline's schedule**

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

- [ ] **Step 3: Commit**

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

---

### Task 6: Exhaustive real-usage audit (report layer)

**Files:** none — investigation only. Findings get documented directly in this plan before Task 7 proceeds (same discipline as the Inventory Analysis migration's Task 1).

- [ ] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Open Parts Tickets.Report"
```

- [ ] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition"
for tbl in Fact_Parts_Open_Tickets Fact_Parts_Open_Tickets_Details dim_BranchLocation dim_DateTable fact_parts_open_orders_snapshot Fact_PartsInvoiced_ByBranch; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_#\$%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_#\$%]+)\]/\1/" | sort -u
done
```

- [ ] **Step 3: Bookmark check**

```bash
ls "Open Parts Tickets.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "Open Parts Tickets.Report/definition/bookmarks/" 2>/dev/null
```

- [ ] **Step 4: `relationships.tmdl` cross-reference**

Relationship key columns use TMDL `fromColumn:`/`toColumn:` syntax, not `Table[Column]` DAX syntax, so they won't match Step 2's grep pattern — read `relationships.tmdl` directly and note every column used as a relationship endpoint for these 6 tables (same real miss class already found and corrected on Inventory Analysis's `Fact_Inventory` relationship keys).

- [ ] **Step 5: Document findings**

For each of the 6 tables, record confirmed-used columns (keep) vs. confident-unused columns (trim) vs. ambiguous (leave as-is, note why). Expect `fact_parts_open_orders_snapshot` to land mostly/entirely in "keep everything" (it's a purpose-built append-only snapshot table where every column was deliberately selected) — confirm this against real usage rather than assuming, but don't be surprised if there's little or nothing to trim there. Add a "### Task 6 Findings" section to this plan file (same structure as the Inventory Analysis plan's "Task 1 Findings" section) before starting Task 7.

---

### Task 7: Repoint and trim the report's 6 data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_Parts_Open_Tickets.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_Parts_Open_Tickets_Details.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/fact_parts_open_orders_snapshot.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Open Parts Tickets.SemanticModel/definition/tables/Fact_PartsInvoiced_ByBranch.tmdl`

- [ ] **Step 1: Repoint all 6 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```

- [ ] **Step 2: Fix `fact_parts_open_orders_snapshot.tmdl`'s `Item=` to the new PascalCase name**

Find:
```
				    dbo_fact_parts_open_orders_snapshot = Source{[Schema="dbo",Item="fact_parts_open_orders_snapshot"]}[Data]
```
Replace with:
```
				    dbo_Fact_Parts_Open_Orders_Snapshot = Source{[Schema="dbo",Item="Fact_Parts_Open_Orders_Snapshot"]}[Data]
```
(and update the `in` clause / any other reference to the old variable name accordingly). No other `Item=` changes needed in any of the 6 files — every other real table name already matches exactly between `LH_Master_Data` and `DP_Presentation`.

- [ ] **Step 3: Trim per Task 6's findings**

For each of the 6 tables, apply Task 6's documented keep/trim decisions: remove confidently-unused `column` blocks, add/update a matching `Table.SelectColumns(...)` M-query step, check for any dangling `sortByColumn` on a trim candidate before removing it. Leave ambiguous columns untouched.

- [ ] **Step 4: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Open Parts Tickets.SemanticModel/"
```
Expected: no output.

- [ ] **Step 5: Commit**

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
