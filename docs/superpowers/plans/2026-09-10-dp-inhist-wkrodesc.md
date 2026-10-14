# DP InHist_PmManage and WKRODESC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the last 2 Category A tables that needed more thought — `InHist_PmManage` and `WKRODESC` — onto the `DP` backend as OneLake shortcuts plus Silver notebooks, bringing in full unfiltered data despite both old dataflows having real business-rule filters.

**Architecture:** Same shortcut + Silver notebook pattern as every prior table in this backend. Both old dataflows filtered on something more meaningful than a date window (`Franchise = 'D'`, `LINE_NO = 1`) — investigated directly this session, and both filters turned out to have a real, confirmed cost, so neither is replicated.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Why neither filter is replicated (read before building)

**`InHist_PmManage`'s `Franchise = 'D'`** is not incidental — it's genuinely tied to the "First Pass Fill" report's real purpose (John Deere equipment specifically), and Franchise D really is the dominant scope: 1,105,419 of 1,328,067 rows (83.2%). But a lowercase `'d'` variant (212 rows) sits right next to uppercase `'D'` in the live data — almost certainly the same franchise with a data-entry casing inconsistency, which the old dataflow's exact-match `= 'D'` filter would have silently excluded. The remaining 16.8% spans 43 other franchise codes, some down to single-digit row counts.

**`WKRODESC`'s `WHERE LINE_NO = 1`** is a grain-narrowing rule ("primary job per work order"), not a date filter, and it has two real, confirmed costs: 10 work orders have no `LINE_NO = 1` row at all (716,698 distinct ROs, only 716,688 have a line-1 row) — a report trusting "every RO has a primary job" silently gets zero rows for those 10; and `LINE_NO` values of `1000001`/`1000002` account for 426,921 rows (26% of the whole 1,623,053-row table) — not organic sequential numbers, an unexplained offset pattern the old filter silently drops without anyone having investigated what it represents.

Both filters are real business logic, unlike the pure date-range windows on every other table migrated so far — but both also have a confirmed cost, and both encode a business-scoping decision rather than a data-quality guard (unlike `WarClaim`'s or `Invoice`'s `IS NOT NULL` filters, which were kept). Consistent with every other business-shaping call already deferred this session: **bring in everything at Silver, let Gold decide.** The eventual First Pass Fill Gold/Fact table can still scope to Franchise D there. A future `WKRODESC` Fact table consumer can decide whether it wants "primary job only" or something else — Silver doesn't decide for it, and nothing gets silently thrown away before anyone understands what the `1000001`/`1000002` lines actually are.

**New standing practice, continued:** both notebooks set
```python
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
```
at the top, matching every notebook in this backend since raw sources batch 2.

---

## Scope

| # | Bronze shortcut name | Old dataflow | Silver table | Notes |
|---|---|---|---|---|
| 1 | `InHist_PmManage` | `df_InHist_PmManage_Raw` | `Silver_InHist_PmManage` | 1 real casing correction (`PART_NO`→`Part_No`); `Franchise = 'D'` not replicated |
| 2 | `WKRODESC` | `df_WKRODESC_Raw` | `Silver_WkRoDesc` | No casing corrections; `LINE_NO = 1` not replicated |

**Explicitly out of scope:** the InMaster group (filed separately, see `project_nonjd_parts_order_tool_paused.md` in memory), Category B (Technician-family views) and Category C (tables genuinely excluded from JD's mirror) from the catalog doc. No report repointing, no gold-layer business logic (including NOT applying the Franchise D or `LINE_NO = 1` scoping — that's Gold's job if/when it's ever needed), no refresh schedule — Dev tier only, Silver layer only, manual trigger only.

**This closes out every Category A table in the original raw-sources catalog** except the InMaster group.

---

