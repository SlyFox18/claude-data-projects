# DP Raw Sources — Batch 2 (Date-Windowed Tables, Unfiltered) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the 10 Category A tables whose old `LH_Master_Data` dataflow had a date-range `WHERE` clause onto the new `DP` backend — as OneLake shortcuts plus Silver notebooks, matching batch 1's pattern, but bringing in full history instead of replicating the old date window.

**Architecture:** Same as batch 1 — a OneLake shortcut in `DP_Staging` gives an always-current bronze copy of each table with zero refresh action and zero source-system load, and a Spark notebook per table reads the shortcut and writes a `Silver_<Name>` Delta table with the documented column contract. The difference from batch 1: these old dataflows had a `WHERE ... >= RangeStart` filter, which is deliberately **not** replicated — see "Why no date filter" below.

**Tech Stack:** Fabric OneLake shortcuts, Fabric notebooks (PySpark), DuckDB + `delta_scan()` for independent verification.

---

## Why no date filter (read this before building)

The old dataflows all had a `WHERE <date column> >= RangeStart` clause with a hardcoded epoch (`2022-01-01` or `2023-01-01`). Investigated directly with Brian this session, with three findings that together mean **none of that filtering gets replicated here**:

1. **The `RangeStart`/`RangeEnd` parameter pattern was Brian's own unfinished attempt at incremental refresh** — never completed or validated, not a deliberate "we only need N years" scope decision. Preserving it would be preserving an abandoned experiment, not a real requirement.
2. **On six of these tables, the filter column (`ModifiedDate`) is 40–91% NULL** — a `>=` comparison against NULL is neither true nor false, so the old dataflows were silently dropping most of the table regardless of age, not "excluding old data." A genuinely clean replacement column exists for five of the six (`CreationDate` or a real business-date column); the sixth (`WkVehFl`) has no reliably-populated date column at all across five candidates checked.
3. **Now that a shortcut is free (no ODBC/CU cost), there's no cost reason to filter at this layer anyway.** Date-scoping is a business decision that belongs at the Gold/Fact layer, where a specific consumer's actual need is known — matching how Parts Adjustments and Parts Promo were already built (Silver stayed complete, filtering happened at Gold). Sizes here are modest regardless (largest in this batch is `WKMECHWK` at ~1.5M rows) — Spark processes that quickly either way.

So: **every notebook in this batch brings in full table history, no date filter.** The one exception is `WarClaim`, which keeps its two `IS NOT NULL` filters — confirmed via real data this session to be legitimate data-quality guards (excludes never-filed warranty claims), unrelated to the date-windowing question.

**`Invoice` is deliberately excluded from this batch** — at 6.5M rows, the largest table found in this whole catalog effort, and one of the most heavily-relied-upon tables in the whole platform, it gets its own dedicated look next (same treatment `jdis_Part_Information` got), not lumped into a batch with nine other tables.

**New standing practice, starting with this batch:** every notebook below sets
```python
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")
```
at the top, proactively — this source system has now shown the pre-1900 sentinel-date pattern often enough (`jdis_Part_Information`, and confirmed again this session in `VhStock`, `VhTrans`, `WKMECHWK.DATE_CLOCKED_IN`, `WkVehFl.BUILD_DATE`) that every future notebook touching any table from this source should just include this up front rather than wait to hit the write failure.

---

## Scope

| # | Bronze shortcut name | Old dataflow | Silver table | Notes |
|---|---|---|---|---|
| 1 | `TechnicianInvoiceDetail` | `df_TechnicianInvoiceDetail_Raw` | `Silver_TechnicianInvoiceDetail` | Plain select+rename |
| 2 | `TechnicianPunchedDetail` | `df_TechnicianPunchedDetail_Raw` | `Silver_TechnicianPunchedDetail` | Plain select+rename |
| 3 | `VhStock` | `df_VHSTOCK_Raw` | `Silver_VhStock` | 7 real casing corrections vs. old SQL (confirmed live) + `UPPER(TRIM(...))` on owner code |
| 4 | `VhTrans` | `df_VhTrans_Raw` | `Silver_VhTrans` | Plain select+rename. Has an ancient min date (~1899) and a placeholder future max date (2055) — neither is a bug |
| 5 | `WkInvReg` | `df_WKINVREG_Raw` | `Silver_WkInvReg` | Plain select+rename + `TRIM()` on account number |
| 6 | `WKMECHWK` | `df_WKMECHWK_Raw` | `Silver_WkMechWk` | Plain select+rename. `DATE_CLOCKED_IN` has a confirmed ancient-sentinel date |
| 7 | `WKOTHSUB` | `df_WKOTHSUB_Raw` | `Silver_WkOthSub` | Plain select+rename |
| 8 | `WkRoFile` | `df_WKROFILE_Raw` | `Silver_WkRoFile` | 1 real casing correction vs. old SQL (confirmed live) |
| 9 | `WkVehFl` | `df_WKVEHFL_Raw` | `Silver_WkVehFl` | 1 real casing correction vs. old SQL (confirmed live). No reliable date column exists on this table at all (checked 5 candidates, all 43–76% NULL) |
| 10 | `WarClaim` | `df_WarClaim_Raw` | `Silver_WarClaim` | Keeps its two `IS NOT NULL` filters — the one table in this batch with real row-count reduction |

