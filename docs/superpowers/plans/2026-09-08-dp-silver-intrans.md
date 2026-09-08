# DP Silver InTrans Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the silver-layer `Silver_InTrans` Delta table in `DP_Staging` (the `DP - Staging - Dev` lakehouse from Plan 2), sourced from the `InTrans` bronze shortcut, using a PK-based merge/upsert instead of an append-plus-watermark — the specific design change that makes the original Parts Promo bug structurally impossible to repeat.

**Architecture:** One Fabric Notebook (`Build_Silver_InTrans`, PySpark), reading `InTrans` (the shortcut), selecting and renaming just the columns Parts Promo's rebuild actually needs (Plan 4), deduplicating by `trans_id` (the confirmed true primary key), and writing to `Silver_InTrans` via `MERGE ... ON TransId` (create-with-full-load on first run, since the target doesn't exist yet; upsert on every subsequent run). Scoped to the same 11 columns `dim_RepairOrder`/`Fact_PartsPromo` actually use, not all 66 raw `InTrans` columns — same YAGNI reasoning as Plan 2's shortcut being `InTrans`-only.

**Tech Stack:** PySpark (Fabric notebook, `synapse_pyspark` kernel), authored directly as git-tracked files (this is how every other notebook in this tenant is already managed — see `workspaces/LH_Master_Data/Notebooks/*.Notebook/notebook-content.py` in `fabric-workspace-docs` for the established format this plan follows exactly).

**Known execution pattern (established in Plans 1-2):** file writes and git commits in the `fabric-workspace-docs`/`data-projects` repos are agent-executable; anything that mutates live Fabric tenant state directly (running the notebook, syncing a workspace from git) needs Brian. This plan authors the notebook as git-tracked files — a first for this program — so *writing* the notebook is agent-executable even though *running* it isn't.

---

### Task 1: Author the `Build_Silver_InTrans` notebook

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Staging - Dev\Build_Silver_InTrans.Notebook\.platform`
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Staging - Dev\Build_Silver_InTrans.Notebook\notebook-content.py`

- [ ] **Step 1: Write the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Silver_InTrans"
  },
  "config": {
    "version": "2.0",
    "logicalId": "9ce21a34-dbd0-4baa-9ba1-627c6d396c3c"
  }
}
```

- [ ] **Step 2: Write the notebook content**

Exact format matches every other notebook already in this tenant (`# Fabric notebook source` header, `# METADATA`/`# CELL` block structure) — do not deviate from this structure, Fabric's git sync parses it exactly.

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

# Build_Silver_InTrans
# Purpose: Build the silver-layer InTrans table from the bronze shortcut,
# using a PK-based (TransId) merge/upsert — not an append-plus-watermark.
#
# This is the direct fix for the root cause documented in
# docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md:
# the old df_InTrans_Incremental dataflow used `WHERE Trans_Datetime > watermark`
# with the watermark set to MAX(TransDatetime) already loaded. A row that
# committed to the source *after* a later-timestamped row had already advanced
# the watermark was permanently excluded. Keying this build off TransId with
# MERGE instead makes that failure mode structurally impossible: a re-run
# converges to the correct state regardless of commit order, it never
# permanently drops a row.
#
# Columns are scoped to exactly what dim_RepairOrder and Fact_PartsPromo need
# (Plan 4) — not all 66 raw InTrans columns. Expand later if another report
# needs more.

