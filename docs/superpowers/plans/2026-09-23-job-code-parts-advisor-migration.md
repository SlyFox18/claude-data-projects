# Job Code Parts Advisor Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Job Code Parts Advisor report from `LH_Master_Data` to `DP_Presentation`: register 2 already-built but silently-stale fact notebooks, build 2 new small dimensions (`dim_JobCodes`, `dim_WkcdPart`) from raw sources already available in JD's Bronze mirror, and repoint the report.

**Architecture:** Both new dimensions are trivial single-table ODBC-equivalent pulls with no business logic — Bronze shortcut → thin Silver passthrough → Gold rename/cast, following this project's established 3-layer convention exactly. The 2 existing fact notebooks need no code changes, only registration.

**Tech Stack:** PySpark notebooks in Microsoft Fabric (`DP - Presentation - Dev`/`DP - Staging - Dev` workspaces), OneLake shortcuts, `fab` CLI for deployment, TMDL for the semantic model, DuckDB for verification.

---

### Task 1: Register and catch up the 2 existing fact notebooks

**Files:**
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

Both `Build_Gold_JobCodePartFrequency.Notebook` and `Build_Gold_JobCodePartFrequencyBranch.Notebook` already exist in `DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Order Parts Advisor.Folder/` and are already correct — this is a pure registration fix, no code changes, matching the same bug class (notebook built, never wired into the pipeline) found repeatedly earlier this project.

- [ ] **Step 1: Get the real notebookIds**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Order Parts Advisor.Folder/Build_Gold_JobCodePartFrequency.Notebook" -q "id"
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Order Parts Advisor.Folder/Build_Gold_JobCodePartFrequencyBranch.Notebook" -q "id"
```
Expected: `Build_Gold_JobCodePartFrequency` returns `4de52a40-792f-442f-9f9c-5267c0e18368` (already confirmed this session). Record the real `Build_Gold_JobCodePartFrequencyBranch` notebookId.

- [ ] **Step 2: Register both in `deploy/dp_backend_scope.json`**

Read the file first to match its exact existing single-line-per-entry style, then insert 2 new entries (tier=gold, cadence=daily) using the real notebookIds from Step 1, via precise Edit-tool text insertions — never a full `json.dump()` rewrite (confirmed multiple times this project that reformats the whole file into a large unwanted diff). Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 3: Run both notebooks to catch up**

```bash
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Order Parts Advisor.Folder/Build_Gold_JobCodePartFrequency.Notebook" --timeout 300
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Open Order Parts Advisor.Folder/Build_Gold_JobCodePartFrequencyBranch.Notebook" --timeout 300
```
Expected: both `Completed`, no `failureReason`. Both notebooks were last run `2026-09-14` (9 days stale) — this catches them up to current data.

- [ ] **Step 4: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 5: DuckDB freshness verification**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for t in ["Fact_JobCodePartFrequency", "Fact_JobCodePartFrequency_Branch"]:
    r = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()
    print(f"{t}: {r[0]:,} rows")
```
Expected: row counts close to the pre-run baseline (`Fact_JobCodePartFrequency` 1,160,265, `Fact_JobCodePartFrequency_Branch` 1,410,456) — these are frequency-aggregate tables computed off a 3-year rolling window, so small drift is expected, not a fixed count. Report the real numbers.

- [ ] **Step 6: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add deploy/dp_backend_scope.json
git commit -m "Register 2 unregistered Job Code Parts Advisor fact notebooks

Build_Gold_JobCodePartFrequency and Build_Gold_JobCodePartFrequencyBranch
already existed and were correct, just never wired into the daily
pipeline - the same never-registered-notebook bug class found
repeatedly this project. Both re-run to catch up from 9 days stale.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Create OneLake shortcuts for `WkCodeFl` and `WKCDPART`

**Files:** none (Fabric-side shortcuts, not git-tracked file content).

