# jdis_Part_Information Tiered Refresh — Bronze + Silver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the Active/Dead tiered-refresh pattern for `jdis_Part_Information` end to end — two bronze ingestions split by a 24-month activity definition, recombined into one logical silver table. First concrete step of a validated design, not the full `dim_Parts` rebuild.

**Architecture:** `jdis_Part_Information` has no change-tracking field at all, so full-refresh is structurally required regardless of tooling — but 73.2% of its ~1.1M rows are genuinely dormant (zero on-hand, zero sales in 24 months), confirmed by direct query this session. Splitting the source query itself into two WHERE-filtered pulls (Active ~298k rows, Dead ~813k rows) via two Dataflow Gen2 items lets the small, frequently-relevant slice refresh far more often than the large dormant majority, once refresh scheduling exists — this plan builds the two tiers and proves they recombine correctly, nothing more. `jdis_Part_Information`'s current 3x/day full refresh is already documented as the Fabric capacity's #3 CU consumer (`projects/shannon-report/CLAUDE.md`), so this directly targets a real, already-known cost problem.

**Tech Stack:** Fabric Dataflow Gen2 (portal-created, both bronze tiers — same ODBC full-pull mechanism already proven in production, just WHERE-filtered), PySpark (the silver recombination notebook), DuckDB + `pyodbc` for independent verification.

---

### Task 1: Bronze — Active tier Dataflow Gen2 ✅ DONE 2026-09-09

Refresh completed in 1:17 (vs. ~8 min for the full unfiltered table) — early confirmation the tiering approach reduces refresh time roughly in line with the row-count reduction.

**Files:** none (Fabric portal action — Dataflow Gen2 creation)

- [ ] **Step 1: Brian creates the Dataflow Gen2**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev`
2. **New item** → **Dataflow Gen2**
3. Name it `df_JDIS_PartInformation_Active_Raw`
4. In the Power Query editor, use the Advanced Editor to paste in the M code below, replacing whatever default query exists

```
let
    SQL =
    "SELECT #(lf)
        -- ===== CORE PARTS IDENTIFICATION ===== #(lf)
        pi_Branch AS Branch, #(lf)
        pi_Part_No AS PartNumber, #(lf)
        pi_Description AS Description, #(lf)
        pi_Franchise AS Franchise, #(lf)
        pi_Source AS Source, #(lf)
        pi_SLC AS SLC, #(lf)
        pi_Commodity_Code AS CommodityCode, #(lf)
        pi_Dealer_Group_Code AS DealerGroupCode, #(lf)

        -- ===== INVENTORY MANAGEMENT ===== #(lf)
        pi_On_Hand_Qty AS QuantityOnHand, #(lf)
        pi_Bin_Qty AS BinQty, #(lf)
        pi_Bulk_Bin_Qty AS BulkBinQty, #(lf)
        pi_Pending_Qty AS PendingQty, #(lf)
        pi_Back_Ord_Qty AS BackOrderQty, #(lf)
        pi_Bulk_Bin AS BulkBin, #(lf)
        pi_Bin AS Bin, #(lf)
        pi_Package_Qty AS PackageQty, #(lf)
        pi_Return_Indicator AS Returnable, #(lf)
        pi_Weight AS Weight, #(lf)
        pi_On_Order AS OnOrder, #(lf)

        -- ===== PART SUPERSESSION ===== #(lf)
        pi_Super_To AS SuperTo, #(lf)
        pi_Super_From AS SuperFrom, #(lf)

        -- ===== FINANCIAL DATA ===== #(lf)
        pi_Inventory_Cost AS InventoryCost, #(lf)
        pi_Cost AS Cost, #(lf)
        pi_Sell_Price_1_Master_File AS SellPrice1, #(lf)
        pi_List_Price_Master_File AS ListPrice, #(lf)
        pi_current_12_mo_sales AS Current12MoSales, #(lf)
        pi_current_12_dollars AS Current12MoDollars, #(lf)
        pi_previous_12_mo_sales AS Previous12MoSales, #(lf)
        pi_previous_12_dollars AS Previous12MoDollars, #(lf)

        -- ===== BUSINESS CONTEXT ===== #(lf)
        pi_Vendor_Code AS VendorCode, #(lf)

        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        pi_Date_Created AS DateCreated, #(lf)
        pi_Date_Last_Request AS DateLastRequested, #(lf)
        pi_Stocktake_Date AS StocktakeDate #(lf)

    FROM jdis_Part_Information #(lf)
    WHERE NOT (pi_On_Hand_Qty = 0 #(lf)
        AND (pi_current_12_mo_sales IS NULL OR pi_current_12_mo_sales = 0) #(lf)
        AND (pi_previous_12_mo_sales IS NULL OR pi_previous_12_mo_sales = 0))",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to JDIS_PART_INFORMATION (Active tier). Verify database connection and table availability."
