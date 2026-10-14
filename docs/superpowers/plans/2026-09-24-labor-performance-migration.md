# Labor Performance Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the `Labor Performance` report from `LH_Master_Data` to `DP_Presentation`: register 1 already-built but unregistered dimension notebook, build 3 new fact notebooks from already-migrated Silver tables, and repoint the report — a faithful port, no redesign.

**Architecture:** `dim_Technician_Code_Names` just needs registering (no code changes). The 3 new fact notebooks (`TechnicianAttendance`, `TechnicianPunchedTime`, `TechnicianEfficiency`) are faithful ports of real, already-resolved SQL Anywhere view logic, built from Silver tables that already exist (`Silver_WkMechAdj`, `Silver_WkMechWk`, `Silver_WkOthSub`), each trimmed to the columns the report actually uses (confirmed via a 4-method audit: DAX grep, `relationships.tmdl`, `pbir fields list`, and raw visual-JSON grep for bookmark and non-DAX usage).

**Tech Stack:** PySpark notebooks in Microsoft Fabric (`DP - Presentation - Dev`/`DP - Staging - Dev` workspaces), `fab` CLI for deployment, TMDL for the semantic model, DuckDB for verification.

---

## Real column-usage findings (already confirmed, not deferred to a later audit task)

Cross-checked this session via DAX grep, `relationships.tmdl`, `pbir fields list`, a full bookmark grep, and a raw visual-JSON grep for every candidate-unused column (the last one catches things the others miss — e.g. `TechnicianEfficiency[AvailableHours]` only surfaced via `pbir fields list` as a direct visual aggregation, never a named DAX measure). `Year`/`Month` are confirmed unused on **all three** fact tables — `dim_DateTable`'s `DateKey` relationship handles all date-based grouping in this report, so neither raw table needs its own calendar columns.

- **`TechnicianAttendance`** needs only: `DateKey`, `Branch`, `TechCode`, `AttendanceHours`.
- **`TechnicianPunchedTime`** needs only: `DateKey`, `Branch`, `TechCode`, `HoursWorked`.
- **`TechnicianEfficiency`** needs only: `DateKey`, `Branch`, `TechCode`, `InvoiceHours`, `ReworkHours`, `EfficiencyRateNumerator`, `EfficiencyRateDenominator`, `AvailableHours`.
- Relationships use `TechCode` → `dim_Technician_Code_Names.TechnicianCode` (business key, not `TechnicianKey`) — already the exact key the existing Gold dimension build uses.
- **`AvailableHours` resolved**: production's own `df_TechnicianEfficiency_Raw.Dataflow` header claims `AvailableHours` comes "from TechnicianAttendance" — this is the same false claim the `project_labor_performance_technician_views_resolved.md` memory already proved wrong for the table as a whole (`TechnicianEfficiency` is a plain passthrough of `TechnicianInvoice` alone, not a join of 3 tables). The memory's own two independently-derived formulas resolve this: `AvailableHours = HoursPunched − DelayHours − OtherHours`, and separately, the internal algebra's `available` variable (which becomes `EfficiencyRateDenominator`) = `hwork − other − delay`. Since `HoursPunched` and `hwork` are both `SUM(HoursWorked)` from the same source, **`AvailableHours` and `EfficiencyRateDenominator` are the same computed value** — no further source SQL needs pulling, no separate join needed.

## Real Silver table schemas (confirmed via DuckDB this session — use these exact column names, not the source view's internal aliases)

```
Silver_WkMechAdj (12 cols): TechCode, LineNumber, AdjustmentDate, Type, Paid, Hours, StartTime, EndTime, Branch, CreationDate, ModifiedDate, GuidSO
Silver_WkMechWk (19 cols): Branch, WorkOrder, JobCode, JobType, TechCode, SequenceNumber, ClockInDate, StartTime, FinishTime, InvoiceHours, HoursWorked, HoursRework, LaborCost, LaborSale, DelayCode, DelayHours, LaborType, WorkCategory, ModifiedDate
Silver_WkOthSub (21 cols): Branch, WorkOrder, JobCode, JobType, EstLabor, ActLabor, InvLabor, EstHours, EstParts, ActParts, InvParts, IsMachineDown, WorkCategory, JobStatus, IsNonRevenue, IsFieldRepair, IsStandardLabor, InvoiceNumber, InvoiceDate, ClaimNumber, ModifiedDate
```