Both raw sources already exist in JD's Bronze mirror — this is a cheap shortcut, not a new ODBC pull. Two shortcuts are needed per table: one from JD's Bronze mirror into `DP_Staging` (the raw source), and later (Task 3) one from `DP_Staging` into `DP_Presentation` for each resulting `Silver_*` table — matching the exact pattern already used for `Silver_WkMechFl`/`Silver_WkMechWk`.

- [ ] **Step 1: Create the `WkCodeFl` shortcut into `DP_Staging`**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab ln "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/WkCodeFl.Shortcut" \
  --type oneLake \
  --target "../../JD_FabricOneLake.Workspace/JD_EquipRDB_Production_Bronze.Lakehouse/Tables/WkCodeFl"
```
This matches the exact real target pattern already confirmed this session on the existing `WKMECHADJ.Shortcut` (workspace `4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, lakehouse `7348c3a6-8694-4d11-bc70-1bd55be84ea2`, path `Tables/WKMECHADJ`).

- [ ] **Step 2: Create the `WKCDPART` shortcut into `DP_Staging`**

```bash
fab ln "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/WKCDPART.Shortcut" \
  --type oneLake \
  --target "../../JD_FabricOneLake.Workspace/JD_EquipRDB_Production_Bronze.Lakehouse/Tables/WKCDPART"
```

- [ ] **Step 3: Verify both shortcuts resolve real data**

```bash
fab get "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/WkCodeFl.Shortcut" -q "{name: name, wsId: target.oneLake.workspaceId, itemId: target.oneLake.itemId}"
fab get "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/WKCDPART.Shortcut" -q "{name: name, wsId: target.oneLake.workspaceId, itemId: target.oneLake.itemId}"
```
Expected: both resolve to `wsId: 4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9`, `itemId: 7348c3a6-8694-4d11-bc70-1bd55be84ea2`.

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
staging = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables"

for t in ["WkCodeFl", "WKCDPART"]:
    r = con.execute(f"SELECT COUNT(*) FROM delta_scan('{staging}/{t}')").fetchone()
    print(f"{t}: {r[0]:,} rows")
```
Expected: close to the real Bronze counts already confirmed this session (`WkCodeFl` 575,887, `WKCDPART` 1,846).

No commit needed for this task — shortcuts are Fabric-side metadata, not git-tracked file content in this repo's convention (confirmed: no `.Shortcut` files appear under `workspaces/DP - Staging - Dev/` in git for existing shortcuts like `WKMECHADJ`/`WKMECHFL`).

---

### Task 3: Build `Build_Silver_WkCodeFl.Notebook` and `Build_Silver_WKCDPART.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook/.platform`
- Create: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_WKCDPART.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Staging - Dev/Build_Silver_WKCDPART.Notebook/.platform`

Both are pure passthrough notebooks, matching the exact established convention (`Build_Silver_BranchName.Notebook`) — the original production dataflows did their column selection/renaming in the Gold layer via direct ODBC `SELECT`, not in a Silver step, so Silver here is a straight Bronze mirror with no transformation, kept for consistency with the rest of the backend.

- [ ] **Step 1: Write `Build_Silver_WkCodeFl.Notebook`**

Create `workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook/notebook-content.py`:

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
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_WkCodeFl
# Purpose: Part of the Job Code Parts Advisor migration (2026-09-23).
# Migrates WkCodeFl off the old direct-ODBC df_Dim_WkCodeFl.Dataflow onto
# a OneLake shortcut of JD's own live Bronze mirror.
#
# The original dataflow did all its column selection/renaming directly in
# a single ODBC SQL query (no separate Silver-equivalent step existed) -
# there is no existing rename contract to preserve at this layer. This
# notebook passes every Bronze column through unchanged, still gets its
# own notebook/Silver table for consistency with the rest of this backend
# and to leave room for future normalization if a real need shows up -
# same pattern as Build_Silver_BranchName.Notebook.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_WKCODEFL")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

bronze = spark.read.table("WkCodeFl")
bronze_count = bronze.count()
print(f"Bronze WkCodeFl rows: {bronze_count:,}")