in
    Source
```

This is the exact same 30-column SELECT/alias list as the existing production `jdis_Part_Information.pq` (`.claude/queries/raw-tables/jdis_Part_Information.pq` in `data-projects`) — only the `WHERE` clause is new, defining "Active" as the complement of the Dead definition below.

5. Move the item into the `Raw Data - Dataflows/` folder (matching the established convention)
6. Set the query's **Data destination** to the `DP_Staging` lakehouse (in `DP - Staging - Dev`), table name `PartInformation_Active`, table action **Replace**
7. **Publish**

- [ ] **Step 2: Brian runs it once**

Refresh manually to populate `DP_Staging.PartInformation_Active` for the first time.

---

### Task 2: Bronze — Dead tier Dataflow Gen2 ✅ DONE 2026-09-09

Refresh completed in 1:39 (813k rows, ~73% of the table) — barely slower than the Active tier's 1:17 despite far more rows, and both dramatically faster than the original ~8-minute full pull. Not a linear row-count relationship — likely because both new queries use an explicit 30-column SELECT vs. production's `pi.*`-style full-column pull, on top of whatever the row filtering itself contributes.

**Files:** none (Fabric portal action)

- [ ] **Step 1: Brian creates the second Dataflow Gen2**

Same process as Task 1:
1. In `DP - Staging - Dev`, **New item** → **Dataflow Gen2**, name it `df_JDIS_PartInformation_Dead_Raw`
2. Advanced Editor — paste the same M code as Task 1, but replace the `WHERE` clause (the exact complement — no `NOT`, same three conditions):

```
    FROM jdis_Part_Information #(lf)
    WHERE pi_On_Hand_Qty = 0 #(lf)
        AND (pi_current_12_mo_sales IS NULL OR pi_current_12_mo_sales = 0) #(lf)
        AND (pi_previous_12_mo_sales IS NULL OR pi_previous_12_mo_sales = 0)",

    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise
        error "Failed to connect to JDIS_PART_INFORMATION (Dead tier). Verify database connection and table availability."