Note: `Silver_WkMechWk` has its own `HoursRework` column, but the resolved formula's `rework` aggregate is **not** a sum of that column — it's derived from negative `InvoiceHours` entries on `REWORK`-coded jobs (`SUM(CASE WHEN InvoiceHours<0 AND JobCode LIKE '%REWORK%' THEN -InvoiceHours ELSE 0 END)`), matching the real resolved SQL exactly. Don't substitute `HoursRework` — it's an unrelated raw column.

---

### Task 1: Register `Build_Gold_TechnicianCodeNames.Notebook`

**Files:**
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

Already built, already correct, already populated (1,456 rows, confirmed via `delta_scan` this session) — a pure registration fix, same bug class as every other "leftover completed work never wired into the pipeline" case found repeatedly this project.

- [ ] **Step 1: Get the real notebookId**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab get "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_TechnicianCodeNames.Notebook" -q "id"
```

- [ ] **Step 2: Register in `deploy/dp_backend_scope.json`**

Read the file first to match its exact existing style (see the `Build_Gold_JobCodes`/`Build_Gold_WkcdPart` entries at the end of the `notebooks` array for the closest precedent). Insert a new entry using the real notebookId from Step 1:
```json
    {"name": "Build_Gold_TechnicianCodeNames", "tier": "gold", "cadence": "monthly",
     "notebookId": "<real id from Step 1>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_TechnicianCodeNames.Notebook"},
```
`cadence: "monthly"` matches this project's convention for slow-changing dimensions (`Build_Gold_BranchLocation`, `Build_Gold_Salesperson`, `Build_Gold_Franchise` are all `"monthly"`) — technicians change infrequently, and the notebook's own header recommends a monthly reference-data schedule. Use a precise Edit-tool text insertion, never a full `json.dump()` rewrite (confirmed multiple times this project that reformats the whole file into a large unwanted diff). Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 3: Run once to confirm it's current**

```bash
fab job run "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_TechnicianCodeNames.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`.

- [ ] **Step 4: DuckDB verification**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

r = con.execute(f"SELECT COUNT(*) AS total, COUNT(DISTINCT TechnicianCode) AS distinct_codes FROM delta_scan('{base}/dim_Technician_Code_Names')").fetchone()
print(f"dim_Technician_Code_Names: total={r[0]:,}, distinct_codes={r[1]:,}")
```
Expected: `total == distinct_codes` (the notebook already `dropDuplicates`s on `TechnicianCode`), close to the previously-confirmed 1,456.

- [ ] **Step 5: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add deploy/dp_backend_scope.json
git commit -m "Register unregistered Build_Gold_TechnicianCodeNames notebook

Already built and correct (from the earlier Dimensions catalog audit
project - already fixes a real production bug, IsActive wired to the
real WkMechFl.IsTerminated value instead of production's own
hardcoded-always-true literal), just never wired into the daily
pipeline. Same never-registered-notebook pattern found repeatedly
this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Build `Build_Gold_TechnicianAttendance.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

Faithful port of the real resolved `Administrator.TechnicianAttendance` view SQL (`WkMechAdj` grouped by Branch/TechCode/Year/Month, `WHERE end_time IS NOT NULL AND Branch IS NOT NULL`), trimmed to the 4 real-usage columns.