**Explicitly out of scope:** `Invoice` (separate, dedicated work next), `InHist_PmManage`/`WKRODESC` (real business-rule filters, not date bounds — still flagged as "needs more thought" in the catalog), the InMaster group (investigated and filed separately — see `project_nonjd_parts_order_tool_paused.md` in memory), Category B (Technician-family views) and Category C (tables excluded from JD's mirror). No report repointing, no gold-layer logic, no refresh schedule — Dev tier, Silver layer, manual trigger only.

---

### Task 1: Brian creates the 10 OneLake shortcuts

**Files:** none (Fabric portal action)

- [ ] **Step 1: Create the first shortcut (`TechnicianInvoiceDetail`) — full steps**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. Open the `DP_Staging` lakehouse
3. In the `Tables` explorer, right-click → **New shortcut**
4. Choose **Microsoft OneLake** as the source
5. Navigate to `JD_FabricOneLake` workspace → `EquipRDB_Production` folder → `JD_EquipRDB_Production_Bronze` lakehouse → `Tables`
6. Select the table `TechnicianInvoiceDetail`
7. Keep the destination name as `TechnicianInvoiceDetail` (don't rename)
8. **Create**

- [ ] **Step 2: Repeat for the remaining 9 tables**

Same steps as above, substituting the table name — select each from `JD_EquipRDB_Production_Bronze` → `Tables` and keep the destination name identical to the source name:

- `TechnicianPunchedDetail`
- `VhStock`
- `VhTrans`
- `WkInvReg`
- `WKMECHWK`
- `WKOTHSUB`
- `WkRoFile`
- `WkVehFl`
- `WarClaim`

- [ ] **Step 3: Confirm all 10 shortcuts appear**

In `DP_Staging` → `Tables`, confirm all 10 names above are listed alongside the existing shortcuts from batch 1 and the InTrans/GlTrans work. Report back once done.

---

### Task 2: Independently verify the 10 bronze shortcuts

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch2.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP RAW SOURCES BATCH 2 - BRONZE SHORTCUT VERIFICATION
============================================================================
Confirms each of the 10 new OneLake shortcuts in DP_Staging resolves to the
exact same row count as reading the same table directly from
JD_EquipRDB_Production_Bronze. A shortcut points at the same underlying
Delta files as its source, so any mismatch here means the shortcut itself
is broken (wrong table selected, stale metadata), not a data problem.

Run manually after Brian creates all 10 shortcuts (plan Task 1).
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
    "TechnicianInvoiceDetail",
    "TechnicianPunchedDetail",
    "VhStock",
    "VhTrans",
    "WkInvReg",
    "WKMECHWK",
    "WKOTHSUB",
    "WkRoFile",
    "WkVehFl",
    "WarClaim",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 90)
print(f"{'Table':<26} {'DP_Staging shortcut':>20} {'JD Bronze direct':>20} {'Match':>10}")
print("=" * 90)

all_match = True
for t in TABLES:
    dp_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{t}')").fetchone()[0]
    jd_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{jd_base}/{t}')").fetchone()[0]
    match = dp_count == jd_count
    all_match = all_match and match
    print(f"{t:<26} {dp_count:>20,} {jd_count:>20,} {'OK' if match else 'MISMATCH':>10}")

print("=" * 90)
print(f"All 10 shortcuts match their JD Bronze source exactly: {all_match}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch2.py
```

Expected: all 10 rows show `OK`. If any row shows `MISMATCH`, stop and investigate that specific shortcut before proceeding to Task 3 — check the table name was selected correctly (batch 1 caught a real `VhStock`/`VhStockAccess` mix-up this exact way).

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcuts_rawsources_batch2.py
git commit -m "Add bronze shortcut verification for raw sources batch 2

Confirms all 10 new DP_Staging OneLake shortcuts (TechnicianInvoiceDetail,
TechnicianPunchedDetail, VhStock, VhTrans, WkInvReg, WKMECHWK, WKOTHSUB,
WkRoFile, WkVehFl, WarClaim) resolve to the exact same row count as
JD_EquipRDB_Production_Bronze directly.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 3: Build `Build_Silver_TechnicianInvoiceDetail.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianInvoiceDetail.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianInvoiceDetail.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_TechnicianInvoiceDetail"
  },
  "config": {
    "version": "2.0",
    "logicalId": "a2851d92-95ff-4431-a50d-37e5ee3ee9e9"
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

# Build_Silver_TechnicianInvoiceDetail
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates
# TechnicianInvoiceDetail off the old ODBC-based
# df_TechnicianInvoiceDetail_Raw dataflow onto a OneLake shortcut of JD's
# own live mirror.
#
# Brings in FULL history - the old dataflow's date-range WHERE clause is
# deliberately not replicated here. That filter was Brian's own unfinished
# attempt at incremental refresh (never completed/validated), not a real
# "we only need N years" requirement, and date-scoping is a business
# decision that belongs at the Gold/Fact layer where a specific consumer's
# real need is known - not at Silver, which stays complete and correct,
# matching how Parts Adjustments and Parts Promo were already built.
#
# Sets the ancient-datetime rebase config proactively (new standing
# practice for every notebook in this backend from now on) - this source
# system has shown the pre-1900 sentinel-date pattern often enough
# (jdis_Part_Information, VhStock, VhTrans, and other tables in this same
# batch) that it's cheaper to always include this than wait to hit the
# write failure again.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_TECHNICIANINVOICEDETAIL")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("TechnicianInvoiceDetail")
bronze_count = bronze.count()
print(f"Bronze TechnicianInvoiceDetail rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Branch").alias("Branch"),
    F.col("RepairOrderNumber").alias("WorkOrder"),
    F.col("InvoiceNumber").alias("InvoiceNumber"),
    F.col("TechnicianCode").alias("TechCode"),
    F.col("SequenceID").alias("SequenceID"),
    F.col("JobCode").alias("JobCode"),
    F.col("JobType").alias("JobType"),
    F.col("InvoiceDate").alias("InvoiceDate"),
    F.col("WorkDate").alias("WorkDate"),
    F.col("StartTime").alias("StartTime"),
    F.col("EndTime").alias("EndTime"),
    F.col("HoursPunched").alias("HoursPunched"),
    F.col("InvoiceHours").alias("InvoiceHours"),
    F.col("ReworkHours").alias("ReworkHours"),
    F.col("DelayHours").alias("DelayHours"),
    F.col("LaborCost").alias("LaborCost"),
    F.col("LaborSale").alias("LaborSale"),
    F.col("NonRevenueIndicator").alias("NonRevenueIndicator"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_TechnicianInvoiceDetail")
print("Silver build complete: Silver_TechnicianInvoiceDetail written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_TechnicianInvoiceDetail` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianInvoiceDetail.Notebook"
git commit -m "Add Build_Silver_TechnicianInvoiceDetail notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

---

### Task 4: Build `Build_Silver_TechnicianPunchedDetail.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianPunchedDetail.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianPunchedDetail.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_TechnicianPunchedDetail"
  },
  "config": {
    "version": "2.0",
    "logicalId": "1c545801-de44-4da5-899b-78eb6615872e"
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

# Build_Silver_TechnicianPunchedDetail
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates
# TechnicianPunchedDetail off the old ODBC-based
# df_TechnicianPunchedDetail_Raw dataflow onto a OneLake shortcut of JD's
# own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale (same for every notebook in this batch).
# This table's old filter column, CreationDate, was actually 0% NULL (one
# of only a few in this batch that was already clean) - still not
# replicated, for consistency with the rest of the batch and because the
# reasoning (date-scoping belongs at Gold, not Silver) applies regardless
# of whether the old column happened to be reliable.
#
# Sets the ancient-datetime rebase config proactively (new standing
# practice for every notebook in this backend).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_TECHNICIANPUNCHEDDETAIL")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("TechnicianPunchedDetail")
bronze_count = bronze.count()
print(f"Bronze TechnicianPunchedDetail rows: {bronze_count:,}")

silver = bronze.select(
    F.col("Branch").alias("Branch"),
    F.col("ROBranch").alias("ROBranch"),
    F.col("RepairOrderNumber").alias("WorkOrder"),
    F.col("TechnicianCode").alias("TechCode"),
    F.col("SequenceID").alias("SequenceID"),
    F.col("JobCode").alias("JobCode"),
    F.col("JobType").alias("JobType"),
    F.col("HoursInternal").alias("HoursInternal"),
    F.col("HoursWarranty").alias("HoursWarranty"),
    F.col("HoursRetail").alias("HoursRetail"),
    F.col("HoursFleet").alias("HoursFleet"),
    F.col("HoursSundry").alias("HoursSundry"),
    F.col("HoursAgreement").alias("HoursAgreement"),
    F.col("HoursOther").alias("HoursOther"),
    F.col("WorkDate").alias("WorkDate"),
    F.col("StartTime").alias("StartTime"),
    F.col("EndTime").alias("EndTime"),
    F.col("HoursWorked").alias("HoursWorked"),
    F.col("HoursSold").alias("HoursSold"),
    F.col("CustomerName").alias("CustomerName"),
    F.col("Model").alias("EquipmentModel"),
    F.col("CreationDate").alias("CreationDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_TechnicianPunchedDetail")
print("Silver build complete: Silver_TechnicianPunchedDetail written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_TechnicianPunchedDetail` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_TechnicianPunchedDetail.Notebook"
git commit -m "Add Build_Silver_TechnicianPunchedDetail notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 5: Build `Build_Silver_VhStock.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStock.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStock.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_VhStock"
  },
  "config": {
    "version": "2.0",
    "logicalId": "ae03c727-9725-4fbc-903e-ec5cc64e53d9"
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

# Build_Silver_VhStock
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates VhStock off
# the old ODBC-based df_VHSTOCK_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale.
#
# Column casing note: the live JD Bronze schema uses mixed case on several
# columns the old dataflow's all-caps SQL text assumed were plain
# uppercase (OWNER->Owner, OPTION_COST->Option_Cost, PAINT_COST->
# Paint_Cost, TRIM_COST->Trim_Cost, CHARGE_COST->Charge_Cost,
# AFTER_MARKET_COST->After_Market_Cost, PRE_TRADE_OVRALLOW->
# Pre_Trade_Ovrallow) - confirmed via a live schema query this session,
# same class of issue as VhStockAccess in batch 1 (SQL Anywhere resolves
# column names case-insensitively, Delta/Parquet does not).
#
# Replicates the old dataflow's UPPER(TRIM(...)) transform on the owner
# contact code. Sets the ancient-datetime rebase config proactively (this
# table has genuine sentinel dates, e.g. DATEREC/other columns not
# selected here, but the config is applied as standing practice regardless
# of which specific column would trigger it).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_VHSTOCK")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("VhStock")
bronze_count = bronze.count()
print(f"Bronze VhStock rows: {bronze_count:,}")

silver = bronze.select(
    F.col("NO").alias("StockNumber"),
    F.col("MAKE").alias("Make"),
    F.col("MODEL").alias("Model"),
    F.col("YEAR_MANUF").alias("Year"),
    F.col("VIN_NO").alias("VIN"),
    F.col("ENGNO").alias("EngineNumber"),
    F.upper(F.trim(F.col("Owner"))).alias("OwnerContactCode"),
    F.col("SALESDATE").alias("SaleDate"),
    F.col("SALES_VALUE").alias("SalesValue"),
    F.col("STATUS").alias("Status"),
    F.col("SALESPERSON").alias("Salesperson"),
    F.col("SALES_INV").alias("SalesInvoice"),
    F.col("SALES_TYPE").alias("SalesType"),
    F.col("RETAIL").alias("RetailCost"),
    F.col("WHOLESALE").alias("WholesaleCost"),
    F.col("PREDEL_COST").alias("PredeliveryCost"),
    F.col("REPAIR_COST").alias("RepairCost"),
    F.col("ACCESS_COST").alias("AccessoryCost"),
    F.col("OTHER_COST").alias("OtherCost"),
    F.col("REGO_FEES").alias("RegistrationFees"),
    F.col("LOT_FEES").alias("LotFees"),
    F.col("STAMP_DUTY").alias("StampDuty"),
    F.col("TRANSFER_FEES").alias("TransferFees"),
    F.col("Option_Cost").alias("OptionCost"),
    F.col("Paint_Cost").alias("PaintCost"),
    F.col("Trim_Cost").alias("TrimCost"),
    F.col("Charge_Cost").alias("ChargeCost"),
    F.col("After_Market_Cost").alias("AfterMarketCost"),
    F.col("OVRALLOW").alias("TradeAllowance"),
    F.col("Pre_Trade_Ovrallow").alias("PreTradeAllowance"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_VhStock")
print("Silver build complete: Silver_VhStock written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_VhStock` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhStock.Notebook"
git commit -m "Add Build_Silver_VhStock notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 6: Build `Build_Silver_VhTrans.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhTrans.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhTrans.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_VhTrans"
  },
  "config": {
    "version": "2.0",
    "logicalId": "0670856d-8a4a-4d1e-aa97-91f0a459bd95"
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

# Build_Silver_VhTrans
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates VhTrans off
# the old ODBC-based df_VhTrans_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale. All column names in the old dataflow's
# SQL already matched the live bronze schema's real casing exactly - no
# casing corrections needed here (unlike VhStock, which used all-caps for
# several columns the live schema stores in mixed case).
#
# Data quality note: this table has a confirmed ancient-sentinel min date
# (~1899) on vhtrans_date, and a placeholder future max date (2055-11-06,
# presumably open/scheduled transactions) - neither is a bug, don't be
# alarmed by either showing up in verification output.
#
# Sets the ancient-datetime rebase config proactively - mandatory here
# given the confirmed sentinel date.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_VHTRANS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("VhTrans")
bronze_count = bronze.count()
print(f"Bronze VhTrans rows: {bronze_count:,}")

silver = bronze.select(
    F.col("stock_no").alias("StockNumber"),
    F.col("trans_id").alias("TransactionId"),
    F.col("vhtrans_date").alias("TransactionDate"),
    F.col("type").alias("Type"),
    F.col("ref").alias("ReferenceNumber"),
    F.col("description").alias("Description"),
    F.col("doc_date").alias("DocumentDate"),
    F.col("period_date").alias("PeriodDate"),
    F.col("period").alias("Period"),
    F.col("prior_year").alias("PriorYear"),
    F.col("predel_cost").alias("PredeliveryCost"),
    F.col("repair_cost").alias("RepairCost"),
    F.col("access_cost").alias("AccessoryCost"),
    F.col("other_cost").alias("OtherCost"),
    F.col("wholesale").alias("WholesaleCost"),
    F.col("retail").alias("RetailCost"),
    F.col("Option_Cost").alias("OptionCost"),
    F.col("Paint_Cost").alias("PaintCost"),
    F.col("Trim_Cost").alias("TrimCost"),
    F.col("Charge_Cost").alias("ChargeCost"),
    F.col("After_Market_Cost").alias("AfterMarketCost"),
    F.col("Surcharge_Cost").alias("SurchargeCost"),
    F.col("rego_fees").alias("RegistrationFees"),
    F.col("lot_fees").alias("LotFees"),
    F.col("stamp_duty").alias("StampDuty"),
    F.col("transfer_fees").alias("TransferFees"),
    F.col("floorval").alias("FloorValue"),
    F.col("unit_debtors").alias("UnitDebtors"),
    F.col("gst_in").alias("GSTIn"),
    F.col("gst_out").alias("GSTOut"),
    F.col("sales_inv").alias("SalesInvoice"),
    F.col("Capitalized_Interest").alias("CapitalizedInterest"),
    F.col("Rental_Depreciation_Memo").alias("RentalDepreciationMemo"),
    F.col("Expense_Code").alias("ExpenseCode"),
    F.col("Expense_Value").alias("ExpenseValue"),
    F.col("after_sales_act").alias("AfterSalesActivity"),
    F.col("Allocated_Ind").alias("AllocatedIndicator"),
    F.col("Company").alias("Company"),
    F.col("tj_seqno").alias("TJSequenceNumber"),
    F.col("tj_cancel_no").alias("TJCancelNumber"),
    F.col("tj_xml").alias("TJXML"),
    F.col("CreationDate").alias("CreationDate"),
    F.col("CreatedBy").alias("CreatedBy"),
    F.col("ModifiedDate").alias("ModifiedDate"),
    F.col("ModifiedBy").alias("ModifiedBy"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_VhTrans")
print("Silver build complete: Silver_VhTrans written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_VhTrans` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_VhTrans.Notebook"
git commit -m "Add Build_Silver_VhTrans notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 7: Build `Build_Silver_WkInvReg.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkInvReg.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkInvReg.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkInvReg"
  },
  "config": {
    "version": "2.0",
    "logicalId": "a2a0d136-66a6-4317-9886-70fdcbe8bc0a"
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

# Build_Silver_WkInvReg
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WkInvReg off
# the old ODBC-based df_WKINVREG_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale. The old dataflow's filter column,
# ModifiedDate, is 90.8% NULL on this table (confirmed via live query this
# session) - the worst case found in this whole batch - so the old filter
# was silently dropping the vast majority of the table long before this
# migration, not meaningfully bounding it by age. Moot now regardless,
# since no date filter is applied at all.
#
# Replicates the old dataflow's TRIM() transform on the account number.
# Sets the ancient-datetime rebase config proactively (standing practice).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKINVREG")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WkInvReg")
bronze_count = bronze.count()
print(f"Bronze WkInvReg rows: {bronze_count:,}")

silver = bronze.select(
    F.col("DOCUMENT_NO").alias("InvoiceNumber"),
    F.col("BRANCH").alias("Branch"),
    F.col("RO_NUMBER").alias("WorkOrder"),
    F.col("RO_TYPE").alias("ROType"),
    F.trim(F.col("CHARGE_ACCT")).alias("AccountNumber"),
    F.col("LABOUR_COST").alias("LabourCost"),
    F.col("LABOUR_CHARGED").alias("LabourCharged"),
    F.col("PARTS_VALUE").alias("PartsValue"),
    F.col("OTHER_VALUE").alias("OtherValue"),
    F.col("SUBLET_VALUE").alias("SubletValue"),
    F.col("INVOICE_VALUE").alias("InvoiceTotal"),
    F.col("serv_tax_val").alias("ServiceTaxValue"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("REG").alias("Registration"),
    F.col("STOCK_NO").alias("StockNumber"),
    F.col("TRADE_TYPE").alias("TradeType"),
    F.col("SALES_ADVISOR").alias("SalesAdvisor"),
    F.col("WORK_DATE").alias("WorkDate"),
    F.col("CreationDate").alias("CreatedOn"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkInvReg")
print("Silver build complete: Silver_WkInvReg written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkInvReg` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkInvReg.Notebook"
git commit -m "Add Build_Silver_WkInvReg notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 8: Build `Build_Silver_WkMechWk.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechWk.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechWk.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkMechWk"
  },
  "config": {
    "version": "2.0",
    "logicalId": "2fe11df7-ec73-4310-bcd9-d0f11d61985a"
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

# Build_Silver_WkMechWk
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WKMECHWK off
# the old ODBC-based df_WKMECHWK_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale. The old dataflow's filter column,
# ModifiedDate, is 49.7% NULL on this table (confirmed this session).
#
# Data quality note: DATE_CLOCKED_IN has a confirmed ancient-sentinel
# date (min year 0013!) - exactly why the ancient-datetime Spark config
# below is mandatory for this notebook, not just standing practice.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKMECHWK")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WKMECHWK")
bronze_count = bronze.count()
print(f"Bronze WKMECHWK rows: {bronze_count:,}")

silver = bronze.select(
    F.col("RO_BRANCH").alias("Branch"),
    F.col("RO_NUMBER").alias("WorkOrder"),
    F.col("JOB_CODE").alias("JobCode"),
    F.col("JOB_TYPE").alias("JobType"),
    F.col("MECHANIC_CODE").alias("TechCode"),
    F.col("SEQ").alias("SequenceNumber"),
    F.col("DATE_CLOCKED_IN").alias("ClockInDate"),
    F.col("START_TIME").alias("StartTime"),
    F.col("FINISH_TIME").alias("FinishTime"),
    F.col("INVOICE_HRS").alias("InvoiceHours"),
    F.col("HOURS_WORK").alias("HoursWorked"),
    F.col("HOURS_REWORK").alias("HoursRework"),
    F.col("COST_VAL").alias("LaborCost"),
    F.col("SELL_VAL").alias("LaborSale"),
    F.col("DELAY_CODE").alias("DelayCode"),
    F.col("DELAY_HOURS").alias("DelayHours"),
    F.col("Labor_Type").alias("LaborType"),
    F.col("Work_Cat").alias("WorkCategory"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkMechWk")
print("Silver build complete: Silver_WkMechWk written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkMechWk` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkMechWk.Notebook"
git commit -m "Add Build_Silver_WkMechWk notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 9: Build `Build_Silver_WkOthSub.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkOthSub.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkOthSub.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkOthSub"
  },
  "config": {
    "version": "2.0",
    "logicalId": "cc269fd4-2beb-4cfc-bd4d-2d47772cf58c"
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

# Build_Silver_WkOthSub
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WKOTHSUB off
# the old ODBC-based df_WKOTHSUB_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale. The old dataflow's filter column,
# ModifiedDate, is 52.7% NULL on this table (confirmed this session) -
# notably, this table's OWN Creation_Date column is actually worse
# (44.6% NULL) than ModifiedDate, so even a same-family "just switch to
# CreationDate" fix (which worked for several other tables in this batch)
# would not have worked here. Moot regardless, since no date filter is
# applied at all.
#
# Sets the ancient-datetime rebase config proactively (standing practice).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKOTHSUB")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WKOTHSUB")
bronze_count = bronze.count()
print(f"Bronze WKOTHSUB rows: {bronze_count:,}")

silver = bronze.select(
    F.col("RO_BRANCH").alias("Branch"),
    F.col("RO_NUMBER").alias("WorkOrder"),
    F.col("JOB_CODE").alias("JobCode"),
    F.col("TYPE").alias("JobType"),
    F.col("EST_LAB_VAL").alias("EstLabor"),
    F.col("Act_Lab_Val").alias("ActLabor"),
    F.col("Inv_Lab_Val").alias("InvLabor"),
    F.col("est_hours").alias("EstHours"),
    F.col("EST_PART_VAL").alias("EstParts"),
    F.col("Act_Part_Val").alias("ActParts"),
    F.col("Inv_Part_Val").alias("InvParts"),
    F.col("Machine_Down_Ind").alias("IsMachineDown"),
    F.col("Work_Cat").alias("WorkCategory"),
    F.col("STATUS").alias("JobStatus"),
    F.col("non_revenue").alias("IsNonRevenue"),
    F.col("Field_Repair").alias("IsFieldRepair"),
    F.col("Std_Lab_Ind").alias("IsStandardLabor"),
    F.col("INVOICE_NO").alias("InvoiceNumber"),
    F.col("INVOICE_DATE").alias("InvoiceDate"),
    F.col("CLAIM_NO").alias("ClaimNumber"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkOthSub")
print("Silver build complete: Silver_WkOthSub written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkOthSub` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkOthSub.Notebook"
git commit -m "Add Build_Silver_WkOthSub notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 10: Build `Build_Silver_WkRoFile.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoFile.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoFile.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkRoFile"
  },
  "config": {
    "version": "2.0",
    "logicalId": "0dee1047-32da-41cd-bd51-1b049f2c9e0d"
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

# Build_Silver_WkRoFile
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WkRoFile off
# the old ODBC-based df_WKROFILE_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the full rationale. The old dataflow's filter column,
# ModifiedDate, is 40.7% NULL on this table (confirmed this session).
#
# Column casing note: the live JD Bronze schema stores RO_PROGRESS_STATUS
# as lowercase ro_progress_status - the old dataflow's all-caps SQL text
# worked under SQL Anywhere's case-insensitive resolution, but Delta/
# Parquet is not case-insensitive, so this notebook uses the real live
# casing (confirmed via a live schema query this session).
#
# Sets the ancient-datetime rebase config proactively (standing practice) -
# REQ_DATETIME, not selected here, has a confirmed corrupted range
# (year 0100 to year 7000), a further data-quality reason this table's old
# filter column choices were unreliable.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKROFILE")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WkRoFile")
bronze_count = bronze.count()
print(f"Bronze WkRoFile rows: {bronze_count:,}")

silver = bronze.select(
    F.col("BRANCH").alias("Branch"),
    F.col("RO_NUMBER").alias("WorkOrder"),
    F.col("REG").alias("Registration"),
    F.col("CHARGE_ACCT").alias("AccountNumber"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("STOCK_FRAN").alias("StockFranchise"),
    F.col("STOCK_NO").alias("StockNumber"),
    F.col("ODOMETER").alias("Odometer"),
    F.col("RO_STATUS").alias("ROStatus"),
    F.col("ro_progress_status").alias("ProgressStatus"),
    F.col("ro_closed_ind").alias("IsClosed"),
    F.col("Account_Class").alias("AccountClass"),
    F.col("CUST_VEH_FA").alias("CustomerVehicleFlag"),
    F.col("salesman").alias("Salesperson"),
    F.col("Pay_Method").alias("PaymentMethod"),
    F.col("CUST_ORDER_NO").alias("CustomerOrderNumber"),
    F.col("Field_Service_Flag").alias("IsFieldService"),
    F.col("Creation_Date").alias("CreatedOn"),
    F.col("Closed_Date").alias("ClosedDate"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkRoFile")
print("Silver build complete: Silver_WkRoFile written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkRoFile` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkRoFile.Notebook"
git commit -m "Add Build_Silver_WkRoFile notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 11: Build `Build_Silver_WkVehFl.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkVehFl.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkVehFl.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WkVehFl"
  },
  "config": {
    "version": "2.0",
    "logicalId": "eee765a5-5b54-4b60-8ed4-0eb82ba00bd8"
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

# Build_Silver_WkVehFl
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WkVehFl off
# the old ODBC-based df_WKVEHFL_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in FULL history - see Build_Silver_TechnicianInvoiceDetail's
# header for the general rationale, but this table is a special case
# worth spelling out: unlike the other tables in this batch, WkVehFl has
# NO reliably-populated date column at all. Checked five candidates this
# session (CreationDate 62.0% NULL, DELIVERY_DATE 20.9% NULL,
# LAST_SERV_DATE 75.1% NULL, BUILD_DATE 76.1% NULL, plus the old
# ModifiedDate at 43.3% NULL) - every one is substantially incomplete.
# This isn't a case of "pick a better column instead," the way it was for
# five other tables in this batch - there simply isn't a clean column
# here. Bringing in the full ~270K-row table unfiltered is the correct
# choice on the data, not just a default.
#
# Column casing note: the live JD Bronze schema stores COMPLIANCE_DATE as
# mixed-case Compliance_Date - the old dataflow's all-caps SQL text worked
# under SQL Anywhere's case-insensitive resolution, but this notebook uses
# the real live casing (confirmed via a live schema query this session).
#
# Sets the ancient-datetime rebase config proactively - mandatory here
# given BUILD_DATE's confirmed 1899-12-31 sentinel minimum.

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WKVEHFL")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WkVehFl")
bronze_count = bronze.count()
print(f"Bronze WkVehFl rows: {bronze_count:,}")

silver = bronze.select(
    F.col("REG").alias("Registration"),
    F.col("ACCOUNT_NO").alias("AccountNumber"),
    F.col("VIN_NO").alias("VIN"),
    F.col("MAKE").alias("Make"),
    F.col("MODEL").alias("Model"),
    F.col("YEAR_MANUF").alias("Year"),
    F.col("ENGINE").alias("Engine"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("NEW_OR_USED").alias("Status"),
    F.col("BUILD_DATE").alias("BuildDate"),
    F.col("DELIVERY_DATE").alias("DeliveryDate"),
    F.col("First_Reg").alias("FirstRegDate"),
    F.col("Compliance_Date").alias("ComplianceDate"),
    F.col("ODOMETER_DATE").alias("OdometerDate"),
    F.col("LATEST_ODO").alias("Odometer"),
    F.col("ModifiedDate").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == bronze_count, (
    f"Row count mismatch: bronze {bronze_count:,} vs silver {silver_count:,} - "
    f"this notebook only renames columns, it should never add or drop rows."
)
print(f"Silver rows: {silver_count:,} (matches bronze exactly)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WkVehFl")
print("Silver build complete: Silver_WkVehFl written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WkVehFl` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WkVehFl.Notebook"
git commit -m "Add Build_Silver_WkVehFl notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 12: Build `Build_Silver_WarClaim.Notebook`

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarClaim.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarClaim.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_WarClaim"
  },
  "config": {
    "version": "2.0",
    "logicalId": "52e929c9-4176-4e88-b1fd-42bccce63d48"
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

# Build_Silver_WarClaim
# Purpose: Part of raw-sources batch 2 (2026-09-10). Migrates WarClaim off
# the old ODBC-based df_WarClaim_Raw dataflow onto a OneLake shortcut of
# JD's own live mirror.
#
# Brings in full history for the date dimension - see
# Build_Silver_TechnicianInvoiceDetail's header for the general rationale
# (the old REPAIR_DATE filter is not replicated). REPAIR_DATE itself was
# actually 0% NULL on this table (one of the clean ones) - not replicated
# anyway, for the same Gold-layer-scoping reasoning as the rest of the
# batch.
#
# UNLIKE every other notebook in this batch, this one DOES keep the old
# dataflow's two IS NOT NULL filters - confirmed via real data this
# session these are legitimate data-quality guards, not an arbitrary scope
# decision: 5,042 of 46,887 rows (10.75%) are excluded, all missing
# CLAIM_NO specifically (INVOICE_NO is never null on this table), and
# sample excluded rows are all STATUS='U' - warranty-eligible RO/invoice
# records that never actually became a filed claim. A table whose whole
# purpose is tracking warranty CLAIMS shouldn't include rows that were
# never a real claim, so this filter stays.
#
# Sets the ancient-datetime rebase config proactively (standing practice).

spark.conf.set("spark.sql.parquet.datetimeRebaseModeInRead", "CORRECTED")
spark.conf.set("spark.sql.parquet.datetimeRebaseModeInWrite", "CORRECTED")

print("=" * 80)
print("BUILD_SILVER_WARCLAIM")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

bronze = spark.read.table("WarClaim")
bronze_count = bronze.count()
print(f"Bronze WarClaim rows: {bronze_count:,}")

filtered = bronze.filter(
    F.col("INVOICE_NO").isNotNull() & F.col("CLAIM_NO").isNotNull()
)
filtered_count = filtered.count()
excluded_count = bronze_count - filtered_count
print(f"Rows excluded (missing InvoiceNumber or ClaimNumber): {excluded_count:,}")

silver = filtered.select(
    F.col("CLAIM_NO").alias("ClaimNumber"),
    F.col("INVOICE_NO").alias("InvoiceNumber"),
    F.col("RO_NUMBER").alias("WorkOrderNumber"),
    F.col("RO_BRANCH").alias("WorkOrderBranch"),
    F.col("Model_Serial_No").alias("ModelSerialNumber"),
    F.col("PART_INVOICE_VAL").alias("PartsInvoiceValue"),
    F.col("LAB_INVOICE_VAL").alias("LaborInvoiceValue"),
    F.col("SUB_INVOICE_VAL").alias("SubletInvoiceValue"),
    F.col("OTH_INVOICE_VAL").alias("OtherInvoiceValue"),
    F.col("WARRANTY_WRITE_OFF").alias("WarrantyWriteOff"),
    F.col("WARRANTY_REJECTION").alias("WarrantyRejection"),
    F.col("GST_VALUE").alias("GSTValue"),
    F.col("FRANCHISE").alias("Franchise"),
    F.col("STATUS").alias("ClaimStatus"),
    F.col("DRIVER").alias("DriverName"),
    F.col("OWNER").alias("OwnerName"),
    F.col("Owner_Status_Code").alias("OwnerStatusCode"),
    F.col("REPAIR_DATE").alias("RepairDate"),
    F.col("LAST_UPDATE_TS").alias("ModifiedDate"),
)

silver_count = silver.count()
assert silver_count == filtered_count, (
    f"Row count mismatch after column selection: filtered {filtered_count:,} "
    f"vs silver {silver_count:,} - the select step should never add or drop "
    f"rows beyond the explicit IS NOT NULL filter already applied above."
)
print(f"Silver rows: {silver_count:,} (bronze {bronze_count:,} minus {excluded_count:,} excluded)")

silver.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_WarClaim")
print("Silver build complete: Silver_WarClaim written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/Silver_WarClaim` LIMIT 5").toPandas()
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
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_WarClaim.Notebook"
git commit -m "Add Build_Silver_WarClaim notebook (raw sources batch 2)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT. Otherwise:
```bash
git push origin dev
```

---

### Task 13: Brian syncs Dev and runs all 10 notebooks

**Files:** none (Fabric portal action)

- [ ] **Step 1: Sync the workspace**

`DP - Staging - Dev` → Source control → **Update all**.

- [ ] **Step 2: Run each notebook**

Open each of the 10 notebooks below (in `Data Notebooks/`) and **Run all** cells. They're independent of each other - run them one at a time or back-to-back:

- `Build_Silver_TechnicianInvoiceDetail`
- `Build_Silver_TechnicianPunchedDetail`
- `Build_Silver_VhStock`
- `Build_Silver_VhTrans`
- `Build_Silver_WkInvReg`
- `Build_Silver_WkMechWk`
- `Build_Silver_WkOthSub`
- `Build_Silver_WkRoFile`
- `Build_Silver_WkVehFl`
- `Build_Silver_WarClaim`

- [ ] **Step 3: Report back each notebook's own output**

For each: the bronze row count, the silver row count, and the sample rows printed at the end. For `Build_Silver_WarClaim` specifically, also report the "Rows excluded" line - expect it to be close to 5,042 (it will drift slightly since the source is live, same as every other count in this project). If any notebook's assertion fails or throws an error, stop and report the full error/stack trace rather than re-running blindly - the ancient-datetime write failure looks exactly like this if any notebook is somehow missing its rebase-mode config, so check that first if a write step fails.

---

### Task 14: Independently verify all 10 Silver tables

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch2.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP RAW SOURCES BATCH 2 - SILVER VERIFICATION
============================================================================
Independent check of the 10 Silver tables built in this batch. Nine of the
ten should match their bronze shortcut's row count exactly (pure select/
rename, no filtering). WarClaim is the one exception - it applies a real
IS NOT NULL filter, so its Silver count is expected to be LOWER than
bronze by roughly 5,042 rows (10.75% of the table, as of this session -
will drift slightly since the source is live).
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

# (bronze shortcut name, silver table name, expect_exact_match)
TABLE_PAIRS = [
    ("TechnicianInvoiceDetail", "Silver_TechnicianInvoiceDetail", True),
    ("TechnicianPunchedDetail", "Silver_TechnicianPunchedDetail", True),
    ("VhStock", "Silver_VhStock", True),
    ("VhTrans", "Silver_VhTrans", True),
    ("WkInvReg", "Silver_WkInvReg", True),
    ("WKMECHWK", "Silver_WkMechWk", True),
    ("WKOTHSUB", "Silver_WkOthSub", True),
    ("WkRoFile", "Silver_WkRoFile", True),
    ("WkVehFl", "Silver_WkVehFl", True),
    ("WarClaim", "Silver_WarClaim", False),
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=" * 100)
print(f"{'Bronze':<26} {'Silver':<28} {'Bronze rows':>13} {'Silver rows':>13} {'Result':>10}")
print("=" * 100)

all_ok = True
for bronze_name, silver_name, expect_exact in TABLE_PAIRS:
    bronze_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{bronze_name}')").fetchone()[0]
    silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/{silver_name}')").fetchone()[0]
    if expect_exact:
        ok = bronze_count == silver_count
        result = "OK" if ok else "MISMATCH"
    else:
        # WarClaim: silver should be strictly less than bronze (real filter applied),
        # and not implausibly smaller (sanity bound - shouldn't drop more than half the table)
        ok = 0 < silver_count < bronze_count and (bronze_count - silver_count) < bronze_count * 0.5
        result = f"OK (-{bronze_count - silver_count:,})" if ok else "UNEXPECTED"
    all_ok = all_ok and ok
    print(f"{bronze_name:<26} {silver_name:<28} {bronze_count:>13,} {silver_count:>13,} {result:>10}")

print("=" * 100)
print(f"All 10 Silver tables verified: {all_ok}")
```

- [ ] **Step 2: Brian runs it and reports the output**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch2.py
```

Expected: nine rows show `OK`, `WarClaim` shows `OK (-N)` where N is close to 5,042.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_rawsources_batch2.py
git commit -m "Add Silver verification for raw sources batch 2

Confirms 9 of the 10 new Silver tables match their bronze shortcut
row count exactly (pure select/rename); WarClaim is the expected
exception, verified to be lower than bronze by a plausible amount
(its real IS NOT NULL filter).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 15: Update reference docs

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`
- Modify: `docs/architecture/jd-bronze-raw-sources-catalog.md`

- [ ] **Step 1: Add the new tables to `DP_Staging`'s Lakehouses table**

In `docs/architecture/data-platform-workspaces.md`, find the `DP_Staging` lakehouse row (already updated once for batch 1) and add the 10 new shortcuts and 10 new Silver tables to its listed contents.

- [ ] **Step 2: Add a new section for this batch**

Add a `## Raw sources batch 2 (2026-09-10) — date-windowed tables, brought in unfiltered` section (same format as the batch 1 section) covering:
- Why the old date windows were dropped: Brian's own account that `RangeStart`/`RangeEnd` was an unfinished incremental-refresh attempt, not a deliberate scope decision; the discovery that six of the old filter columns (`ModifiedDate`) were 40-91% NULL, meaning the old dataflows were silently dropping most of the table regardless of age; and the architectural point that date-scoping belongs at Gold, not Silver, now that a shortcut removes any cost reason to filter early
- `WkVehFl`'s special case: no reliably-populated date column exists on this table at all (5 candidates checked, all 43-76% NULL)
- `WarClaim`'s two real `IS NOT NULL` filters, kept, with the real numbers (5,042 of 46,887 rows / 10.75% excluded, all missing `CLAIM_NO`, sample rows all `STATUS='U'`)
- The new standing practice: every notebook in this backend now proactively sets the ancient-datetime rebase-mode config, not just tables where a sentinel date was already confirmed
- Real casing corrections found and fixed (`VhStock`'s 7, `WkRoFile`'s 1, `WkVehFl`'s 1)
- Verification results (both scripts, all passing)
- `Invoice` explicitly excluded from this batch, called out for its own dedicated future work given its size (6.5M rows) and importance
- What's still deferred: `InHist_PmManage`/`WKRODESC` (real business-rule filters), the InMaster group (filed separately, see `project_nonjd_parts_order_tool_paused.md` in memory), Category B/C, any report repointing, gold-layer logic, refresh scheduling

- [ ] **Step 3: Mark these 10 tables done in the catalog doc, and flag Invoice**

In `docs/architecture/jd-bronze-raw-sources-catalog.md`, in the Category A table, add a "**Migrated 2026-09-10**" note next to each of the 10 migrated rows (`TechnicianInvoiceDetail`, `TechnicianPunchedDetail`, `VHSTOCK`/`VhStock`, `VhTrans`, `WKINVREG`/`WkInvReg`, `WKMECHWK`, `WKOTHSUB`, `WKROFILE`/`WkRoFile`, `WKVEHFL`/`WkVehFl`, `WarClaim`), matching batch 1's note style. Also add a note to the `Invoice` row explicitly flagging it as deliberately deferred for its own dedicated work (not forgotten, not blocked - a scale/importance decision).

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md docs/architecture/jd-bronze-raw-sources-catalog.md
git commit -m "Document raw sources batch 2: 10 tables shortcut + normalized, unfiltered

10 Category A tables (TechnicianInvoiceDetail, TechnicianPunchedDetail,
VhStock, VhTrans, WkInvReg, WKMECHWK, WKOTHSUB, WkRoFile, WkVehFl,
WarClaim) moved from ODBC-based LH_Master_Data dataflows onto OneLake
shortcuts + Silver notebooks - full history, no date filter (the old
RangeStart/RangeEnd windowing was an abandoned incremental-refresh
attempt, and on 6 tables was silently dropping most of the table via
a NULL-heavy filter column, not meaningfully bounding it by age).
WarClaim keeps its 2 real IS NOT NULL data-quality filters. New
standing practice: every notebook in this backend now proactively
sets the ancient-datetime Spark rebase config. Invoice (6.5M rows)
deliberately excluded, deferred to its own dedicated migration.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 16: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into `Invoice`, the InMaster group, `InHist_PmManage`/`WKRODESC`, the Technician-family view rebuild, or any report repointing as part of this plan** — those are each their own future decision, not implied by completing this one.