### Task 1: Brian creates the 2 OneLake shortcuts

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the first shortcut (`InHist_PmManage`) — full steps**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `InHist_PmManage`
7. Keep the destination name as `InHist_PmManage` (don't rename)
8. **Create**

- [ ] **Step 2: Repeat for `WKRODESC`**

Same steps as above — select `WKRODESC` from `JD_EquipRDB_Production_Bronze` → `Tables`, keep the destination name identical to the source name.

- [ ] **Step 3: Confirm both shortcuts appear**

In `DP_Staging` → `Tables`, confirm `InHist_PmManage` and `WKRODESC` are both listed. Report back once done.

---

### Task 2: Independently verify the 2 bronze shortcuts

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_inhist_wkrodesc.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INHIST_PMMANAGE AND WKRODESC - BRONZE SHORTCUT VERIFICATION
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
    "InHist_PmManage",
    "WKRODESC",
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
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_inhist_wkrodesc.py
```

Expected: both rows show `OK`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_inhist_wkrodesc.py
git commit -m "Add bronze shortcut verification for InHist_PmManage and WKRODESC

Confirms both new DP_Staging OneLake shortcuts resolve to the exact
same row count as JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_InHist_PmManage.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InHist_PmManage.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InHist_PmManage.Notebook/notebook-content.py`

- [ ] **Step 1: Generate a logical ID**

```bash
python -c "import uuid; print(uuid.uuid4())"
```

- [ ] **Step 2: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_InHist_PmManage"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<LOGICAL_ID from Step 1>"
  }
}
```

- [ ] **Step 3: Create the notebook content**

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

# Build_Silver_InHist_PmManage
# Purpose: Migrates InHist_PmManage off the old ODBC-based
# df_InHist_PmManage_Raw dataflow onto a OneLake shortcut of JD's own
# live mirror.
#
# Brings in FULL history AND ALL FRANCHISES - the old dataflow's
# Franchise = 'D' filter is deliberately NOT replicated. This was a real
# discussion, not a reflexive default: Franchise D genuinely is the
# dominant business scope for this table (1,105,419 of 1,328,067 rows,
# 83.2%, confirmed this session), tied to the real "First Pass Fill"
# report's actual purpose (John Deere equipment specifically). But a
# lowercase 'd' variant (212 rows) sits right next to uppercase 'D' in
# the live data - almost certainly the same franchise with a data-entry
# casing inconsistency, which the old exact-match = 'D' filter would have
# silently excluded. The remaining 16.8% spans 43 other franchise codes.
# Franchise-scoping is a business decision, not a data-quality guard -
# it belongs at Gold (the eventual First Pass Fill Gold/Fact table can
# scope to Franchise D there), matching every other business-shaping
# call already deferred in this backend (date windows on every other
# table, no partitioning on Invoice).
#
# The old dataflow's Period_Date range is also not replicated, for the
# same reason as every other table in this backend since raw sources
# batch 2 - date-scoping is a Gold-layer decision.
#
# Column casing note: the live JD Bronze schema stores PART_NO as
# mixed-case Part_No - the old dataflow's all-caps SQL text worked under
# SQL Anywhere's case-insensitive resolution, but this notebook uses the
# real live casing (confirmed via a live schema query this session).
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_INHIST_PMMANAGE")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("InHist_PmManage")
bronze_count = bronze.count()
print(f"Bronze InHist_PmManage rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Period_Date").alias("PeriodDate"),
    F.col("Branch").alias("Branch"),
    F.col("Franchise").alias("Franchise"),
    F.col("Part_No").alias("PartNumber"),
    F.col("Job_Code").alias("JobCode"),
    F.col("Job_Type").alias("JobType"),
    F.col("Stocked_Ind").alias("StockedIndicator"),
    F.col("Internal_FirstPass_Attempt_Cnt").alias("InternalFirstPassAttempts"),
    F.col("Internal_FirstPass_Success_Cnt").alias("InternalFirstPassSuccesses"),
    F.col("Internal_InTrfs_Success_Cnt").alias("InternalTransferSuccesses"),
    F.col("Internal_24Hour_Attempt_Cnt").alias("Internal24HourAttempts"),
    F.col("Internal_24Hour_Success_Cnt").alias("Internal24HourSuccesses"),
    F.col("Parts_FirstPass_Attempt_Cnt").alias("PartsFirstPassAttempts"),
    F.col("Parts_FirstPass_Success_Cnt").alias("PartsFirstPassSuccesses"),
    F.col("Parts_InTrfs_Success_Cnt").alias("PartsTransferSuccesses"),
    F.col("Parts_24Hour_Attempt_Cnt").alias("Parts24HourAttempts"),
    F.col("Parts_24Hour_Success_Cnt").alias("Parts24HourSuccesses"),
    F.col("Workshop_FirstPass_Attempt_Cnt").alias("WorkshopFirstPassAttempts"),
    F.col("Workshop_FirstPass_Success_Cnt").alias("WorkshopFirstPassSuccesses"),
    F.col("Workshop_InTrfs_Success_Cnt").alias("WorkshopTransferSuccesses"),
    F.col("Workshop_24Hour_Attempt_Cnt").alias("Workshop24HourAttempts"),
    F.col("Workshop_24Hour_Success_Cnt").alias("Workshop24HourSuccesses"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_InHist_PmManage")
print("Silver build complete: Silver_InHist_PmManage written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_InHist_PmManage` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