# No column selection/renaming - the original dataflow did all of that in
# a single downstream ODBC SQL query, not at this layer. Passthrough.
silver = bronze

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook is a pure passthrough, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkCodeFl")
print("Silver build complete: Silver_WkCodeFl written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkCodeFl` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write `Build_Silver_WkCodeFl.Notebook`'s `.platform` file**

Generate a real v4 UUID for `logicalId`. Create `workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook/.platform`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkCodeFl"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<the generated guid>"
  }
}
```

- [ ] **Step 3: Write `Build_Silver_WKCDPART.Notebook`**

Create `workspaces/DP - Staging - Dev/Build_Silver_WKCDPART.Notebook/notebook-content.py` — identical structure to Step 1, with `WKCDPART`/`Silver_WKCDPART` in place of `WkCodeFl`/`Silver_WkCodeFl`:

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
# META     }
# META   }
# META }

# CELL ********************

# Build_Silver_WKCDPART
# Purpose: Part of the Job Code Parts Advisor migration (2026-09-23).
# Migrates WKCDPART off the old direct-ODBC df_Dim_WKCDPART.Dataflow onto
# a OneLake shortcut of JD's own live Bronze mirror.
#
# The original dataflow did all its column selection/renaming directly in
# a single ODBC SQL query (no separate Silver-equivalent step existed) -
# there is no existing rename contract to preserve at this layer. This
# notebook passes every Bronze column through unchanged, still gets its
# own notebook/Silver table for consistency with the rest of this backend
# and to leave room for future normalization if a real need shows up -
# same pattern as Build_Silver_BranchName.Notebook.
#
# NOT in scope: any gold-layer business logic, any report repointing, any
# refresh schedule.

print("=" * 80)
print("BUILD_SILVER_WKCDPART")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

bronze = spark.read.table("WKCDPART")
bronze_count = bronze.count()
print(f"Bronze WKCDPART rows: {bronze_count:,}")

# No column selection/renaming - the original dataflow did all of that in
# a single downstream ODBC SQL query, not at this layer. Passthrough.
silver = bronze

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook is a pure passthrough, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WKCDPART")
print("Silver build complete: Silver_WKCDPART written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WKCDPART` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Write `Build_Silver_WKCDPART.Notebook`'s `.platform` file**

Same pattern as Step 2, `displayName: "Build_Silver_WKCDPART"`, a new generated GUID.

- [ ] **Step 5: Import both to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Staging - Dev.Workspace/Build_Silver_WkCodeFl.Notebook" \
  -i "workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook" --format .py -f
fab import "DP - Staging - Dev.Workspace/Build_Silver_WKCDPART.Notebook" \
  -i "workspaces/DP - Staging - Dev/Build_Silver_WKCDPART.Notebook" --format .py -f
```
Both are fresh CREATEs — this works fine (`fab import` is only broken for updates to existing notebooks). If either needs a content fix after this, use the raw API workaround (base64 payload + `fab api -X post .../updateDefinition`), not `fab import` again.

- [ ] **Step 6: Run both notebooks**

```bash
fab job run "DP - Staging - Dev.Workspace/Build_Silver_WkCodeFl.Notebook" --timeout 300
fab job run "DP - Staging - Dev.Workspace/Build_Silver_WKCDPART.Notebook" --timeout 300
```
Expected: both `Completed`, no `failureReason`.

- [ ] **Step 7: Create the DP_Presentation-side shortcuts to the new Silver tables**

```bash
fab ln "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Tables/Silver_WkCodeFl.Shortcut" \
  --type oneLake \
  --target "../../DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/Silver_WkCodeFl"
fab ln "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse/Tables/Silver_WKCDPART.Shortcut" \
  --type oneLake \
  --target "../../DP - Staging - Dev.Workspace/DP_Staging.Lakehouse/Tables/Silver_WKCDPART"