```
(Everything above the `FROM jdis_Part_Information` line — the full column `SELECT` list — is identical to Task 1's query; only the `WHERE` and the error message text differ.)

3. Move into `Raw Data - Dataflows/`
4. Data destination: `DP_Staging` lakehouse, table name `PartInformation_Dead`, table action **Replace**
5. **Publish**

- [ ] **Step 2: Brian runs it once**

Refresh manually to populate `DP_Staging.PartInformation_Dead` for the first time.

---

### Task 3: Independently verify both bronze tiers ✅ DONE 2026-09-09

**Real finding, investigated properly rather than assumed:** first run found 2,215 "overlapping" rows using `(Branch, PartNumber)` as the key. Traced directly against real data (pulled every column for a live duplicate example): the true grain of `jdis_Part_Information` is `(Branch, PartNumber, Franchise)` — the same part number can be carried under multiple franchise codes at the same branch, each an independent inventory/cost/sales record. Confirmed via a new Check 2b that this corrected key is genuinely unique within each tier (0 duplicates in either). Corrected key drops the overlap to 5 rows (0.00045% of 1.1M), fully explained by the two dataflows being non-atomic point-in-time pulls against a live source ~2 minutes apart — a few rows can legitimately flip Active/Dead status in that window, same magnitude as Check 3's own 1-row live-count drift. Committed `e525ef99`. **Note for Task 4:** the Silver notebook's row-count assertion (combined == active + dead) still holds regardless of this — union doesn't dedupe, so these 5 rows will appear twice in `Silver_PartInformation` (once per tier). Acceptable for this proof-of-concept pass; not adding dedup complexity here.

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_partinformation_tiers.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP BRONZE PARTINFORMATION TIERS VERIFICATION
============================================================================
Confirms the Active/Dead split of jdis_Part_Information landed correctly:
both bronze tables are mutually exclusive, their combined row count matches
a fresh live count against EquipRDB directly (not assumed from an earlier
session), and the split is roughly in line with what was measured this
session (Active ~27%, Dead ~73%) - source data changes continuously, so an
exact match isn't expected, only a similar shape.

Run manually after Task 1 and Task 2 confirm both dataflows ran successfully.
============================================================================
"""

import duckdb
import pyodbc

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: bronze tier row counts ===")
active_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Active')").fetchone()[0]
dead_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Dead')").fetchone()[0]
combined = active_count + dead_count
print(f"Active: {active_count:,} ({active_count/combined*100:.1f}%)")
print(f"Dead: {dead_count:,} ({dead_count/combined*100:.1f}%)")
print(f"Combined: {combined:,}")
print("Expect roughly Active ~27%, Dead ~73% (measured this session: 298,349 / 813,379 of 1,111,728 total)")

print("\n=== Check 2: mutual exclusivity - no PartNumber+Branch appears in both tiers ===")
overlap = con.execute(f"""
    SELECT COUNT(*) FROM (
        SELECT Branch, PartNumber FROM delta_scan('{dp_base}/PartInformation_Active')
        INTERSECT
        SELECT Branch, PartNumber FROM delta_scan('{dp_base}/PartInformation_Dead')
    )
""").fetchone()[0]
print(f"Rows appearing in both tiers (expect 0): {overlap}")

print("\n=== Check 3: combined bronze total vs. a fresh live EquipRDB count ===")
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute("SELECT COUNT(*) FROM jdis_Part_Information")
live_total = cur.fetchone()[0]
print(f"Live EquipRDB total right now: {live_total:,}")
print(f"Bronze combined total: {combined:,}")
diff = abs(live_total - combined)
diff_pct = diff / live_total * 100
print(f"Difference: {diff:,} rows ({diff_pct:.2f}%) - expect small (source data changes continuously "
      f"between the dataflow runs and this check; a large gap would suggest a real problem, not drift)")
```

- [ ] **Step 2: Run it**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_shortcut_partinformation_tiers.py"
```
Expected: Check 1 shows a split close to 27%/73%, Check 2 shows 0 overlap, Check 3 shows a small (a few percent at most) difference between the bronze combined total and a fresh live count.

**If Check 2 shows any overlap, or Check 3 shows a large gap (more than a few percent): stop, investigate before proceeding to Task 4** — a real overlap means the two WHERE clauses aren't true complements (a logic bug), and a large total gap means something else is wrong beyond normal data drift.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_partinformation_tiers.py
git commit -m "Add jdis_Part_Information tiers verification script

Confirms the Active/Dead bronze split is mutually exclusive and its
combined total matches a fresh live EquipRDB count within normal data
drift.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Build `Build_Silver_PartInformation.Notebook` ✅ DONE 2026-09-09

**Real finding, root-caused properly:** first write attempt failed twice at the same task (Task 8, stage 44) with `TASK_WRITE_FAILED`. Not infrastructure flakiness (retrying blindly would not have fixed it) — the full stack trace revealed `SparkUpgradeException: [INCONSISTENT_BEHAVIOR_CROSS_VERSION.READ_ANCIENT_DATETIME]`. Root cause: `jdis_Part_Information` has genuine sentinel "never happened" dates (e.g. `DateLastRequested = 1900-01-01`, confirmed present in real source data) written into the bronze Parquet files by Dataflow Gen2's own writer — a different engine than native Spark, using a different calendar convention for dates before 1900-01-01 (SPARK-31404). Row counts succeeded first (metadata-only, no timestamp decoding needed) while the write failed (must fully materialize every column). Fixed by setting `spark.sql.parquet.datetimeRebaseModeInRead`/`datetimeRebaseModeInWrite` to `CORRECTED` — committed `d54c1b1d`. Re-run succeeded: 298,384 Active / 813,390 Dead rows, samples confirm the classification logic is correct (Active rows show real sales activity, Dead rows are all zeros).

**Files:**
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook/notebook-content.py`

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
    "displayName": "Build_Silver_PartInformation"
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