franchise_breakdown = spark.sql("""
    SELECT Franchise, COUNT(*) AS RowCount
    FROM delta.`Tables/Silver_InHist_PmManage`
    GROUP BY Franchise
    ORDER BY RowCount DESC
    LIMIT 10
""").toPandas()
print("\nFranchise breakdown (top 10 - confirms all franchises came through, not just 'D'):")
print(franchise_breakdown.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_InHist_PmManage.Notebook"
git commit -m "Add Build_Silver_InHist_PmManage notebook

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Build `Build_Silver_WkRoDesc.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoDesc.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoDesc.Notebook/notebook-content.py`

- [ ] **Step 1: Generate a logical ID**

```bash
python -c "import uuid; print(uuid.uuid4())"
```

- [ ] **Step 2: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkRoDesc"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<LOGICAL_ID from Step 1>"
  }
}
```

- [ ] **Step 3: Create the notebook content**

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

# Build_Silver_WkRoDesc
# Purpose: Migrates WKRODESC off the old ODBC-based df_WKRODESC_Raw
# dataflow onto a OneLake shortcut of JD's own live mirror.
#
# Brings in ALL LINES, not just LINE_NO = 1 - the old dataflow's
# WHERE LINE_NO = 1 filter is deliberately NOT replicated. This was a
# real discussion, not a reflexive default: the filter is a real
# grain-narrowing business rule ("primary job per work order"), not a
# date bound, but it has two confirmed real costs found this session:
#   1. 10 work orders have NO LINE_NO = 1 row at all (716,698 distinct
#      (Branch, WorkOrder) combos, only 716,688 have a line-1 row) - a
#      report trusting "every RO has a primary job" would silently get
#      zero rows for those 10.
#   2. LINE_NO values of 1000001 and 1000002 account for 426,921 rows -
#      26% of the whole 1,623,053-row table. Not organic sequential
#      numbers - an unexplained offset pattern the old filter silently
#      drops entirely without anyone having investigated what it
#      represents.
# "Primary job only" is a business decision about what a specific
# consumer wants, not a property of the raw data - it belongs at Gold,
# matching every other business-shaping call already deferred in this
# backend. A future Fact table consumer can decide whether it wants
# LINE_NO = 1 only or something else once the 1000001/1000002 pattern is
# actually understood.
#
# Column casing note: every column in the old dataflow's SQL matched the
# live bronze schema's real casing exactly - no corrections needed here
# (confirmed via a live schema query this session).
#
# Note: the live bronze schema also has a DETAIL column not selected
# here - not added, matching this backend's established discipline of
# replicating each old dataflow's existing consumed column set exactly,
# not expanding scope opportunistically.
#
# Sets the ancient-datetime rebase config proactively (standing practice
# for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKRODESC")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WKRODESC")
bronze_count = bronze.count()
print(f"Bronze WKRODESC rows: {bronze_count:,}")

silver = bronze.select(
    F.col("RO_BRANCH").alias("Branch"),
    F.col("RO_NUMBER").alias("WorkOrder"),
    F.col("JOB_CODE").alias("JobCode"),
    F.col("TYPE").alias("JobType"),
    F.col("LINE_NO").alias("LineNumber"),
    F.col("VALUE").alias("JobValue"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkRoDesc")
print("Silver build complete: Silver_WkRoDesc written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkRoDesc` LIMIT 5").toPandas()
print("Sample rows:")
print(sample.to_string())