print("=" * 80)
print("BUILD_SILVER_INTRANS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql.functions import col

df_source = spark.read.table("InTrans")

silver_df = (
    df_source
    .select(
        col("trans_id").alias("TransId"),
        col("BRANCH").alias("Branch"),
        col("REF_NO").alias("RONumber"),
        col("PART_NO").alias("PartNumber"),
        col("Trans_Datetime").alias("TransDatetime"),
        col("customer_no").alias("CustomerNo"),
        col("FRANCHISE").alias("Franchise"),
        col("TYPE").alias("Type"),
        col("DESCRIPTION").alias("Description"),
        col("QTY").alias("Qty"),
        col("SALE_VAL").alias("SaleValue"),
        col("COST_VAL").alias("CostValue"),
    )
    .dropDuplicates(["TransId"])
)

staged_count = silver_df.count()
print(f"Staged row count (post-dedupe by TransId): {staged_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from delta.tables import DeltaTable

TARGET_TABLE = "Silver_InTrans"

if spark.catalog.tableExists(TARGET_TABLE):
    print(f"{TARGET_TABLE} exists — running MERGE (upsert by TransId)")
    target = DeltaTable.forName(spark, TARGET_TABLE)
    (
        target.alias("t")
        .merge(silver_df.alias("s"), "t.TransId = s.TransId")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute()
    )
else:
    print(f"{TARGET_TABLE} does not exist — creating with full initial load")
    silver_df.write.format("delta").mode("overwrite").saveAsTable(TARGET_TABLE)

print("Silver InTrans build complete.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification — run this cell every time and read the output before
# trusting the build. Three checks: total row count, zero duplicate
# TransId groups, and the RO 1985073 spot check (expect exactly 9 rows,
# matching the printed invoice — see the design spec for why this
# specific order matters).

result_count = spark.sql(f"SELECT COUNT(*) AS cnt FROM {TARGET_TABLE}").collect()[0]["cnt"]
dup_groups = spark.sql(f"""
    SELECT TransId, COUNT(*) AS cnt
    FROM {TARGET_TABLE}
    GROUP BY TransId
    HAVING COUNT(*) > 1
""").count()
ro_check = spark.sql(f"""
    SELECT Branch, Franchise, RONumber, PartNumber, TransDatetime, SaleValue
    FROM {TARGET_TABLE}
    WHERE RONumber = '1985073'
    ORDER BY TransDatetime
""").toPandas()

print(f"Total rows in {TARGET_TABLE}: {result_count:,}")
print(f"Duplicate TransId groups found: {dup_groups} (expect 0)")
print(f"RO 1985073 row count: {len(ro_check)} (expect 9)")
print(ro_check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit both files**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Staging - Dev/Build_Silver_InTrans.Notebook"
git commit -m "Add Build_Silver_InTrans notebook

PK-based (TransId) merge/upsert silver build for InTrans, replacing
the watermark-based approach that caused the original Parts Promo
bug. Scoped to the 11 columns dim_RepairOrder/Fact_PartsPromo need.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

If the push is blocked by the sandbox classifier (same pattern as before), hand it to Brian to run directly.

---

### Task 2: Sync and run the notebook

**Files:** none (Fabric portal action — this is Brian's)

- [ ] **Step 1: Pull the notebook into the workspace**

In the Fabric portal: open `DP - Staging - Dev` → **Source control** → there should be 1 pending update (`Build_Silver_InTrans`). Click **Update all** (safe this time — we know exactly what's incoming, unlike the Plan 1 git-folder incident, because this workspace's git folder is correctly scoped and this is the only pending item).

- [ ] **Step 2: Open and run the notebook**

Open `Build_Silver_InTrans` in the workspace. Run all cells in order (Run All, or cell-by-cell — either is fine). This is a first-time full build of ~20.6M rows through Spark, so expect it to take a few minutes, not seconds.

- [ ] **Step 3: Read the output of the last cell**

Report back what it printed — specifically the three verification lines (total row count, duplicate TransId groups, RO 1985073 row count). Expect roughly 20.6M total rows, 0 duplicate groups, and 9 rows for RO 1985073.

---

### Task 3: Independent verification (agent-executed)

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans.py`

- [ ] **Step 1: Write the verification script**

```python
"""
DP SILVER INTRANS VERIFICATION
============================================================================
Independent check of Silver_InTrans (built by Build_Silver_InTrans.Notebook,
Plan 3) against the bronze shortcut it was built from — confirms the silver
build didn't lose or duplicate rows, and that RO 1985073 (the case that
proved the original bug) still resolves correctly one layer downstream.

Run manually after Task 2 confirms the notebook ran successfully.
============================================================================
"""

import duckdb

DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"   # DP - Staging - Dev workspace
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"   # DP_Staging lakehouse
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row counts, bronze shortcut vs. silver table ===")
bronze_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/InTrans')").df()
silver_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/Silver_InTrans')").df()
print(f"Bronze (InTrans) row count: {bronze_count['cnt'][0]:,}")
print(f"Silver (Silver_InTrans) row count: {silver_count['cnt'][0]:,}")
print("(Silver may be slightly lower if bronze has any exact-duplicate TransId rows — that's expected and correct, not a bug)")

print("\n=== Check 2: no duplicate TransId in silver ===")
dupes = con.execute(f"""
    SELECT TransId, COUNT(*) AS cnt
    FROM delta_scan('{dp_base}/Silver_InTrans')
    GROUP BY TransId
    HAVING COUNT(*) > 1
""").df()
print(f"Duplicate TransId groups: {len(dupes)} (expect 0)")

print("\n=== Check 3: RO 1985073 through silver ===")
ro_check = con.execute(f"""
    SELECT Branch, Franchise, RONumber, PartNumber, TransDatetime, SaleValue
    FROM delta_scan('{dp_base}/Silver_InTrans')
    WHERE RONumber = '1985073'
    ORDER BY TransDatetime
""").df()
print(ro_check.to_string())
print(f"\nRow count for RO 1985073 in silver: {len(ro_check)} (expect 9)")
```

- [ ] **Step 2: Run it**

```
export PATH="$HOME/.local/bin:$PATH"
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python ".claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans.py"
```

Expected: Check 1 shows silver's count equal to (or very marginally below, if any true duplicates existed) bronze's count; Check 2 shows 0 duplicate groups; Check 3 shows exactly 9 rows for RO 1985073.

**If Check 2 finds duplicate groups, or Check 3 doesn't show 9 rows:** stop, do not proceed to Task 4 — the merge logic or the dedupe step has a real bug that needs fixing before anything gets built on top of this table.

- [ ] **Step 3: Commit the verification script**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_silver_intrans.py
git commit -m "Add Silver_InTrans verification script

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Update the reference doc

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Add the Silver_InTrans table to the Lakehouses section**

Add a row (or sub-note under the existing `DP_Staging` row) documenting `Silver_InTrans`: built by `Build_Silver_InTrans.Notebook`, PK-merge on `TransId`, verified row count and RO 1985073 check as of the date this plan is executed.

- [ ] **Step 2: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record Silver_InTrans table

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```