```
This matches the exact real target pattern already confirmed this session on the existing `Silver_WkMechFl.Shortcut` (workspace `ab15d64d-c7ba-415d-9bcf-7feb1ef9b201`, lakehouse `876255e0-d462-4697-adc1-4a655f5bb101`) — the Gold notebooks in Task 4 read these via `spark.read.table(...)` in the `DP_Presentation` lakehouse context, same as every other Gold notebook reading a Silver source.

- [ ] **Step 8: Verify via DuckDB**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
staging = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables"

for t in ["Silver_WkCodeFl", "Silver_WKCDPART"]:
    r = con.execute(f"SELECT COUNT(*) FROM delta_scan('{staging}/{t}')").fetchone()
    print(f"{t}: {r[0]:,} rows")
```
Expected: matches the Bronze counts exactly (pure passthrough — `Silver_WkCodeFl` 575,887, `Silver_WKCDPART` 1,846, or whatever the real current counts are at execution time).

- [ ] **Step 9: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Build_Silver_WkCodeFl.Notebook/" "workspaces/DP - Staging - Dev/Build_Silver_WKCDPART.Notebook/"
git commit -m "Add Build_Silver_WkCodeFl and Build_Silver_WKCDPART notebooks

Pure passthrough Silver builds off new OneLake shortcuts into JD's
Bronze mirror - both raw sources needed for the Job Code Parts
Advisor migration. No transformation logic; the original production
dataflows did their column selection directly in ODBC SQL, not at
a Silver-equivalent layer.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 4: Build `Build_Gold_JobCodes.Notebook` and `Build_Gold_WkcdPart.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook/.platform`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_WkcdPart.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_WkcdPart.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

**Depends on Task 3** — reads `Silver_WkCodeFl`/`Silver_WKCDPART` via their new `DP_Presentation`-side shortcuts.

- [ ] **Step 1: Write `Build_Gold_JobCodes.Notebook`**

Create `workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook/notebook-content.py`:

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

# Build_Gold_JobCodes
# Purpose: Reproduce production's dim_JobCodes (plural - a factory
# job-code master file with sales/hours stats, NOT the same table as the
# already-built dim_JobCode singular business-categorization dimension)
# per df_Dim_WkCodeFl.Dataflow in LH_Master_Data, part of the Job Code
# Parts Advisor migration (2026-09-23).
#
# SOURCE: Silver_WkCodeFl (already shortcut/built in DP_Presentation).
#
# GRAIN: One row per full job code variant (JobCode). Multiple rows share
# the same FactoryCode (one canonical code -> many branch/model variants).
#
# Faithful port of the original dataflow's column selection - no bugs
# found in it, nothing to fix. The original kept a ModifiedDate >=
# 2023-01-01 date-scope filter for its own incremental-refresh reasons;
# kept here as a plain filter for parity, even though this notebook does
# a full overwrite each run like every other Gold notebook in this
# project (not a true incremental fetch). No filter on FactoryCode
# nullability - the original dataflow's own header note about filtering
# WHERE FactoryCode IS NOT NULL is guidance for report/DAX consumers, not
# baked into the ETL - confirmed via direct read, all rows are kept here
# too.

print("=" * 80)
print("BUILD_GOLD_JOBCODES")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

# STEP 1: date-scope filter, matching the original's ModifiedDate >= 2023-01-01.
source = spark.read.table("Silver_WkCodeFl")
scoped = source.filter(F.col("ModifiedDate") >= F.lit("2023-01-01 00:00:00"))
print(f"WkCodeFl rows with ModifiedDate >= 2023-01-01: {scoped.count():,}")

# STEP 2: column selection and rename, matching the original SQL exactly.
dim_job_codes = scoped.select(
    F.col("CODE").cast("string").alias("JobCode"),
    F.col("FACTORY_CODE").cast("string").alias("FactoryCode"),
    F.col("DESCRIPTION").cast("string").alias("Description"),
    F.col("PART_BRANCH").cast("string").alias("Branch"),
    F.col("EST_HOURS").cast("double").alias("EstHours"),
    F.col("SALE_MTD_QTY").cast("double").alias("SaleMTDQty"),
    F.col("SALE_YTD_QTY").cast("double").alias("SaleYTDQty"),
    F.col("Make").cast("string").alias("Make"),
    F.col("Model").cast("string").alias("Model"),
    F.col("Work_Cat").cast("string").alias("WorkCategory"),
    F.col("SERVICE_TYPE").cast("string").alias("ServiceType"),
    F.col("CreationDate").cast("timestamp").alias("CreationDate"),
    F.col("ModifiedDate").cast("timestamp").alias("ModifiedDate"),
)

