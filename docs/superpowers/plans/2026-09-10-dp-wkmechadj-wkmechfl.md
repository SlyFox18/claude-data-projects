# DP WKMECHADJ and WKMECHFL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `WKMECHADJ` and `WKMECHFL` into the `DP` backend as OneLake shortcuts plus Silver notebooks — the two new raw sources needed to fully unblock the Technician-family (Category B) rebuild, discovered this session by getting the real SQL Anywhere view definitions directly from Brian via SQL Central.

**Architecture:** Same shortcut + Silver notebook pattern as every prior table in this backend. **This plan is raw + Silver only** — no joins, no aggregation, no business logic, no Gold-layer Fact table. Brian's own scoping: "let's stay focused on getting the raw data and silver tables build, noting all of these findings along the way so when we get to the gold fact table and report rework we will have this information."

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Why these two tables (read before building)

Brian pulled the real `CREATE/ALTER VIEW` SQL for all 5 Technician-family source-side views directly from SQL Central this session — fully decoding Category B of the raw-sources catalog, previously the most opaque, undecided piece of the whole migration effort. Full writeup (the actual Efficiency formula, complete lineage for all 5 views, a real `BranchOperational` simplification opportunity found along the way, and Brian's own stated intent to revisit the whole Labor Performance report design once this reaches Gold) lives in project memory: `project_labor_performance_technician_views_resolved.md`.

The short version: every input the eventual Gold rebuild needs already traces back to a table in JD Bronze — `Contact` (have, `Silver_Contact`, batch 1), `WkMechWk` (have, `Silver_WkMechWk`, batch 2), and `WkOthSub` (have, `Silver_WkOthSub`, batch 2) — except for two new ones, both confirmed present in JD Bronze this session (**no direct-ODBC pull needed for anything in this category**, unlike Category C tables):

- **`WKMECHADJ`** — the real source behind the `TechnicianAttendance` view, and part of `TechnicianPunchedTime`'s join-gate logic (only counts labor on days a technician has a valid same-day attendance record).
- **`WKMECHFL`** — the real source behind the `TechnicianInformation` view, which the `Technician` view routes through.

**This plan brings both in as plain Silver tables — nothing more.** No Efficiency formula, no join/aggregation logic from any of the 5 views, no Gold Fact table, no report work. That's all deliberately separate, future work.

---

## Scope

| # | Bronze shortcut name | Silver table | Notes |
|---|---|---|---|
| 1 | `WKMECHADJ` | `Silver_WkMechAdj` | Brand-new raw source — no prior `LH_Master_Data` dataflow ever pulled it directly. Narrow (12 columns) — bring in the whole table |
| 2 | `WKMECHFL` | `Silver_WkMechFl` | Brand-new raw source. Wide (38 columns) — curated to the 5 columns the real `TechnicianInformation` view proved necessary. One real casing correction (`Team_Code`→`TEAM_CODE`). Deliberately does NOT apply the view's `IsTerminated` boolean-conversion logic — that's a real business interpretation, kept out of Silver |

**Neither table ever had its own `LH_Master_Data` dataflow** — both were only ever consumed indirectly through the source-side views. That means there's no old dataflow column contract to replicate (unlike every other table migrated this session); the column choices below come from what the real view SQL proved necessary, cross-checked against the live bronze schema.

**Explicitly out of scope:** the Efficiency formula, any of the 5 views' real join/aggregation/grouping logic, any Gold-layer Fact table, any report work, any refresh schedule. Dev tier only, Silver layer only, manual trigger only.

---

### Task 1: Brian creates the 2 OneLake shortcuts

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the first shortcut (`WKMECHADJ`) — full steps**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `WKMECHADJ`
7. Keep the destination name as `WKMECHADJ` (don't rename)
8. **Create**

- [ ] **Step 2: Repeat for `WKMECHFL`**

Same steps as above — select `WKMECHFL` from `JD_EquipRDB_Production_Bronze` → `Tables`, keep the destination name identical to the source name.

- [ ] **Step 3: Confirm both shortcuts appear**

In `DP_Staging` → `Tables`, confirm `WKMECHADJ` and `WKMECHFL` are both listed. Report back once done.

---

### Task 2: Independently verify the 2 bronze shortcuts

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_wkmechadj_wkmechfl.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP WKMECHADJ AND WKMECHFL - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms each of the 2 new OneLake shortcuts in DP_Staging resolves to the
exact same row count as reading the same table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch here means the shortcut itself
is broken (wrong table selected, stale metadata), not a data problem.

Run manually after Brian creates both shortcuts (plan Task 1).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

JD_BRONZE_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"
JD_BRONZE_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"
jd_base = f"abfss://{JD_BRONZE_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_BRONZE_LH_ID}/Tables"

TABLES = [
    "WKMECHADJ",
    "WKMECHFL",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Table':<20} {'DP_Staging shortcut':>20} {'JD Bronze direct':>20} {'Match':>10}")
print("=" * 90)

all_match = True
for t in TABLES:
    dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{t}')").fetchone()[0]
    jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/{t}')").fetchone()[0]
    match = dp_count == jd_count
    all_match = all_match and match
    print(f"{t:<20} {dp_count:>20,} {jd_count:>20,} {'OK' if match else 'MISMATCH':>10}")

print("=" * 90)
print(f"Both shortcuts match their JD Bronze source exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_wkmechadj_wkmechfl.py
```

Expected: both rows show `OK`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_wkmechadj_wkmechfl.py
git commit -m "Add bronze shortcut verification for WKMECHADJ and WKMECHFL

Confirms both new DP_Staging OneLake shortcuts resolve to the exact
same row count as JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_WkMechAdj.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechAdj.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechAdj.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkMechAdj"
  },
  "config": {
    "version": "2.0",
    "logicalId": "2907b61e-dc8e-4754-85ef-c96c24a1f92f"
  }
}
```

- [ ] **Step 2: Create the notebook content**

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

# Build_Silver_WkMechAdj
# Purpose: RAW + SILVER ONLY - part of the Technician-family (Category B)
# rebuild groundwork, per Brian's own explicit scoping 2026-09-10 ("let's
# stay focused on getting the raw data and silver tables build"). This
# notebook does NOT implement any Gold-layer business logic - see
# project memory `project_labor_performance_technician_views_resolved.md`
# for the full context (the real Efficiency formula, all 5 Technician-
# family view definitions pulled directly from SQL Anywhere via SQL
# Central, and what's still deferred).
#
# WKMECHADJ is the real source behind the TechnicianAttendance view
# (SUM(hours) grouped by branch/tech/year/month) and part of
# TechnicianPunchedTime's join-gate logic (only counts WkMechWk labor on
# days a technician has a valid same-day WKMECHADJ record). Neither of
# those views' actual logic is implemented here - this notebook is a
# plain select + rename, nothing more.
#
# No prior LH_Master_Data dataflow ever pulled this table directly (it
# was only ever consumed indirectly through the views), so there's no
# old dataflow column contract to replicate - this is a brand-new raw
# source. It's narrow enough (12 columns total) that the whole table is
# brought in rather than curated to a subset.
#
# Brings in FULL history, no date filter - matching this backend's
# established default since raw sources batch 2 (date-scoping is a
# Gold-layer decision).
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKMECHADJ")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WKMECHADJ")
bronze_count = bronze.count()
print(f"Bronze WKMECHADJ rows: {bronze_count:,}")

silver = bronze.select(
    F.col("TECH_CODE").alias("TechCode"),
    F.col("LINE_NO").alias("LineNumber"),
    F.col("ADJ_DATE").alias("AdjustmentDate"),
    F.col("TYPE").alias("Type"),
    F.col("PAID").alias("Paid"),
    F.col("HOURS").alias("Hours"),
    F.col("START_TIME").alias("StartTime"),
    F.col("END_TIME").alias("EndTime"),
    F.col("TECH_BRANCH").alias("Branch"),
    F.col("CreationDate").alias("CreationDate"),
    F.col("ModifiedDate").alias("ModifiedDate"),
    F.col("GUID_SO").alias("GuidSO"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkMechAdj")
print("Silver build complete: Silver_WkMechAdj written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkMechAdj` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechAdj.Notebook"
git commit -m "Add Build_Silver_WkMechAdj notebook

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Build `Build_Silver_WkMechFl.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechFl.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechFl.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkMechFl"
  },
  "config": {
    "version": "2.0",
    "logicalId": "f1586e80-51cb-4967-9714-46e40a56388b"
  }
}
```

- [ ] **Step 2: Create the notebook content**

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

# Build_Silver_WkMechFl
# Purpose: RAW + SILVER ONLY - part of the Technician-family (Category B)
# rebuild groundwork, per Brian's own explicit scoping 2026-09-10 ("let's
# stay focused on getting the raw data and silver tables build"). This
# notebook does NOT implement any Gold-layer business logic - see
# project memory `project_labor_performance_technician_views_resolved.md`
# for the full context (the real Efficiency formula, all 5 Technician-
# family view definitions pulled directly from SQL Anywhere via SQL
# Central, and what's still deferred).
#
# WKMECHFL is the real source behind the TechnicianInformation view,
# which the Technician view routes through (joined to Contact for the
# name). That join and every other view's real logic is NOT implemented
# here - this notebook is a plain select + rename, nothing more.
#
# No prior LH_Master_Data dataflow ever pulled this table directly, so
# there's no old dataflow column contract to replicate - this is a
# brand-new raw source. WKMECHFL is WIDE (38 columns total) - only the 5
# columns the real TechnicianInformation view proved necessary are
# selected here, matching this backend's established discipline of not
# expanding scope beyond what's proven needed (same discipline already
# applied to WKRODESC's unused DETAIL column in an earlier plan). The
# bronze shortcut itself stays full-fidelity regardless - all 38 columns
# remain directly queryable - so nothing is permanently lost by curating
# Silver narrowly; if the eventual Gold-layer Labor Performance rework
# wants more of these columns later, they're one query away.
#
# Column casing note: the view's own SQL text references Team_Code, but
# the live bronze schema stores it as TEAM_CODE (confirmed via a live
# schema query this session).
#
# Real design decision: the TechnicianInformation view applies
# CASE WHEN Is_Terminated = 'N' THEN 0 ELSE 1 END to derive a boolean-
# style IsTerminated flag - a real business interpretation (deciding any
# non-'N' value, including nulls, means "terminated"), not a faithful
# passthrough. That CASE logic is deliberately NOT applied here - this
# notebook carries the raw is_terminated value through unconverted into
# the IsTerminated column, exactly as found in the source. Whoever
# eventually builds the Gold-layer equivalent can apply that
# interpretation there, with full visibility into the raw values first -
# same principle already applied to every other business-rule filter
# deferred this session (InHist_PmManage's Franchise='D',
# WKRODESC's LINE_NO=1).
#
# Brings in FULL history, no date filter - matching this backend's
# established default since raw sources batch 2.
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKMECHFL")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WKMECHFL")
bronze_count = bronze.count()
print(f"Bronze WKMECHFL rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Code").alias("TechnicianCode"),
    F.col("BRANCH").alias("Branch"),
    F.col("TEAM_CODE").alias("TeamCode"),
    F.col("is_terminated").alias("IsTerminated"),
    F.col("HOUR_COST_RATE").alias("HourCostRate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkMechFl")
print("Silver build complete: Silver_WkMechFl written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkMechFl` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

is_terminated_breakdown = spark.sql("""
    SELECT IsTerminated, COUNT(*) AS RowCount
    FROM delta.`Tables/Silver_WkMechFl`
    GROUP BY IsTerminated
    ORDER BY RowCount DESC
""").toPandas()
print("\nIsTerminated raw value breakdown (unconverted - see header comment for why):")
print(is_terminated_breakdown.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechFl.Notebook"
git commit -m "Add Build_Silver_WkMechFl notebook

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 5: Brian syncs Dev and runs both notebooks

**Files:** none (Fabric portal action)

- [ ] **Step 1: Sync the workspace**

`DP - Staging - Dev` → Source control → **Update all**.

- [ ] **Step 2: Run each notebook**

Open and **Run all** cells on:
- `Build_Silver_WkMechAdj`
- `Build_Silver_WkMechFl`

- [ ] **Step 3: Report back each notebook's own output**

For both: bronze/Silver row counts and the sample rows. For `Build_Silver_WkMechFl` specifically, also report the `IsTerminated` raw-value breakdown (confirms the real distinct values in the source, useful groundwork for whoever eventually builds the Gold-layer interpretation). If either assertion fails or a write throws an error, stop and report the full error rather than re-running blindly.

---

### Task 6: Independently verify both Silver tables

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_wkmechadj_wkmechfl.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP WKMECHADJ AND WKMECHFL - SILVER VERIFICATION
============================================================================
Independent check of the 2 Silver tables built in this plan - confirms
each Silver table's row count matches its bronze shortcut exactly (both
are pure select/rename, no filtering).

Run manually after Brian runs both notebooks (plan Task 5).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name)
TABLE_PAIRS = [
    ("WKMECHADJ", "Silver_WkMechAdj"),
    ("WKMECHFL", "Silver_WkMechFl"),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Bronze':<20} {'Silver':<20} {'Bronze rows':>15} {'Silver rows':>15} {'Match':>8}")
print("=" * 90)

all_match = True
for bronze_name, silver_name in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    match = bronze_count == silver_count
    all_match = all_match and match
    print(f"{bronze_name:<20} {silver_name:<20} {bronze_count:>15,} {silver_count:>15,} {'OK' if match else 'MISMATCH':>8}")

print("=" * 90)
print(f"Both Silver tables match their bronze shortcut exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_wkmechadj_wkmechfl.py
```

Expected: both rows show `OK`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_wkmechadj_wkmechfl.py
git commit -m "Add Silver verification for WKMECHADJ and WKMECHFL

Confirms both new Silver tables match their bronze shortcut row
count exactly (pure select/rename, no filtering).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 7: Update reference docs

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`

- [ ] **Step 1: Add the new tables to `DP_Staging`'s Lakehouses table**

In `docs/architecture/data-platform-workspaces.md`, find the `DP_Staging` lakehouse row and add the 2 new shortcuts and 2 new Silver tables to its listed contents, pointing to the new section below.

- [ ] **Step 2: Add a new section**

Add a `## WKMECHADJ and WKMECHFL (2026-09-10) — the two missing pieces for the Technician-family rebuild` section (after the "InHist_PmManage and WKRODESC" section) covering:
- Why these two specifically — summarize the SQL-Central view-definition investigation (point to `project_labor_performance_technician_views_resolved.md` in project memory for the full formula derivation rather than duplicating it here)
- The column curation decisions: `WKMECHADJ` brought in whole (narrow, 12 columns), `WKMECHFL` curated to the 5 columns the real view proved necessary (wide, 38 columns total)
- The `Team_Code`→`TEAM_CODE` casing correction
- The deliberately-not-applied `IsTerminated` CASE logic and why (Gold-layer interpretation, not a Silver concern)
- Verification results (both scripts, all passing)
- An explicit, prominent note: **this is raw+Silver only** — the actual Gold-layer Technician-family Fact rebuild, the Efficiency formula implementation, and any Labor Performance report rework are deliberately separate, future pieces of work, not started here

- [ ] **Step 3: Add a pointer note in the catalog doc's Category B section**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`'s Category B section, add a short note: both `WKMECHADJ` and `WKMECHFL` are now migrated (raw+Silver) as of 2026-09-10 — see the new section in `data-platform-workspaces.md` and `project_labor_performance_technician_views_resolved.md` in project memory for the full Technician-family investigation. Don't try to add these two as rows in the Category A/B/C table itself — neither ever had its own `LH_Master_Data` dataflow, so they don't fit that table's row structure; a pointer note is enough for a future reader to find the right place.

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document WKMECHADJ and WKMECHFL migration

Both tables moved onto OneLake shortcuts + Silver notebooks - the two
new raw sources needed to fully unblock the Technician-family
(Category B) rebuild, discovered this session by getting the real
SQL Anywhere view definitions directly from Brian via SQL Central.
WKMECHADJ brought in whole (narrow, 12 columns); WKMECHFL curated to
the 5 columns the real TechnicianInformation view proved necessary
(wide, 38 columns total) - deliberately does not apply the view's
IsTerminated boolean-conversion logic, kept as a raw passthrough.

This is raw+Silver only - the Gold-layer Technician-family Fact
rebuild, the Efficiency formula, and any Labor Performance report
rework remain deliberately deferred, per Brian's own scoping.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 8: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into the Gold-layer Technician-family Fact rebuild, the Efficiency formula, the Labor Performance report rework, or the `BranchOperational` simplification opportunity as part of this plan** — each of those is its own future decision, not implied by completing this one.