line_number_breakdown = spark.sql("""
    SELECT LineNumber, COUNT(*) AS RowCount
    FROM delta.`Tables/Silver_WkRoDesc`
    GROUP BY LineNumber
    ORDER BY RowCount DESC
    LIMIT 15
""").toPandas()
print("\nLineNumber breakdown (top 15 - confirms all lines came through, including the unexplained 1000001/1000002 pattern):")
print(line_number_breakdown.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoDesc.Notebook"
git commit -m "Add Build_Silver_WkRoDesc notebook

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
- `Build_Silver_InHist_PmManage`
- `Build_Silver_WkRoDesc`

- [ ] **Step 3: Report back each notebook's own output**

For `Build_Silver_InHist_PmManage`: bronze/Silver row counts and the franchise breakdown (expect `D` still dominant but every other code present too — confirms nothing got filtered). For `Build_Silver_WkRoDesc`: bronze/Silver row counts and the LineNumber breakdown (expect `1` still the largest single value but `1000001`/`1000002` present too, matching the numbers in this plan). If either assertion fails or a write throws an error, stop and report the full error rather than re-running blindly.

---

### Task 6: Independently verify both Silver tables

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_inhist_wkrodesc.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP INHIST_PMMANAGE AND WKRODESC - SILVER VERIFICATION
============================================================================
Independent check of the 2 Silver tables built in this plan - confirms
each Silver table's row count matches its bronze shortcut exactly (both
are pure select/rename, no filtering - neither old business-rule filter
was replicated).

Run manually after Brian runs both notebooks (plan Task 5).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name)
TABLE_PAIRS = [
    ("InHist_PmManage", "Silver_InHist_PmManage"),
    ("WKRODESC", "Silver_WkRoDesc"),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Bronze':<20} {'Silver':<26} {'Bronze rows':>15} {'Silver rows':>15} {'Match':>8}")
print("=" * 90)

all_match = True
for bronze_name, silver_name in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    match = bronze_count == silver_count
    all_match = all_match and match
    print(f"{bronze_name:<20} {silver_name:<26} {bronze_count:>15,} {silver_count:>15,} {'OK' if match else 'MISMATCH':>8}")

print("=" * 90)
print(f"Both Silver tables match their bronze shortcut exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_inhist_wkrodesc.py
```

Expected: both rows show `OK`.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_inhist_wkrodesc.py
git commit -m "Add Silver verification for InHist_PmManage and WKRODESC

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

Add a `## InHist_PmManage and WKRODESC (2026-09-10) — real business-rule filters, brought in unfiltered anyway` section (after the "Invoice" section) covering:
- The full findings for both tables: `InHist_PmManage`'s Franchise D concentration (83.2%) plus the lowercase `'d'` variant (212 rows) the old exact-match filter would have excluded; `WKRODESC`'s 10-work-orders-with-no-line-1-row gap and the unexplained `1000001`/`1000002` `LINE_NO` pattern (26% of the table)
- Why both filters were NOT replicated despite being real business logic (not incidental like date windows) — the same "business-scoping belongs at Gold" reasoning already applied consistently this session, plus the concrete costs found in each
- The one real casing correction (`InHist_PmManage`'s `PART_NO`→`Part_No`)
- Verification results (both scripts, all passing)
- **That this closes out every Category A table in the original raw-sources catalog except the InMaster group** (filed separately, see `project_nonjd_parts_order_tool_paused.md` in memory) — Category B (Technician-family views) and Category C (tables excluded from JD's mirror) remain, each needing their own future design work
- What's NOT done here: no Franchise D or LINE_NO=1 scoping applied, no report repointing, no gold-layer logic, no refresh schedule

- [ ] **Step 3: Mark both tables done in the catalog doc**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`, change both rows' notes to "**Migrated 2026-09-10**" in the same style as every other completed row, with a one-line mention of what each real finding was.

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document InHist_PmManage and WKRODESC migration

Both tables moved from ODBC-based LH_Master_Data dataflows onto
OneLake shortcuts + Silver notebooks - full unfiltered data, despite
both old dataflows having real business-rule filters (Franchise = 'D',
LINE_NO = 1). Both filters had a confirmed real cost: InHist_PmManage's
exact-match filter would have excluded a lowercase 'd' franchise-code
variant (212 rows); WKRODESC's filter silently dropped 10 work orders
entirely and an unexplained 1000001/1000002 LineNumber pattern (26%
of the table). Business-scoping belongs at Gold, not Silver, matching
every other business-shaping decision already deferred this session.

This closes out every Category A table in the original raw-sources
catalog except the InMaster group (filed separately).

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

**Do not extend this into the InMaster group, Category B/C, gold-layer logic, or any report repointing as part of this plan** — those are each their own future decision, not implied by completing this one.