# Build_Silver_PartInformation
# Purpose: First concrete step of the tiered-refresh design for
# jdis_Part_Information, agreed with Brian 2026-09-09. Recombines the
# Active and Dead bronze tiers (PartInformation_Active, PartInformation_Dead
# - built by df_JDIS_PartInformation_Active_Raw / df_JDIS_PartInformation_
# Dead_Raw, two Dataflow Gen2 items in this same workspace) into one
# logical table - proving the tier-and-recombine pattern works end to end.
#
# Why tiered at all: jdis_Part_Information has no ModifiedDate/change-
# tracking field, so full-refresh is structurally required regardless of
# tooling - no incremental capture is possible against this source. Its
# current production refresh (3x/day, full ~1.1M-row pull, ~8 min each) is
# already documented as the Fabric capacity's #3 CU consumer (see
# projects/shannon-report/CLAUDE.md's "Refresh" section). Directly queried
# this session: 73.2% of the table (813,379 of 1,111,728 rows) is
# genuinely dormant by a reasonable 24-month definition (zero on-hand
# qty, zero sales in the trailing 24 months) - only 26.8% (298,349 rows)
# is "active." Splitting the source query itself into two WHERE-filtered
# pulls lets that small active slice eventually refresh far more often
# than the large dormant majority, once refresh scheduling exists for
# this backend (still the platform's biggest open gap - not built here).
#
# NOT in scope here: the full dim_Parts business-logic enrichment
# (promo/margin/supersession classification, dimension modeling) - that's
# a separate, substantial future project, same category as dim_CustomerList
# (dim_Parts already has its own open, deferred Spark-redesign ticket in
# project memory). This notebook produces a SILVER table - cleaned and
# combined, matching Silver_InTrans's role, not yet business-enriched.
# Also NOT in scope: any refresh schedule for either bronze dataflow (both
# are manually triggered for now) and periodic reclassification of which
# tier a part belongs to (not needed yet - since there's no schedule
# driving repeated runs, each manual run of either dataflow re-evaluates
# activity status fresh against live source data; reclassification only
# becomes a real design question once this runs on an actual asymmetric
# schedule).

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

# ActivityTier is derived from which bronze table the row came from, not
# recomputed here - the WHERE clause on each Dataflow Gen2 already did that
# classification at the source, against live data, at the time each tier
# was last refreshed.
active_df = spark.read.table("PartInformation_Active").withColumn("ActivityTier", F.lit("Active"))
dead_df = spark.read.table("PartInformation_Dead").withColumn("ActivityTier", F.lit("Dead"))