row_count = dim_job_codes.count()
print(f"dim_JobCodes rows: {row_count:,}")

dim_job_codes.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/dim_JobCodes")
print("Gold build complete: dim_JobCodes written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/dim_JobCodes` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

factory_code_check = spark.sql("""
    SELECT
        SUM(CASE WHEN FactoryCode IS NULL THEN 1 ELSE 0 END) AS null_factory_code,
        COUNT(DISTINCT FactoryCode) AS distinct_factory_codes,
        COUNT(DISTINCT JobCode) AS distinct_job_codes
    FROM delta.`Tables/dim_JobCodes`
""").toPandas()
print("\nFactoryCode coverage (null_factory_code is expected > 0, per the original's own note about custom/legacy codes):")
print(factory_code_check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write `Build_Gold_JobCodes.Notebook`'s `.platform` file**

Generate a real v4 UUID for `logicalId`. Create `workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook/.platform`:
```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_JobCodes"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<the generated guid>"
  }
}
```

- [ ] **Step 3: Write `Build_Gold_WkcdPart.Notebook`**

Create `workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_WkcdPart.Notebook/notebook-content.py`:

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

# Build_Gold_WkcdPart
# Purpose: Reproduce production's dim_WkcdPart per df_Dim_WKCDPART.Dataflow
# in LH_Master_Data, part of the Job Code Parts Advisor migration
# (2026-09-23).
#
# SOURCE: Silver_WKCDPART (already shortcut/built in DP_Presentation).
#
# GRAIN: One row per JobCode x PartNumber "official template" assignment -
# what the source system thinks should be on a work order for a given job
# code. Used as the gap-analysis baseline vs. actual historical frequency
# (Fact_JobCodePartFrequency).
#
# Faithful port of the original dataflow's column selection - no bugs
# found in it, nothing to fix. Full refresh, no filter - matches the
# original exactly (small ~1,800-row table, no incremental logic in
# production either).

print("=" * 80)
print("BUILD_GOLD_WKCDPART")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

# STEP 1: column selection and rename, matching the original SQL exactly.
source = spark.read.table("Silver_WKCDPART")
dim_wkcd_part = source.select(
    F.col("JOB_CODE").cast("string").alias("JobCode"),
    F.col("FRANCHISE").cast("string").alias("Franchise"),
    F.col("PART_NUMBER").cast("string").alias("PartNumber"),
    F.col("QTY").cast("double").alias("Qty"),
    F.col("value").cast("double").alias("Value"),
    F.col("Part_Freq").cast("double").alias("PartFreq"),
    F.col("CreationDate").cast("timestamp").alias("CreationDate"),
    F.col("ModifiedDate").cast("timestamp").alias("ModifiedDate"),
)

row_count = dim_wkcd_part.count()
print(f"dim_WkcdPart rows: {row_count:,}")

dim_wkcd_part.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/dim_WkcdPart")
print("Gold build complete: dim_WkcdPart written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/dim_WkcdPart` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

coverage_check = spark.sql("""
    SELECT
        COUNT(DISTINCT JobCode) AS distinct_job_codes,
        SUM(CASE WHEN PartFreq IS NULL THEN 1 ELSE 0 END) AS null_part_freq
    FROM delta.`Tables/dim_WkcdPart`
""").toPandas()
print("\nCoverage check (expect ~858 distinct job codes per production's own documented figure; null_part_freq expected mostly-null per the original's own note that Part_Freq is largely unreliable):")
print(coverage_check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Write `Build_Gold_WkcdPart.Notebook`'s `.platform` file**

Same pattern as Step 2, `displayName: "Build_Gold_WkcdPart"`, a new generated GUID.

- [ ] **Step 5: Import both to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_JobCodes.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook" --format .py -f
fab import "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_WkcdPart.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_WkcdPart.Notebook" --format .py -f
```
Both are fresh CREATEs. If either needs a content fix after this, use the raw API workaround, not `fab import` again.

- [ ] **Step 6: Get the real notebookIds and run both**

```bash
fab get "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_JobCodes.Notebook" -q "id"
fab get "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_WkcdPart.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_JobCodes.Notebook" --timeout 300
fab job run "DP - Presentation - Dev.Workspace/Dimensions.Folder/Build_Gold_WkcdPart.Notebook" --timeout 300
```
Expected: both `Completed`, no `failureReason`. Record both real notebookIds for Step 8.

- [ ] **Step 7: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```
Expected: HTTP 200, both `dim_JobCodes` and `dim_WkcdPart` listed with `status: "Success"`.

- [ ] **Step 8: Register both in `deploy/dp_backend_scope.json`**

Read the file first to match its exact existing single-line-per-entry style, then insert 2 new entries for `Build_Gold_JobCodes` and `Build_Gold_WkcdPart` (tier=gold, cadence=daily) using the real notebookIds from Step 6, via precise Edit-tool text insertions. Validate afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 9: DuckDB verification against real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

lh_tables = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_tables = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, path in [("OLD", f"{lh_tables}/dim_JobCodes"), ("NEW", f"{dp_tables}/dim_JobCodes")]:
    r = con.execute(f"SELECT COUNT(*) AS rows, COUNT(DISTINCT FactoryCode) AS distinct_factory_codes FROM delta_scan('{path}')").fetchone()
    print(f"{label} dim_JobCodes: rows={r[0]:,}, distinct_factory_codes={r[1]:,}")

for label, path in [("OLD", f"{lh_tables}/dim_WkcdPart"), ("NEW", f"{dp_tables}/dim_WkcdPart")]:
    r = con.execute(f"SELECT COUNT(*) AS rows, COUNT(DISTINCT JobCode) AS distinct_job_codes FROM delta_scan('{path}')").fetchone()
    print(f"{label} dim_WkcdPart: rows={r[0]:,}, distinct_job_codes={r[1]:,}")
```
Report the real numbers — don't assume a match. Both should be close given both source from the same live Bronze mirror data.

- [ ] **Step 10: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_JobCodes.Notebook/" "workspaces/DP - Presentation - Dev/Dimensions/Build_Gold_WkcdPart.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_JobCodes and Build_Gold_WkcdPart notebooks

Faithful ports of df_Dim_WkCodeFl.Dataflow and df_Dim_WKCDPART.Dataflow's
real column selection - no business logic to fix in either. Resolves
the long-open catalog question: dim_JobCodes (plural) is a genuinely
different table from the already-built dim_JobCode (singular), not a
stale reference.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-23):** Completed by implementer subagent, DONE_WITH_CONCERNS. Both notebooks ran clean (notebookIds `b0d026f6-df7b-4cc2-b6cf-f0846e366d81` for `Build_Gold_JobCodes`, `b9de2812-7db0-40de-8f7b-d2f627dd5c3f` for `Build_Gold_WkcdPart`), registered, committed as `a7ce9a48`.

`dim_WkcdPart` verified with an **exact match** against production (1,846 rows, 866 distinct job codes both sides) — confirms the port methodology is correct.

`dim_JobCodes` showed a large row-count difference (OLD 75,563 rows vs. NEW 575,887 rows) — investigated and confirmed **not a bug**: production's `dim_JobCodes` is stale (last refreshed ~Jun 2026, `ModifiedDate` range Jan–Jun 2026), while the new build reflects the live current Bronze mirror (`ModifiedDate` range Aug–Sep 2026, entirely within the last ~26 days). The two windows don't overlap, so this is the same "live source vs. stale snapshot" comparison pattern already documented in project memory (`feedback_verification_live_source_vs_snapshot`), not a defect in the column-rename logic. Secondary finding worth keeping in mind for any future incremental-refresh work on this table: `WkCodeFl`'s `ModifiedDate` appears to reflect a rolling extraction/touch date across the whole table rather than genuine per-record business-modification timestamps (the entire 575,887-row Bronze table falls within that same narrow ~26-day window) — not actionable for this faithful-port task, just a data-characteristic note.

---

### Task 5: Report-layer exhaustive real-usage audit

**Files:** none — investigation only. Findings get documented directly in this plan before Task 6 proceeds (same discipline as every prior report this project).

- [ ] **Step 1: Audit all 7 real data tables**

For `dim_JobCodes`, `dim_WkcdPart`, `Fact_JobCodePartFrequency`, `Fact_JobCodePartFrequency_Branch`, `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`: run `pbir fields list "Job Code Parts Advisor.Report"`, grep every column against `_Measures.tmdl`'s DAX bodies AND against the 2 calculated tables' own DAX (`Fact_GapAnalysis.tmdl`, `Fact_BranchAnalysis.tmdl` — these contain the 4 real `LOOKUPVALUE(dim_JobCodes[...])` calls already confirmed this session), and check every `.bookmark.json` file under `workspaces/RP - Dev/Job Code Parts Advisor.Report/definition/bookmarks/` for filter references (bookmark-only usage is a confirmed real blind spot from prior reports this project).

- [ ] **Step 2: Confirm the 4 `LOOKUPVALUE(dim_JobCodes[...])` calls resolve to real columns**

Cross-check exactly which `dim_JobCodes` columns the 4 `LOOKUPVALUE` calls in `Fact_GapAnalysis.tmdl`/`Fact_BranchAnalysis.tmdl` reference against the real 13-column `dim_JobCodes` build from Task 4 (`JobCode, FactoryCode, Description, Branch, EstHours, SaleMTDQty, SaleYTDQty, Make, Model, WorkCategory, ServiceType, CreationDate, ModifiedDate`). All 4 should resolve — this was a design-time check already, this step re-confirms it against the actual built table, not just the design intent.

- [ ] **Step 3: Document findings**

Add a "### Task 5 Findings" section to this plan file recording, for each of the 7 tables: confirmed-used columns (keep), confident-unused columns (trim), and ambiguous columns (leave as-is, note why). Check every table for `sortByColumn` properties before trimming.

---

### Task 6: Report-layer repoint and trim

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/dim_JobCodes.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/dim_WkcdPart.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/Fact_JobCodePartFrequency.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/Fact_JobCodePartFrequency_Branch.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/dim_Parts.tmdl`

**Depends on Task 5's findings.**

- [ ] **Step 1: Swap connection strings on all 7 tables**

Replace every occurrence in each `partition <table> = m` block:
```
Old: Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")
New: Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")
```

- [ ] **Step 2: Check `dim_DateTable` for the established today-relative-column risk**

Even though not flagged as a known issue for this report specifically, cross-check every DAX-confirmed-used `dim_DateTable` column (from Task 5's findings) against the real 14-column `DP_Presentation.dim_DateTable` schema (`DateKey, Date, Year, Quarter, Month, Day, WeekOfYear, DayOfWeek, MonthName, MonthNameShort, MonthYear, SortableMonthYear, QuarterYear, IsWeekend`) before finalizing the trim — this exact bug class has recurred on 4 of the last 5 reports migrated this project. Restore any genuinely-used missing column as a DAX calculated column sourced from `'Data Refresh'[Date]` if found, following the established pattern from prior reports' `dim_DateTable.tmdl` restorations.

- [ ] **Step 3: Apply trims per Task 5's findings**

Apply the confirmed-unused column removals to each of the 7 tables per Task 5's documented findings, verifying column-for-column against those findings after editing.

- [ ] **Step 4: Verify no stray connection strings remain**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/"
```
Expected: zero matches.

- [ ] **Step 5: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Job Code Parts Advisor.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Job Code Parts Advisor to DP_Presentation

All 7 data tables repointed. Trimmed per the Task 5 exhaustive
audit, including confirming the 4 LOOKUPVALUE(dim_JobCodes[...])
calls in Fact_GapAnalysis/Fact_BranchAnalysis resolve against the
new backend's real columns. Any genuinely-used dim_DateTable
today-relative column restored as a DAX calculated column if found.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 7: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Job Code Parts Advisor.pbip`

- [ ] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "Job Code"
```
Expected: only `Job Code Parts Advisor.Report` and `Job Code Parts Advisor.SemanticModel` — no `.pbip`.

- [ ] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Job Code Parts Advisor.Report"
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
git add "workspaces/RP - Dev/Job Code Parts Advisor.pbip"
git commit -m "Add Job Code Parts Advisor.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 8: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 1-7's commits.

- [ ] **Step 2: Open Job Code Parts Advisor from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean Task 5's audit missed a real usage, or a `dim_DateTable` today-relative column wasn't caught) or errors on the `Fact_GapAnalysis`/`Fact_BranchAnalysis` calculated tables specifically (would mean the `LOOKUPVALUE(dim_JobCodes[...])` calls don't resolve against the new build). Report back for investigation rather than assuming.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live production version — specifically the gap-analysis visuals (comparing `Fact_JobCodePartFrequency` against `dim_WkcdPart`'s official template), to confirm the new Gold tables produce equivalent output.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 9).

---

### Task 9: Post-publish verification and catalog update

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
    "dim_JobCodes", "dim_WkcdPart", "Fact_JobCodePartFrequency",
    "Fact_JobCodePartFrequency_Branch", "dim_BranchLocation", "dim_DateTable", "dim_Parts",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark Job Code Parts Advisor complete in `docs/architecture/report-migration-catalog.md`, matching the completion-note pattern already used for every prior completed report. Note this resolves the long-open `dim_JobCodes` vs `dim_JobCode` question, and note this is the first of 2 reports in this pair (Labor Performance still to come).

---

## Self-Review Notes

**Spec coverage:** The design spec's 5 architecture sections (3.1 registration fix, 3.2 Silver notebooks, 3.3 `Build_Gold_JobCodes`, 3.4 `Build_Gold_WkcdPart`, 3.5 report-layer repoint) map to Tasks 1, 3, 4, and 6 respectively (Task 2 — shortcut creation — is the spec's implicit prerequisite for 3.2, made explicit as its own task since it's Fabric-side metadata work distinct from writing notebook code). The spec's verification plan maps to Task 1 Step 5, Task 4 Step 9, and Task 9 Step 1. The spec's explicit non-goals (no change to production dataflows/existing fact notebooks, no `Fact_GapAnalysis`/`Fact_BranchAnalysis`/`dim_FrequencyFilter` work) are respected throughout.

**Placeholder scan:** Task 5's findings feed Task 6 Steps 2-3 — a real sequential dependency, matching the pattern proven on every prior report this project. Task 1/4/9's DuckDB verification steps explicitly call for reporting real run-time numbers rather than guessing them now.

**Type consistency:** `dim_JobCodes`'s 13-column schema (`JobCode, FactoryCode, Description, Branch, EstHours, SaleMTDQty, SaleYTDQty, Make, Model, WorkCategory, ServiceType, CreationDate, ModifiedDate`) is referenced identically in the Context section, Task 4 Step 1's notebook code, and Task 6 Step 2's cross-check note. `dim_WkcdPart`'s 8-column schema (`JobCode, Franchise, PartNumber, Qty, Value, PartFreq, CreationDate, ModifiedDate`) is likewise consistent between the Context section and Task 4 Step 3's notebook code. The 2 existing fact notebooks' real column schemas (`Fact_JobCodePartFrequency`: JobCode/PartNumber/TimesWithPart/TotalOrdersWithJobCode/FrequencyPct; `Fact_JobCodePartFrequency_Branch`: adds Branch) are used consistently in Task 1's DuckDB checks and Task 9's final verification.