- [ ] **Step 1: Write `Build_Gold_TechnicianAttendance.Notebook`**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook/notebook-content.py`:

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

# Build_Gold_TechnicianAttendance
# Purpose: Reproduce production's TechnicianAttendance
# (df_TechnicianAttendance_Raw.Dataflow in LH_Master_Data reads
# Administrator.TechnicianAttendance directly), part of the Labor
# Performance migration (2026-09-24).
#
# SOURCE: Silver_WkMechAdj. Real resolved view SQL (see
# project_labor_performance_technician_views_resolved.md):
#   select tech_branch as Branch, isnull(trim(upper(tech_code)),'') as TechnicianCode,
#          month(adj_date) as Month, year(adj_date) as Year,
#          isnull(sum(hours),0) as AttendanceHours
#   from Administrator.wkmechadj
#   where end_time is not null and Branch is not null
#   group by branch, TechnicianCode, Year, Month
#
# GRAIN: One row per Branch + TechCode + calendar month.
#
# TRIMMED to real usage (confirmed via DAX grep + relationships.tmdl +
# pbir fields list + raw visual-JSON grep this session): only DateKey,
# Branch, TechCode, AttendanceHours are ever referenced anywhere in the
# report. Year/Month exist on production's own table but are unused -
# dim_DateTable's DateKey relationship handles all date grouping.
#
# Faithful port, no bugs found - matches the resolved SQL exactly.

print("=" * 80)
print("BUILD_GOLD_TECHNICIANATTENDANCE")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

source = spark.read.table("Silver_WkMechAdj")

filtered = source.filter(
    F.col("EndTime").isNotNull() & F.col("Branch").isNotNull()
)

grouped = (
    filtered
    .withColumn("TechCode", F.upper(F.trim(F.coalesce(F.col("TechCode"), F.lit("")))))
    .withColumn("DateKey", F.trunc(F.col("AdjustmentDate"), "month"))
    .groupBy("Branch", "TechCode", "DateKey")
    .agg(F.coalesce(F.sum(F.col("Hours")), F.lit(0.0)).alias("AttendanceHours"))
)

technician_attendance = grouped.select("DateKey", "Branch", "TechCode", "AttendanceHours")

row_count = technician_attendance.count()
print(f"TechnicianAttendance rows: {row_count:,}")

technician_attendance.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/TechnicianAttendance")

spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/TechnicianAttendance` RETAIN 0 HOURS")
print("Gold build complete: TechnicianAttendance written and vacuumed.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/TechnicianAttendance` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

coverage = spark.sql("""
    SELECT COUNT(DISTINCT TechCode) AS distinct_techs, MIN(DateKey) AS earliest, MAX(DateKey) AS latest
    FROM delta.`Tables/TechnicianAttendance`
""").toPandas()
print("\nCoverage check:")
print(coverage.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

Generate a real v4 UUID for `logicalId`. Create `workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook/.platform`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_TechnicianAttendance"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<the generated guid>"
  }
}
```

- [ ] **Step 3: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianAttendance.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook" --format .py -f
```
Fresh CREATE — this works fine (`fab import` is only broken for updates to existing notebooks). If it needs a content fix after this, use the raw API workaround (base64 payload + `fab api -X post .../updateDefinition`), not `fab import` again.

- [ ] **Step 4: Get the notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianAttendance.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianAttendance.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. Record the notebookId for Step 6.

- [ ] **Step 5: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `deploy/dp_backend_scope.json`**

Same precise-Edit-tool-insertion approach as Task 1 Step 2:
```json
    {"name": "Build_Gold_TechnicianAttendance", "tier": "gold", "cadence": "daily",
     "notebookId": "<real id from Step 4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook"},
```
Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 7: DuckDB verification**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

r = con.execute(f"SELECT COUNT(*) AS total, MIN(DateKey) AS earliest, MAX(DateKey) AS latest FROM delta_scan('{base}/TechnicianAttendance')").fetchone()
print(f"TechnicianAttendance: total={r[0]:,}, earliest={r[1]}, latest={r[2]}")
```
Report the real numbers — don't assume a specific count, this is genuinely new data.

- [ ] **Step 8: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianAttendance.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_TechnicianAttendance notebook

Faithful port of the real resolved Administrator.TechnicianAttendance
view SQL (WkMechAdj grouped by Branch/TechCode/month, filtered to
rows with an EndTime and a Branch), trimmed to the report's real
4-column usage (DateKey, Branch, TechCode, AttendanceHours - Year/Month
confirmed unused, dim_DateTable handles date grouping).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Gold_TechnicianPunchedTime.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

Faithful port of the real resolved `Administrator.TechnicianPunchedTime` view SQL (`WkMechWk` gated to a same-day `WkMechAdj` attendance match, `WHERE finish_time IS NOT NULL`), trimmed to the 4 real-usage columns — the job-type-bucketed hour columns and `JobCode`/`JobType` from the source view are confirmed unused, so this notebook skips computing them entirely.

- [ ] **Step 1: Write `Build_Gold_TechnicianPunchedTime.Notebook`**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook/notebook-content.py`:

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