active_count = active_df.count()
dead_count = dead_df.count()
print(f"Active tier rows: {active_count:,}")
print(f"Dead tier rows: {dead_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Recombine - the actual proof this plan exists to establish. unionByName
# (not positional union) so a future column-order difference between the
# two bronze tables wouldn't silently misalign data.

combined = active_df.unionByName(dead_df)

combined_count = combined.count()
print(f"Combined rows: {combined_count:,}")
assert combined_count == active_count + dead_count, (
    f"Row count mismatch after union ({active_count:,} + {dead_count:,} = "
    f"{active_count + dead_count:,}, but got {combined_count:,}) - the union "
    f"should never add or drop rows from a plain concatenation of two "
    f"already-independent tables."
)
print("Combined row count matches Active + Dead exactly - union did not add or drop rows.")

combined.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Silver_PartInformation")

print("Silver build complete: Silver_PartInformation written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof
# (that's the independent DuckDB script). Confirms the ActivityTier
# breakdown matches what was written, and spot-checks a few real rows from
# each tier.

tier_breakdown = spark.sql("""
    SELECT ActivityTier, COUNT(*) AS RowCount
    FROM delta.`Tables/Silver_PartInformation`
    GROUP BY ActivityTier
    ORDER BY ActivityTier
""").toPandas()
print("ActivityTier breakdown:")
print(tier_breakdown.to_string())

sample_active = spark.sql("""
    SELECT Branch, PartNumber, QuantityOnHand, Current12MoSales, Previous12MoSales, ActivityTier
    FROM delta.`Tables/Silver_PartInformation`
    WHERE ActivityTier = 'Active'
    LIMIT 3
""").toPandas()
print("\nSample Active rows (expect at least one of QuantityOnHand/Current12MoSales/Previous12MoSales nonzero):")
print(sample_active.to_string())

sample_dead = spark.sql("""
    SELECT Branch, PartNumber, QuantityOnHand, Current12MoSales, Previous12MoSales, ActivityTier
    FROM delta.`Tables/Silver_PartInformation`
    WHERE ActivityTier = 'Dead'
    LIMIT 3
""").toPandas()
print("\nSample Dead rows (expect QuantityOnHand=0, Current12MoSales and Previous12MoSales both 0 or null):")
print(sample_dead.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 4: Verify before committing**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status --short
```
Expect exactly 2 new untracked files under `workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook/`. If anything else shows as modified/untracked (e.g. local Desktop artifact noise), STOP and report BLOCKED rather than committing.

- [ ] **Step 5: Commit and push**

```bash
git add "workspaces/DP - Staging - Dev/Data Notebooks/Build_Silver_PartInformation.Notebook"
git commit -m "Add Build_Silver_PartInformation notebook

First concrete step of the tiered-refresh design for
jdis_Part_Information: recombines the Active/Dead bronze tiers into
one logical silver table, proving the tier-and-recombine pattern
works. Not the full dim_Parts business-logic enrichment - that stays
deferred as its own future project. No refresh schedule built here
either - both bronze dataflows are manually triggered for now.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git log --oneline HEAD..origin/dev
```
If the last command shows any commits, report NEEDS_CONTEXT rather than pushing/rebasing yourself. Otherwise:
```bash
git push origin dev
```

- [ ] **Step 6: Brian confirms Dev picked up the notebook and runs it**

`DP - Staging - Dev` → Source control → **Update all**. Open `Build_Silver_PartInformation.Notebook` (in `Data Notebooks/`) and run all cells.

- [ ] **Step 7: Report back the notebook's own output**

Active/Dead row counts, the combined count assertion result, the `ActivityTier` breakdown, and the sample rows from each tier.

---

### Task 5: Independently verify `Silver_PartInformation` ✅ DONE 2026-09-09

All checks pass: combined row count matches bronze sum exactly (1,111,774), ActivityTier breakdown matches, 0 rows where classification contradicts the underlying activity data.

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_partinformation.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP SILVER PARTINFORMATION VERIFICATION
============================================================================
Independent check of Silver_PartInformation (built by
Build_Silver_PartInformation.Notebook) - confirms the combined row count
equals the sum of the two bronze tiers exactly (no loss or duplication
across the union), and that ActivityTier classification is internally
consistent with the underlying QuantityOnHand/sales columns.

Run manually after Task 4 confirms the notebook ran successfully.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: combined row count matches the sum of the two bronze tiers exactly ===")
active_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Active')").fetchone()[0]
dead_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/PartInformation_Dead')").fetchone()[0]
silver_count = con.execute(f"SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_PartInformation')").fetchone()[0]
print(f"Bronze Active: {active_count:,}")
print(f"Bronze Dead: {dead_count:,}")
print(f"Bronze sum: {active_count + dead_count:,}")
print(f"Silver combined: {silver_count:,}")
print(f"Match: {silver_count == active_count + dead_count}")

print("\n=== Check 2: ActivityTier breakdown ===")
breakdown = con.execute(f"""
    SELECT ActivityTier, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/Silver_PartInformation')
    GROUP BY ActivityTier
    ORDER BY ActivityTier
""").df()
print(breakdown.to_string())

print("\n=== Check 3: ActivityTier is internally consistent with the underlying data ===")
inconsistent = con.execute(f"""
    SELECT COUNT(*) FROM delta_scan('{dp_base}/Silver_PartInformation')
    WHERE (ActivityTier = 'Dead' AND NOT (
              (QuantityOnHand = 0 OR QuantityOnHand IS NULL)
              AND (Current12MoSales IS NULL OR Current12MoSales = 0)
              AND (Previous12MoSales IS NULL OR Previous12MoSales = 0)
          ))
       OR (ActivityTier = 'Active' AND (
              (QuantityOnHand = 0 OR QuantityOnHand IS NULL)
              AND (Current12MoSales IS NULL OR Current12MoSales = 0)
              AND (Previous12MoSales IS NULL OR Previous12MoSales = 0)
          ))
""").fetchone()[0]
print(f"Rows where ActivityTier contradicts the underlying activity data (expect 0): {inconsistent}")
```

- [ ] **Step 2: Run it**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_silver_partinformation.py"
```
Expected: Check 1 shows `Match: True`, Check 2 shows a breakdown roughly matching the bronze tier counts, Check 3 shows 0 inconsistent rows.

**If any check fails: stop, investigate before proceeding to Task 6.**

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_partinformation.py
git commit -m "Add Silver_PartInformation verification script

Confirms the combined row count matches the sum of the two bronze
tiers exactly, and that ActivityTier classification is internally
consistent with the underlying on-hand/sales data.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Update the reference doc ✅ DONE 2026-09-09 (`5534f5d7`)

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Add the new tables to the Lakehouses section**

Add to the existing `DP_Staging` row's Contents: `Tables/PartInformation_Active`, `Tables/PartInformation_Dead` (Dataflow Gen2 ingestions, direct EquipRDB ODBC pulls split by a 24-month activity WHERE clause — not JD Bronze shortcuts, since `jdis_Part_Information` isn't in JD's mirror at all, almost certainly for the same volatility reason it's excluded from any change-tracking-based replication). `Tables/Silver_PartInformation` — the recombined logical table, built by `Build_Silver_PartInformation.Notebook` (`Data Notebooks/` folder).

- [ ] **Step 2: Add a new section**

```markdown
## jdis_Part_Information tiered refresh (2026-09-09) — first step of a larger design

`jdis_Part_Information` has no `ModifiedDate`/change-tracking field at all, so full
refresh is structurally required regardless of tooling. Its current production refresh
(3x/day, full ~1.1M-row pull, ~8 min each) is already documented as the Fabric
capacity's **#3 CU consumer** (`projects/shannon-report/CLAUDE.md`'s "Refresh" section).
It's also not in JD's Bronze mirror — almost certainly the same volatility reason it has
no change-tracking field to begin with.

**The idea, validated with real numbers before building anything** (queried directly
against `EquipRDB` 2026-09-09): of 1,111,728 total rows, **73.2% (813,379) are
genuinely dormant** by a reasonable 24-month definition (zero on-hand quantity, zero
sales in the trailing 24 months) — only **26.8% (298,349) is "active."** That active
slice is close in scale to Shannon's own "Aftermarket - Parts Orders" report (a
completely separate, non-shared-pipeline tool), which proved a 202,262-row filtered
query against this same source refreshes in **33 seconds** — strong evidence the active
tier here could refresh far more often than the dormant majority, once refresh
scheduling exists for this backend.

**This plan (`docs/superpowers/plans/2026-09-09-dp-parts-information-tiered-refresh.md`)
proves the tier-and-recombine pattern only** — two Dataflow Gen2 bronze ingestions
(`df_JDIS_PartInformation_Active_Raw` / `df_JDIS_PartInformation_Dead_Raw`, WHERE-split
by the 24-month definition) recombined by `Build_Silver_PartInformation.Notebook` into
one logical `Silver_PartInformation` table. Verified: combined row count matches the sum
of the two tiers exactly, `ActivityTier` classification is internally consistent with
the underlying on-hand/sales data.

**Explicitly deferred, not part of this step:**
- The actual `dim_Parts` gold business-logic enrichment (promo/margin/supersession
  classification) — a separate, substantial future project, same category as
  `dim_CustomerList` (already has its own open, deferred Spark-redesign ticket in
  project memory).
- Any refresh schedule/cadence for either bronze dataflow — both are manually triggered
  for now, same as every other piece of this backend before scheduling exists (still the
  platform's biggest open gap).
- Periodic reclassification of which tier a part belongs to — not needed yet, since
  there's no schedule driving repeated runs at different cadences; each manual run
  re-evaluates activity status fresh against live source data. This becomes a real
  design question once an asymmetric schedule (Active hourly, Dead daily/weekly) exists.
```

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record jdis_Part_Information tiered refresh (bronze + silver)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 7: Final end-to-end check

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

**Do not extend this into the full `dim_Parts` rebuild, a refresh schedule, or Prod tier as part of this plan** — those are each their own future decision, not implied by completing this one.