# Build_Gold_TechnicianPunchedTime
# Purpose: Reproduce production's TechnicianPunchedTime
# (df_TechnicianPunchedTime_Raw.Dataflow reads
# Administrator.TechnicianPunchedTime directly), part of the Labor
# Performance migration (2026-09-24).
#
# SOURCE: Silver_WkMechWk gated to a same-day Silver_WkMechAdj
# attendance match, matching the resolved view's own semi-join (see
# project_labor_performance_technician_views_resolved.md): "WkMechWk
# gated to only (date, tech) combos with a valid same-day WkMechAdj
# attendance record", WHERE finish_time IS NOT NULL.
#
# The resolved source view also computes job-type-bucketed hour columns
# (Internal/Warranty/Retail/Sundry/Fleet/Agreement/Other) and carries
# JobCode/JobType - all confirmed unused anywhere in this report (DAX
# grep + relationships.tmdl + pbir fields list + raw visual-JSON grep,
# this session). Skipped entirely - only the total HoursWorked is
# needed, trimmed to DateKey/Branch/TechCode/HoursWorked.
#
# GRAIN: One row per Branch + TechCode + calendar month (matching
# TechnicianAttendance's own grain, since this report only ever
# aggregates PunchedTime to that level).

print("=" * 80)
print("BUILD_GOLD_TECHNICIANPUNCHEDTIME")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

wkmechwk = spark.read.table("Silver_WkMechWk")
wkmechadj = spark.read.table("Silver_WkMechAdj")

# Same attendance scope as Build_Gold_TechnicianAttendance's own filter,
# reused here as the semi-join gate.
attendance_scope = (
    wkmechadj
    .filter(F.col("EndTime").isNotNull() & F.col("Branch").isNotNull())
    .withColumn("_TechCode", F.upper(F.trim(F.coalesce(F.col("TechCode"), F.lit("")))))
    .select("_TechCode", F.col("AdjustmentDate").alias("_AdjustmentDate"))
    .dropDuplicates(["_TechCode", "_AdjustmentDate"])
)

punched = (
    wkmechwk
    .filter(F.col("FinishTime").isNotNull())
    .withColumn("TechCode", F.upper(F.trim(F.coalesce(F.col("TechCode"), F.lit("")))))
)

# Semi-join: only (date, tech) combos with a matching same-day attendance record.
gated = punched.join(
    attendance_scope,
    (punched["TechCode"] == attendance_scope["_TechCode"])
    & (punched["ClockInDate"] == attendance_scope["_AdjustmentDate"]),
    how="inner",
).drop("_TechCode", "_AdjustmentDate")

grouped = (
    gated
    .withColumn("DateKey", F.trunc(F.col("ClockInDate"), "month"))
    .groupBy("Branch", "TechCode", "DateKey")
    .agg(F.coalesce(F.sum(F.col("HoursWorked")), F.lit(0.0)).alias("HoursWorked"))
)

technician_punched_time = grouped.select("DateKey", "Branch", "TechCode", "HoursWorked")

row_count = technician_punched_time.count()
print(f"TechnicianPunchedTime rows: {row_count:,}")

technician_punched_time.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/TechnicianPunchedTime")

spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/TechnicianPunchedTime` RETAIN 0 HOURS")
print("Gold build complete: TechnicianPunchedTime written and vacuumed.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/TechnicianPunchedTime` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

coverage = spark.sql("""
    SELECT COUNT(DISTINCT TechCode) AS distinct_techs, MIN(DateKey) AS earliest, MAX(DateKey) AS latest
    FROM delta.`Tables/TechnicianPunchedTime`
""").toPandas()
print("\nCoverage check:")
print(coverage.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

Same pattern as Task 2 Step 2, `displayName: "Build_Gold_TechnicianPunchedTime"`, a new generated GUID.

- [ ] **Step 3: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianPunchedTime.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook" --format .py -f
```

- [ ] **Step 4: Get the notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianPunchedTime.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianPunchedTime.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. Record the notebookId for Step 6.

- [ ] **Step 5: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `deploy/dp_backend_scope.json`**

```json
    {"name": "Build_Gold_TechnicianPunchedTime", "tier": "gold", "cadence": "daily",
     "notebookId": "<real id from Step 4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook"},
```
Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 7: DuckDB verification**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

r = con.execute(f"SELECT COUNT(*) AS total, MIN(DateKey) AS earliest, MAX(DateKey) AS latest FROM delta_scan('{base}/TechnicianPunchedTime')").fetchone()
print(f"TechnicianPunchedTime: total={r[0]:,}, earliest={r[1]}, latest={r[2]}")
```
Report the real numbers.

- [ ] **Step 8: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianPunchedTime.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_TechnicianPunchedTime notebook

Faithful port of the real resolved Administrator.TechnicianPunchedTime
view SQL (WkMechWk gated to a same-day WkMechAdj attendance match,
filtered to rows with a FinishTime), trimmed to the report's real
4-column usage. Skips the job-type-bucketed hour columns and
JobCode/JobType entirely - confirmed unused anywhere in this report.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 4: Build `Build_Gold_TechnicianEfficiency.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

The most involved of the three: builds `TechnicianInvoice` as an in-notebook intermediate DataFrame (never persisted as its own table, matching how `Fact_GapAnalysis`/`Fact_BranchAnalysis` build intermediates inline elsewhere in this project), computes the full resolved Efficiency formula, and persists only the 8 real-usage columns.

- [ ] **Step 1: Write `Build_Gold_TechnicianEfficiency.Notebook`**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook/notebook-content.py`:

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

# Build_Gold_TechnicianEfficiency
# Purpose: Reproduce production's TechnicianEfficiency
# (df_TechnicianEfficiency_Raw.Dataflow reads
# Administrator.TechnicianEfficiency directly), part of the Labor
# Performance migration (2026-09-24).
#
# SOURCE: builds TechnicianInvoice in-notebook as an intermediate (never
# persisted as its own table) from Silver_WkMechWk LEFT JOIN
# Silver_WkOthSub on (Branch, WorkOrder, JobCode, JobType), filtered to
# WHERE WkOthSub.InvoiceNumber is non-empty AND
# YEAR(WkOthSub.InvoiceDate) >= YEAR(current_date) - 1 - the real,
# PERMANENT 2-year window baked into the source view itself (confirmed
# via Brian's own real SQL Anywhere view pull - see
# project_labor_performance_technician_views_resolved.md). This is a
# faithful port, not the fuller-history redesign Brian previously
# flagged as a future possibility - that's explicitly out of scope here.
#
# FULL EFFICIENCY FORMULA (already fully derived from the real ALTER
# VIEW SQL's positional column list - see the memory's own derivation
# section for the full algebra):
#   hwork    = SUM(ISNULL(HoursWorked,0))
#   invoice  = SUM(CASE WHEN InvoiceHours>0 THEN InvoiceHours ELSE 0 END)
#   rework   = SUM(CASE WHEN InvoiceHours<0 AND JobCode LIKE '%REWORK%'
#                   THEN -InvoiceHours ELSE 0 END)
#   delay    = SUM(ISNULL(DelayHours,0))
#   other    = SUM(CASE WHEN os.JobType='S' AND JobCode NOT IN
#                   ('/NR-REWORK','REWORK','/NR REWORK')
#                   THEN HoursWorked ELSE 0 END)
#   EfficiencyRateDenominator (= internal "available") = hwork - other - delay
#   EfficiencyRateNumerator   (= internal "hrs_billed") = invoice - other - rework
#
# AvailableHours RESOLVED (was an open question in the design spec):
# production's own dataflow header claims AvailableHours comes "from
# TechnicianAttendance" - this is the same false claim the memory
# already proved wrong for the table as a whole (TechnicianEfficiency
# is a plain passthrough of TechnicianInvoice alone). The memory's own
# formula for AvailableHours is "HoursPunched - DelayHours - OtherHours",
# which is algebraically identical to EfficiencyRateDenominator's
# "hwork - other - delay" (HoursPunched and hwork are the same
# SUM(HoursWorked) aggregate). AvailableHours and EfficiencyRateDenominator
# are the same computed value - no separate join to TechnicianAttendance
# needed, confirmed via the memory's own two independent derivations.
#
# TRIMMED to real usage (confirmed via DAX grep + relationships.tmdl +
# pbir fields list + raw visual-JSON grep this session): DateKey,
# Branch, TechCode, InvoiceHours, ReworkHours, EfficiencyRateNumerator,
# EfficiencyRateDenominator, AvailableHours. WorkedHours/BilledHours/
# GainLossHours/LostHours/TechnicianName/Year/Month all confirmed
# unused - not computed at all.
#
# GRAIN: One row per Branch + TechCode + calendar month.

print("=" * 80)
print("BUILD_GOLD_TECHNICIANEFFICIENCY")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

wkmechwk = spark.read.table("Silver_WkMechWk")
wkothsub = spark.read.table("Silver_WkOthSub")

wk = wkmechwk.alias("wk")
os_ = wkothsub.alias("os")

# TechnicianInvoice intermediate: WkMechWk LEFT JOIN WkOthSub, filters
# on the WkOthSub side effectively make this an inner join (a NULL
# InvoiceNumber/InvoiceDate can never pass the WHERE clause below) -
# matching the resolved view's own real behavior exactly.
joined = wk.join(
    os_,
    (F.col("wk.Branch") == F.col("os.Branch"))
    & (F.col("wk.WorkOrder") == F.col("os.WorkOrder"))
    & (F.col("wk.JobCode") == F.col("os.JobCode"))
    & (F.col("wk.JobType") == F.col("os.JobType")),
    how="inner",
)

technician_invoice = joined.filter(
    (F.col("os.InvoiceNumber").isNotNull())
    & (F.trim(F.col("os.InvoiceNumber")) != "")
    & (F.year(F.col("os.InvoiceDate")) >= F.year(F.current_date()) - 1)
)

with_derived = (
    technician_invoice
    .withColumn("TechCode", F.upper(F.trim(F.coalesce(F.col("wk.TechCode"), F.lit("")))))
    .withColumn("DateKey", F.trunc(F.col("wk.ClockInDate"), "month"))
    .withColumn(
        "_InvoiceAmt",
        F.when(F.col("wk.InvoiceHours") > 0, F.col("wk.InvoiceHours")).otherwise(F.lit(0.0)),
    )
    .withColumn(
        "_ReworkAmt",
        F.when(
            (F.col("wk.InvoiceHours") < 0) & (F.col("wk.JobCode").like("%REWORK%")),
            -F.col("wk.InvoiceHours"),
        ).otherwise(F.lit(0.0)),
    )
    .withColumn("_DelayAmt", F.coalesce(F.col("wk.DelayHours"), F.lit(0.0)))
    .withColumn(
        "_OtherAmt",
        F.when(
            (F.col("os.JobType") == "S")
            & (~F.col("wk.JobCode").isin("/NR-REWORK", "REWORK", "/NR REWORK")),
            F.coalesce(F.col("wk.HoursWorked"), F.lit(0.0)),
        ).otherwise(F.lit(0.0)),
    )
    .withColumn("_HworkAmt", F.coalesce(F.col("wk.HoursWorked"), F.lit(0.0)))
)

grouped = (
    with_derived
    .groupBy(F.col("wk.Branch").alias("Branch"), "TechCode", "DateKey")
    .agg(
        F.sum("_InvoiceAmt").alias("InvoiceHours"),
        F.sum("_ReworkAmt").alias("ReworkHours"),
        F.sum("_DelayAmt").alias("_TotalDelay"),
        F.sum("_OtherAmt").alias("_TotalOther"),
        F.sum("_HworkAmt").alias("_TotalHwork"),
    )
)

technician_efficiency = (
    grouped
    .withColumn(
        "EfficiencyRateDenominator",
        F.col("_TotalHwork") - F.col("_TotalOther") - F.col("_TotalDelay"),
    )
    .withColumn(
        "EfficiencyRateNumerator",
        F.col("InvoiceHours") - F.col("_TotalOther") - F.col("ReworkHours"),
    )
    .withColumn("AvailableHours", F.col("EfficiencyRateDenominator"))
    .select(
        "DateKey", "Branch", "TechCode", "InvoiceHours", "ReworkHours",
        "EfficiencyRateNumerator", "EfficiencyRateDenominator", "AvailableHours",
    )
)

row_count = technician_efficiency.count()
print(f"TechnicianEfficiency rows: {row_count:,}")

technician_efficiency.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/TechnicianEfficiency")

spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`Tables/TechnicianEfficiency` RETAIN 0 HOURS")
print("Gold build complete: TechnicianEfficiency written and vacuumed.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/TechnicianEfficiency` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

check = spark.sql("""
    SELECT
        COUNT(DISTINCT TechCode) AS distinct_techs,
        MIN(DateKey) AS earliest, MAX(DateKey) AS latest,
        SUM(CASE WHEN AvailableHours <> EfficiencyRateDenominator THEN 1 ELSE 0 END) AS mismatch_rows
    FROM delta.`Tables/TechnicianEfficiency`
""").toPandas()
print("\nCoverage + AvailableHours-equals-EfficiencyRateDenominator sanity check (mismatch_rows must be 0):")
print(check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

Same pattern as Task 2 Step 2, `displayName: "Build_Gold_TechnicianEfficiency"`, a new generated GUID.

- [ ] **Step 3: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianEfficiency.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook" --format .py -f
```

- [ ] **Step 4: Get the notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianEfficiency.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Labor Performance.Folder/Build_Gold_TechnicianEfficiency.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. Check the "mismatch_rows must be 0" assertion in the output specifically — if it's ever nonzero, stop and re-investigate the `AvailableHours`/`EfficiencyRateDenominator` algebra before proceeding, don't just note it and move on. Record the notebookId for Step 6.

- [ ] **Step 5: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `deploy/dp_backend_scope.json`**

```json
    {"name": "Build_Gold_TechnicianEfficiency", "tier": "gold", "cadence": "daily",
     "notebookId": "<real id from Step 4>", "workspaceId": "73fd5443-240e-410a-990a-98827f32c087",
     "path": "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook"},
```
Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 7: DuckDB verification**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

r = con.execute(f"""
    SELECT COUNT(*) AS total, MIN(DateKey) AS earliest, MAX(DateKey) AS latest,
           SUM(CASE WHEN AvailableHours <> EfficiencyRateDenominator THEN 1 ELSE 0 END) AS mismatch_rows
    FROM delta_scan('{base}/TechnicianEfficiency')
""").fetchone()
print(f"TechnicianEfficiency: total={r[0]:,}, earliest={r[1]}, latest={r[2]}, mismatch_rows={r[3]}")
```
Report the real numbers. `mismatch_rows` must be 0.

- [ ] **Step 8: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Labor Performance/Build_Gold_TechnicianEfficiency.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_TechnicianEfficiency notebook

Faithful port of the real resolved Administrator.TechnicianEfficiency
view SQL - builds TechnicianInvoice as an in-notebook intermediate
(WkMechWk LEFT JOIN WkOthSub, invoiced-only, real permanent 2-year
window), computes the full derived Efficiency formula, trimmed to the
report's real 8-column usage. Resolves the AvailableHours open
question from the design spec: it's algebraically identical to
EfficiencyRateDenominator, not a separate join to TechnicianAttendance
as production's own (already-proven-wrong-elsewhere) header comment
claims.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 5: Report-layer repoint and trim

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Labor Performance.SemanticModel/definition/tables/dim_Technician_Code_Names.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Labor Performance.SemanticModel/definition/tables/TechnicianAttendance.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Labor Performance.SemanticModel/definition/tables/TechnicianPunchedTime.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Labor Performance.SemanticModel/definition/tables/TechnicianEfficiency.tmdl`

**Depends on Tasks 1-4** (all 4 Gold tables must exist first).

**IMPORTANT: this step is Brian's own action in Desktop, not a Claude pre-edit.** Per `feedback_report_migration_desktop_source_switch` (this project's established, hard-learned rule): Claude never directly edits a report's TMDL connection string — Desktop's own open-session state silently overwrites any external file edit on its next write. This task exists in the plan to document exactly what the switch needs to look like, so Brian (or whoever executes this task) knows precisely what "done" means — **do not attempt to make these file edits directly.** Ask Brian whether Desktop is currently open on this report before touching any of these 4 files for any reason (including a post-hoc verification fix), matching the hard requirement already established this session on Job Code Parts Advisor.

- [ ] **Step 1: Confirm with Brian he's ready to do the Desktop source switch**

Reference this task's column lists (below) so he knows exactly which columns should exist after the switch, in case Desktop's own column-picker doesn't show something expected.

- [ ] **Step 2: Brian switches all 4 tables' data source in Desktop**

Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

Real expected column sets after the switch (Desktop will show exactly these, since the Gold tables were built with only these columns):
- `dim_Technician_Code_Names`: `TechnicianKey`, `TechnicianCode`, `TechnicianDisplayName`, `IsActive`
- `TechnicianAttendance`: `DateKey`, `Branch`, `TechCode`, `AttendanceHours`
- `TechnicianPunchedTime`: `DateKey`, `Branch`, `TechCode`, `HoursWorked`
- `TechnicianEfficiency`: `DateKey`, `Branch`, `TechCode`, `InvoiceHours`, `ReworkHours`, `EfficiencyRateNumerator`, `EfficiencyRateDenominator`, `AvailableHours`

- [ ] **Step 3: Verify no stray connection strings remain (Claude, after Brian confirms the switch + a commit exist in git)**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Labor Performance.SemanticModel/definition/tables/"
```
Expected: zero matches.

- [ ] **Step 4: Verify relationships survived the switch**

```bash
cat "workspaces/RP - Dev/Labor Performance.SemanticModel/definition/relationships.tmdl"
```
Expected: the same 9 relationships as before (`TechnicianEfficiency`/`TechnicianPunchedTime`/`TechnicianAttendance` each relating `DateKey`→`dim_DateTable.Date`, `Branch`→`dim_BranchLocation.BranchID`, `TechCode`→`dim_Technician_Code_Names.TechnicianCode`) — Desktop's own relationship-reload behavior after a source switch has been unpredictable on prior reports in this project, so this needs a real check, not an assumption.

---

### Task 6: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Labor Performance.pbip`

- [ ] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep -i "labor"
```
Expected: only `Labor Performance.Report` and `Labor Performance.SemanticModel` — no `.pbip` (confirmed this session).

- [ ] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Labor Performance.Report"
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
git add "workspaces/RP - Dev/Labor Performance.pbip"
git commit -m "Add Labor Performance.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 7: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 1-6's commits.

- [ ] **Step 2: Open Labor Performance from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean the column-usage audit missed a real usage) or a relationship-load error on `dim_Technician_Code_Names` similar to Job Code Parts Advisor's `dim_JobCodes` incident — unlikely here since `TechnicianCode` is already deduplicated by construction in the existing Gold notebook, but report back for investigation rather than assuming if it happens.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live production version — specifically the `Efficiency`/`Productivity`/`Labor Performance` KPI cards and the YoY/MoM variance visuals, to confirm the new Gold tables produce equivalent output to production's existing `TechnicianAttendance`/`TechnicianPunchedTime`/`TechnicianEfficiency` tables.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 8).

---

### Task 8: Post-publish verification and catalog update

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
    "dim_Technician_Code_Names", "TechnicianAttendance", "TechnicianPunchedTime",
    "TechnicianEfficiency", "dim_BranchLocation", "dim_DateTable",
]
for t in tables:
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark Labor Performance complete in `docs/architecture/report-migration-catalog.md`'s Tier 3 table row, and add a completion narrative section matching the style/detail level of the Job Code Parts Advisor completion section already in that file — this is the second and last of the 2 previously-unscheduled Tier 3 reports, so note that both are now done.

---

## Self-Review Notes

**Spec coverage:** The design spec's "What gets built" items 1-6 map directly to Tasks 1-6 respectively; item 5's report-layer repoint/trim maps to Task 5, item 6's `.pbip`/verification maps to Tasks 6-8. The spec's "Known risks" section (orphaned-Parquet VACUUM, UTC-safe date handling) is addressed in every new notebook (Tasks 2-4 all include the `VACUUM ... RETAIN 0 HOURS` step; `F.current_date()` is used directly in Task 4 since Spark's `current_date()` reflects the cluster's configured timezone correctly, unlike Power Query's service-side UTC quirk that caused the `DateTime.LocalNow()` bug class elsewhere in this project — this is a PySpark notebook, not a Power Query dataflow, so that specific bug doesn't apply here).

**Placeholder scan:** The `AvailableHours` open question flagged in the design spec is fully resolved inline in this plan's findings section and in Task 4's own header comment — no "TBD" remains. All real column names were verified via direct DuckDB schema checks before writing any notebook code, not assumed from the source view's internal SQL Anywhere aliases.

**Type consistency:** `TechnicianAttendance`'s real Silver schema (`TechCode, LineNumber, AdjustmentDate, Type, Paid, Hours, StartTime, EndTime, Branch, CreationDate, ModifiedDate, GuidSO`) is used identically in Task 2's notebook code. `TechnicianPunchedTime`'s real Silver schema and `TechnicianEfficiency`'s dual-source real Silver schemas are likewise used consistently between the findings section and Tasks 3-4's notebook code. The final Gold table column sets (4/4/8 columns respectively) are consistent between the findings section, each task's notebook `select()` call, and Task 5's Desktop-switch reference column lists.
