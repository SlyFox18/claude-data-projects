# Parts Adjustments — DP Gold Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Parts Adjustments (`Fact_PartsAdjustments`) off `LH_Master_Data`/`InTrans_Incremental` onto the new JD Bronze data platform — the second report migrated, using the exact process proven on Parts Promo. Dev tier only; Prod tier and Sandbox/Production promotion are explicitly follow-on plans.

**Architecture:** Reuses the already-built, already-verified `Silver_InTrans` (no new silver-layer work needed for the InTrans side — it was deliberately widened to full column parity for exactly this reason). Adds one new bronze source (`GlTrans`, via the same "shortcuts, not copies" pattern) and one new gold notebook (`Build_Gold_PartsAdjustments.Notebook`) that joins the two, replicating the current production business logic exactly — plus fixing one confirmed, unrelated bug (`LoadedDatetime` using `DateTime.LocalNow()`, which returns UTC in the Fabric service, not actual local time) while rebuilding this table anyway.

**Tech Stack:** Microsoft Fabric CLI (`fab`) for lakehouse/shortcut creation, Fabric portal for git-only operations (git connect, running notebooks — no verified CLI syntax for either), PySpark for the gold notebook, DuckDB + `pyodbc`/`dsn=EquipRDB64` for independent verification.

**Known execution pattern (established across this whole plan series):** every mutating `fab`/git-push command gets auto-blocked by this session's sandbox classifier — hand these to Brian directly, don't retry or work around. Agent handles file edits, git commits/verification, and DuckDB/pyodbc checks.

---

### Task 1: Migrate Parts Adjustments' report-layer git tracking into `RP - Dev`

**Files:** none yet (this task lands the report in `fabric-workspace-docs` for the first time — same gap Parts Promo had before its own migration, confirmed via `find` this session)

- [ ] **Step 1: Brian publishes the current Desktop copy to `RP - Dev`**

Open `data-projects/projects/parts adjustments - report/reports/current/Parts Adjustments.pbix` (or the current live Desktop file for this report) in Power BI Desktop. **Publish** → select workspace **`RP - Dev`**.

- [ ] **Step 2: Brian commits via Fabric Git Integration**

In the Fabric portal: `RP - Dev` → **Source control** → **Commit**. This pushes the report + semantic model definition to `fabric-workspace-docs` on the `dev` branch, under `workspaces/RP - Dev/`.

- [ ] **Step 3: Verify it landed (agent-executed)**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git status --short
```
If this shows unrelated local Desktop artifact noise mixed in (a recurring pattern all session — visual position jitter, schema-version bumps, `.pbip` trailing-newline drift), stash it non-destructively first: `git stash push -u -m "local Desktop artifacts before Parts Adjustments pull"`. Never use a destructive discard here.

```bash
git pull origin dev
find "workspaces/RP - Dev" -maxdepth 1 -iname "*Parts Adjustments*"
```
Expected: both `Parts Adjustments.Report` and `Parts Adjustments.SemanticModel` folders present.

- [ ] **Step 4: Check for and fix the missing `.pbip` file (agent-executed)**

```bash
find "workspaces/RP - Dev" -maxdepth 1 -iname "*Parts Adjustments*.pbip"
```
If empty (expected — every report workspace touched this session had this gap), create it:

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Parts Adjustments.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```
Save to `workspaces/RP - Dev/Parts Adjustments.pbip`.

- [ ] **Step 5: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/RP - Dev/Parts Adjustments.pbip"
git commit -m "Add missing Parts Adjustments.pbip for RP - Dev

Same gap Parts Promo had before its own migration - Fabric git
integration doesn't generate the Desktop .pbip project-marker file
on its own.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: Bronze — add the `GlTrans` OneLake shortcut to `DP_Staging` (Dev)

**Files:** none (Fabric portal action)

- [ ] **Step 1: Brian creates the shortcut**

In the Fabric portal:
1. Open workspace `DP - Staging - Dev` → lakehouse `DP_Staging`
2. **Tables** → **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `JD_FabricOneLake` → lakehouse `JD_EquipRDB_Production_Bronze` → **Tables** → select `GlTrans`
4. Keep the name `GlTrans`
5. **Create**

- [ ] **Step 2: Confirm it appears**

Report back once `GlTrans` shows in `DP_Staging`'s Tables list with a shortcut icon.

- [ ] **Step 3: Write and run the verification script (agent-executed)**

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_gltrans.py`

```python
"""
DP BRONZE SHORTCUT VERIFICATION - GlTrans
============================================================================
Confirms the DP_Staging.GlTrans OneLake shortcut (created in this plan's
Task 2) is a complete, accurate zero-copy reference to
JD_EquipRDB_Production_Bronze.GlTrans - not a partial or stale copy.

Unlike InTrans, GlTrans's current LH_Master_Data ingestion (df_GlTrans_Raw.
Dataflow) is a small, fully-filtered, FULL REFRESH pull (DEPT=30, ACCT=480,
since 2023-01-01) via a direct ODBC SQL query - not an incremental/watermark
pipeline, so it doesn't carry the same class of bug InTrans_Incremental had.
This check still confirms the shortcut itself is complete and current.

Run manually - not part of any scheduled pipeline.
============================================================================
"""

import duckdb

JD_WS_ID = "4bd21b07-f4ce-4b28-b0f1-0397fb5d5ea9"      # JD_FabricOneLake workspace
JD_LH_ID = "7348c3a6-8694-4d11-bc70-1bd55be84ea2"      # JD_EquipRDB_Production_Bronze lakehouse
jd_base = f"abfss://{JD_WS_ID}@onelake.dfs.fabric.microsoft.com/{JD_LH_ID}/Tables"

# Fill in after Task 2, Step 1 - get the DP_Staging (Dev) lakehouse ID via:
#   fab get "DP - Staging - Dev.Workspace/DP_Staging.Lakehouse" -q "id"
# (already known: 876255e0-d462-4697-adc1-4a655f5bb101, workspace
# ab15d64d-c7ba-415d-9bcf-7feb1ef9b201 - these are unchanged from Plan 2)
DP_STAGING_WS_ID = "ab15d64d-c7ba-415d-9bcf-7feb1ef9b201"
DP_STAGING_LH_ID = "876255e0-d462-4697-adc1-4a655f5bb101"
dp_base = f"abfss://{DP_STAGING_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_STAGING_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

print("=== Check 1: row count, JD source vs. DP shortcut ===")
jd_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{jd_base}/GlTrans')").df()
dp_count = con.execute(f"SELECT COUNT(*) AS cnt FROM delta_scan('{dp_base}/GlTrans')").df()
print(f"JD Bronze direct: {jd_count['cnt'][0]:,}")
print(f"DP_Staging shortcut: {dp_count['cnt'][0]:,}")
print(f"Match: {jd_count['cnt'][0] == dp_count['cnt'][0]}")

print("\n=== Check 2: sample of Parts Adjustments-scoped rows through the shortcut ===")
sample = con.execute(f"""
    SELECT trans_id, DOC_REF, SUB_ACCT, GLTRANS_DATE, BRANCH
    FROM delta_scan('{dp_base}/GlTrans')
    WHERE DEPT = 30 AND ACCT = 480 AND GLTRANS_DATE >= '2023-01-01'
    ORDER BY GLTRANS_DATE DESC
    LIMIT 5
""").df()
print(sample.to_string())
print(f"\nRows found in Parts-Adjustments scope (DEPT=30, ACCT=480, since 2023-01-01): "
      f"{con.execute(f\"SELECT COUNT(*) FROM delta_scan('{dp_base}/GlTrans') WHERE DEPT = 30 AND ACCT = 480 AND GLTRANS_DATE >= '2023-01-01'\").fetchone()[0]:,}")
```

Run:
```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_shortcut_gltrans.py"
```
Expected: row counts match exactly between JD source and the shortcut, and Check 2 returns a non-empty, sensible-looking sample (recent dates, SUB_ACCT values in the 1-6 range).

**If row counts don't match: stop, do not proceed to Task 3.**

- [ ] **Step 4: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_shortcut_gltrans.py
git commit -m "Add DP bronze GlTrans shortcut verification script

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Add the `GlTrans` shortcut to `DP_Presentation` (Dev)

**Files:** none (Fabric portal action)

Same cross-workspace "shortcuts, not copies" pattern already used for `Silver_InTrans` (see `docs/architecture/data-platform-workspaces.md`). GlTrans doesn't need its own silver-layer notebook — unlike InTrans, it has no PK-reuse problem to resolve (its current dedup is a simple "one row per DocRef" collapse, not a genuine primary-key conflict), so the filter/dedup logic lives directly in the gold notebook instead of a dedicated silver build. This is a deliberate scope decision: if a second consumer ever needs cleaned GlTrans, promote this into a real silver table then — not before.

- [ ] **Step 1: Brian creates the shortcut**

In the Fabric portal:
1. Open workspace `DP - Presentation - Dev` → lakehouse `DP_Presentation`
2. **Tables** → **...** → **New table shortcut** → **Microsoft OneLake**
3. Browse to: workspace `DP - Staging - Dev` → lakehouse `DP_Staging` → **Tables** → select `GlTrans`
4. Keep the name `GlTrans`
5. **Create**

- [ ] **Step 2: Confirm it appears and matches the direct source (agent-executed)**

Report back once visible, then run:
```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python -c "
import duckdb
con = duckdb.connect()
con.execute(\"INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;\")
con.execute(\"CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');\")
staging = con.execute(\"SELECT COUNT(*) FROM delta_scan('abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/GlTrans')\").fetchone()[0]
presentation = con.execute(\"SELECT COUNT(*) FROM delta_scan('abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables/GlTrans')\").fetchone()[0]
print(f'Staging direct: {staging:,}')
print(f'Presentation shortcut: {presentation:,}')
print(f'Match: {staging == presentation}')
"
```
Expected: `Match: True`.

---

### Task 4: Build `Build_Gold_PartsAdjustments.Notebook`

**Files:**
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_PartsAdjustments.Notebook/.platform` (in `fabric-workspace-docs`)
- Create: `workspaces/DP - Presentation - Dev/Build_Gold_PartsAdjustments.Notebook/notebook-content.py`

- [ ] **Step 1: Create the `.platform` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_PartsAdjustments"
  },
  "config": {
    "version": "2.0",
    "logicalId": "b89b0f9d-ebf0-429b-9b41-6b8230814891"
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

# Build_Gold_PartsAdjustments
# Purpose: Build Fact_PartsAdjustments from Silver_InTrans + GlTrans,
# reproducing the exact business logic of the existing production table
# (df_Fact_PartsAdjustments.Dataflow in LH_Master_Data), sourced from the
# new corrected backend instead of the buggy InTrans_Incremental.
#
# Business rules (unchanged from production):
# - Scope: InTrans rows with Type = 'A' (adjustments) since 2023-01-01,
#   LEFT JOINed to GlTrans rows with Department = 30 (Parts) and
#   Account = 480 (Parts Adjustments) since 2023-01-01, on
#   InTrans.RONumber = GlTrans.DocRef. GlTrans is deduplicated to one row
#   per DocRef before the join (a genuine one-to-many source relationship,
#   not a bug to fix - a document reference can have multiple GL lines,
#   and only one is needed for PAType classification).
# - PAType is derived from GlTrans.SubAccount: 1=Stock Check,
#   2=Customer BIN, 3=Damaged, 4=Lost, 5=Overage, 6=Count Off, anything
#   else (including no GlTrans match at all) = Unknown.
# - PositiveQty/NegativeQty/PositiveCost/NegativeCost split Qty/CostValue
#   by sign (the non-matching sign is 0, not null). AbsQty/AbsCost are
#   absolute values. IsPositiveQty/IsNegativeQty are boolean flags.
#
# Sourced from Silver_InTrans (already deduped, PK-correct - see
# Build_Silver_InTrans.Notebook in DP - Staging - Dev) via the
# Silver_InTrans OneLake shortcut already present in this lakehouse
# (added for Build_Gold_PartsPromo.Notebook, same shortcut reused here -
# no per-notebook duplication needed). GlTrans comes from a new shortcut
# added in this plan's Task 3 - unlike InTrans, GlTrans's current
# LH_Master_Data ingestion (df_GlTrans_Raw.Dataflow) is already a
# fully-filtered, full-refresh SQL pull, not an incremental/watermark
# pipeline, so it doesn't carry the same class of bug - this migration is
# about consistency and narrowing LH_Master_Data, not a known correctness
# fix on the GlTrans side specifically.
#
# One real, unrelated bug fixed while rebuilding this table: the
# production LoadedDatetime column used DateTime.LocalNow(), which
# returns UTC in the Fabric service, not actual local time (the exact
# pattern already documented and fixed elsewhere - see project memory
# feedback on the Data Refresh Table UTC bug, fixed 2026-02-27). Fixed
# here via an explicit UTC-to-Central conversion instead of a naive
# current timestamp.

print("=" * 80)
print("BUILD_GOLD_PARTSADJUSTMENTS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.window import Window

INTRANS_START_DATE = "2023-01-01"

# InTrans side: same scope as current production (Type = 'A', since
# 2023-01-01), read from the already-deduped, already-verified
# Silver_InTrans via the existing cross-workspace shortcut.
intrans_adjustments = (
    spark.read.table("Silver_InTrans")
    .filter(F.col("TransDatetime") >= INTRANS_START_DATE)
    .filter(F.col("Type") == "A")
    .select(
        "TransId", "RONumber", "TransDatetime", "Branch", "PartNumber",
        F.col("Description").alias("PartDescription"),
        "Franchise", "Type", "Qty", "CostValue", "SellPrice1",
        "Salesman", "CustomerNo", "Comments", "ModifiedDate",
    )
)

intrans_count = intrans_adjustments.count()
print(f"InTrans adjustment rows loaded (Type='A', >= {INTRANS_START_DATE}): {intrans_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

GLTRANS_START_DATE = "2023-01-01"

# GlTrans side: raw JD Bronze mirror has unfiltered EquipRDB column names
# and DECIMAL(38,18) types for DEPT/ACCT/SUB_ACCT - cast and filter to
# the same scope the current production raw ingestion (df_GlTrans_Raw.
# Dataflow) already applies (Dept=30 Parts, Acct=480 Parts Adjustments),
# then deduplicate to one row per DocRef. Unlike the old Power Query
# List.First (arbitrary row order), this uses a deterministic
# Window/row_number keyed on ascending TransId - a real (minor)
# correctness improvement, not just a like-for-like port.
gltrans_filtered = (
    spark.read.table("GlTrans")
    .withColumn("Department", F.col("DEPT").cast("int"))
    .withColumn("Account", F.col("ACCT").cast("int"))
    .filter((F.col("Department") == 30) & (F.col("Account") == 480))
    .filter(F.col("GLTRANS_DATE") >= GLTRANS_START_DATE)
    .select(
        F.col("trans_id").cast("bigint").alias("GLTransId"),
        F.col("DOC_REF").alias("DocRef"),
        F.col("SUB_ACCT").cast("int").alias("SubAccount"),
        F.col("GLTRANS_DATE").cast("timestamp").alias("GLTransDate"),
    )
)

dedup_window = Window.partitionBy("DocRef").orderBy(F.col("GLTransId").asc())
gltrans_deduped = (
    gltrans_filtered
    .withColumn("_rn", F.row_number().over(dedup_window))
    .filter(F.col("_rn") == 1)
    .drop("_rn", "GLTransId")
)

gltrans_count = gltrans_deduped.count()
print(f"GlTrans rows loaded (Dept=30, Acct=480, >= {GLTRANS_START_DATE}, deduped to one per DocRef): {gltrans_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Join, classify, and compute derived columns.
#
# LEFT JOIN preserves InTrans's exact row count - GlTrans is already
# deduplicated to at most one row per DocRef before this join, so it's a
# one-to-zero-or-one relationship, never a multiplying one-to-many.

joined = intrans_adjustments.join(
    gltrans_deduped,
    intrans_adjustments["RONumber"] == gltrans_deduped["DocRef"],
    "left",
).drop("DocRef")

classified = joined.withColumn(
    "PAType",
    F.when(F.col("SubAccount").isNull(), "Unknown")
    .when(F.col("SubAccount") == 1, "Stock Check")
    .when(F.col("SubAccount") == 2, "Customer BIN")
    .when(F.col("SubAccount") == 3, "Damaged")
    .when(F.col("SubAccount") == 4, "Lost")
    .when(F.col("SubAccount") == 5, "Overage")
    .when(F.col("SubAccount") == 6, "Count Off")
    .otherwise("Unknown"),
)

enriched = (
    classified
    .withColumn("PositiveQty", F.when(F.col("Qty") > 0, F.col("Qty")).otherwise(F.lit(0.0)))
    .withColumn("NegativeQty", F.when(F.col("Qty") < 0, F.col("Qty")).otherwise(F.lit(0.0)))
    .withColumn("PositiveCost", F.when(F.col("CostValue") > 0, F.col("CostValue")).otherwise(F.lit(0.0)))
    .withColumn("NegativeCost", F.when(F.col("CostValue") < 0, F.col("CostValue")).otherwise(F.lit(0.0)))
    .withColumn("IsPositiveQty", F.col("Qty") > 0)
    .withColumn("IsNegativeQty", F.col("Qty") < 0)
    .withColumn("AbsQty", F.abs(F.col("Qty")))
    .withColumn("AbsCost", F.abs(F.col("CostValue")))
    # Bug fix: production used DateTime.LocalNow(), which returns UTC in
    # the Fabric service - not actual local time. This converts a real
    # UTC instant to Central time explicitly instead.
    .withColumn("LoadedDatetime", F.from_utc_timestamp(F.current_timestamp(), "America/Chicago"))
)

fact_parts_adjustments = enriched.select(
    "TransId", "RONumber", "TransDatetime", "Branch", "PartNumber", "PartDescription",
    "Franchise", "Type", "Qty", "CostValue", "SellPrice1", "Salesman", "CustomerNo",
    "Comments", "ModifiedDate", "SubAccount", "GLTransDate", "PAType",
    "PositiveQty", "NegativeQty", "PositiveCost", "NegativeCost",
    "IsPositiveQty", "IsNegativeQty", "AbsQty", "AbsCost", "LoadedDatetime",
)

fact_count = fact_parts_adjustments.count()
print(f"Fact_PartsAdjustments rows (one per InTrans adjustment line): {fact_count:,}")
assert fact_count == intrans_count, (
    f"Row count changed across the join ({intrans_count:,} -> {fact_count:,}) - "
    f"the LEFT JOIN should never add or drop InTrans rows since GlTrans is "
    f"deduplicated to at most one match per DocRef before joining."
)
print("Row count matches InTrans input exactly - join did not multiply or drop rows.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write - path-based .save(), not saveAsTable(), to preserve exact
# PascalCase (see Plan 3 / feedback_fabric_saveastable_casing.md).
# overwriteSchema=true since this is a full rebuild every run.

fact_parts_adjustments.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save("Tables/Fact_PartsAdjustments")

print("Gold build complete: Fact_PartsAdjustments written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - quick in-notebook sanity check, not the final proof
# (that's the independent EquipRDB comparison in this plan's Task 5).
# Confirms PAType classification actually produced a sensible spread
# across categories, not everything collapsing into "Unknown".

paType_breakdown = spark.sql("""
    SELECT PAType, COUNT(*) AS RowCount, SUM(AbsCost) AS TotalAbsCost
    FROM delta.`Tables/Fact_PartsAdjustments`
    GROUP BY PAType
    ORDER BY RowCount DESC
""").toPandas()

print("PAType breakdown:")
print(paType_breakdown.to_string())
print("\nExpect: multiple categories present (not 100% Unknown) - a mostly-Unknown result")
print("would mean the GlTrans join isn't matching, worth investigating before trusting this build.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Build_Gold_PartsAdjustments.Notebook"
git commit -m "Add Build_Gold_PartsAdjustments notebook

Reproduces the current production Fact_PartsAdjustments logic
(InTrans Type='A' LEFT JOIN deduped GlTrans, PAType classification,
sign-split/abs columns) sourced from the new corrected backend
instead of InTrans_Incremental. Also fixes a confirmed, unrelated
bug: LoadedDatetime used DateTime.LocalNow(), which returns UTC in
the Fabric service, not actual local time.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

- [ ] **Step 4: Brian confirms Dev picked up the notebook and runs it**

`DP - Presentation - Dev` → Source control → **Update all**. Then open `Build_Gold_PartsAdjustments.Notebook` and run all cells.

- [ ] **Step 5: Report back the notebook's own output**

Row counts from each cell, and the PAType breakdown table from the verification cell.

---

### Task 5: Independently verify against `EquipRDB`

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_adjustments.py`

Unlike the PAType classification (which depends on the GlTrans join), the row count and dollar totals for adjustment activity depend on InTrans alone — GlTrans is deduplicated to at most one match per DocRef before the LEFT JOIN, so it can never add or drop rows or change Qty/CostValue values. This means the actual bug-fix proof (matching Parts Promo's approach) is a direct InTrans-only comparison against source — the same class of check that caught the original watermark bug.

- [ ] **Step 1: Write the verification script**

```python
"""
DP GOLD PARTS ADJUSTMENTS VERIFICATION - THE ACTUAL PROOF
============================================================================
Compares the new Fact_PartsAdjustments (built by
Build_Gold_PartsAdjustments.Notebook, this plan's Task 4) against
EquipRDB - the real source system - for total row count, total cost
value, and total absolute cost value of adjustment activity since
2023-01-01.

This is deliberately NOT comparing against another copy of our own data -
it's comparing against ground truth, the same way the original Parts
Promo bug was first proven.

Business rule under test: Fact_PartsAdjustments should have exactly one
row per InTrans line where Type = 'A' (adjustment) and TransDatetime >=
2023-01-01 - GlTrans classification doesn't change this count or these
totals (see the notebook's own row-count assertion for why).

Run manually after Task 4 confirms the notebook ran successfully.
============================================================================
"""

import duckdb
import pyodbc

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

START_DATE = "2023-01-01"

# ------------------------------------------------------------------
# Pull the new gold table's totals
# ------------------------------------------------------------------
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

gold = con.execute(f"""
    SELECT COUNT(*) AS RowCount, SUM(CostValue) AS TotalCostValue, SUM(AbsCost) AS TotalAbsCost
    FROM delta_scan('{dp_base}/Fact_PartsAdjustments')
""").df()
print("New gold table (Fact_PartsAdjustments):")
print(gold.to_string())

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB - same business rule
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute(f"""
    SELECT COUNT(*) AS SRC_RowCount, SUM(COST_VAL) AS SRC_TotalCostValue, SUM(ABS(COST_VAL)) AS SRC_TotalAbsCost
    FROM InTrans
    WHERE TYPE = 'A'
      AND Trans_Datetime >= '{START_DATE}'
""")
src_row = cur.fetchone()
src_count, src_total_cost, src_total_abs = src_row
print("\nEquipRDB direct (InTrans, Type='A', since 2023-01-01):")
print(f"  RowCount: {src_count:,}")
print(f"  TotalCostValue: {float(src_total_cost):,.2f}")
print(f"  TotalAbsCost: {float(src_total_abs):,.2f}")

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
gold_count = int(gold["RowCount"][0])
gold_cost = float(gold["TotalCostValue"][0])
gold_abs = float(gold["TotalAbsCost"][0])

count_match = gold_count == src_count
cost_diff = abs(gold_cost - float(src_total_cost))
abs_diff = abs(gold_abs - float(src_total_abs))

print(f"\nRow count match: {count_match} (gold {gold_count:,} vs. source {src_count:,})")
print(f"TotalCostValue diff: {cost_diff:.4f} (expect < 0.01)")
print(f"TotalAbsCost diff: {abs_diff:.4f} (expect < 0.01)")

if count_match and cost_diff < 0.01 and abs_diff < 0.01:
    print("\nFact_PartsAdjustments matches EquipRDB exactly - migration confirmed correct.")
else:
    print("\nMISMATCH FOUND - do not trust this build until investigated.")
```

- [ ] **Step 2: Run it**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
export PATH="$HOME/.local/bin:$PATH"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_adjustments.py"
```

Expected: `Row count match: True`, both diffs under 0.01, final message confirms a match.

**If it doesn't match: stop, do not proceed to Task 6.** Investigate before repointing the live report at this table.

- [ ] **Step 3: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_adjustments.py
git commit -m "Add Fact_PartsAdjustments verification script

Compares the new gold table directly against EquipRDB - row count and
dollar totals for InTrans Type='A' adjustment activity since
2023-01-01. Same rigor as verify_gold_parts_promo.py: ground truth,
not another copy of our own data.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 6: Repoint `Fact_PartsAdjustments.tmdl` in `RP - Dev`

**Files:**
- Modify: `workspaces/RP - Dev/Parts Adjustments.SemanticModel/definition/tables/Fact_PartsAdjustments.tmdl` (in `fabric-workspace-docs`)

- [ ] **Step 1: Get the current file's exact partition source**

Read the file first (do not guess at whitespace/formatting). The current partition should read:
```
Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
dbo_Fact_PartsAdjustments = Source{[Schema="dbo",Item="Fact_PartsAdjustments"]}[Data],
#"Extracted Date" = Table.TransformColumns(dbo_Fact_PartsAdjustments,{{"TransDatetime", DateTime.Date, type date}})
```

- [ ] **Step 2: Repoint it**

Replace with:
```
// Repointed 2026-09-09 from LH_Master_Data to DP_Presentation as part of
// the JD Bronze / data platform redesign - see
// docs/superpowers/plans/2026-09-09-dp-gold-parts-adjustments.md.
Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
dbo_Fact_PartsAdjustments = Source{[Schema="dbo",Item="Fact_PartsAdjustments"]}[Data],
#"Extracted Date" = Table.TransformColumns(dbo_Fact_PartsAdjustments,{{"TransDatetime", DateTime.Date, type date}})
```

(Same Dev-tier SQL endpoint host already in use for Parts Promo's Dev-tier tables — `DP - Presentation - Dev`'s SQL Analytics Endpoint, unchanged from Plans 1-4.)

**Note:** TMDL does not support `//` comments per project convention (see `feedback_tmdl_no_comments.md`) — if this repo's TMDL files use `//` elsewhere for this kind of note (confirmed present in Parts Promo's already-repointed tables this session), that convention already deviates from the general TMDL rule for M-code comments specifically (M supports `//`, only TMDL's own declaration syntax doesn't) — match whatever the existing repointed Parts Promo tables actually do here, don't introduce a new style.

- [ ] **Step 3: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/RP - Dev/Parts Adjustments.SemanticModel/definition/tables/Fact_PartsAdjustments.tmdl"
git commit -m "Repoint Fact_PartsAdjustments to the new DP backend

Reads from DP_Presentation (Dev tier) instead of LH_Master_Data /
InTrans_Incremental - same bug-fix migration already proven on Parts
Promo. See docs/superpowers/plans/2026-09-09-dp-gold-parts-adjustments.md.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

- [ ] **Step 4: Brian confirms Dev picked it up, opens Desktop, refreshes**

`RP - Dev` → Source control → **Update all**. Open `Parts Adjustments.pbip` from `workspaces/RP - Dev/` in Power BI Desktop, refresh, confirm it completes without error (may hit the SQL Analytics Endpoint catalog-sync lag on a data source that hasn't been queried this way before — if so, wait a minute and retry, same as every prior instance of this in this project).

- [ ] **Step 5: Spot-check real records**

Report back a few real adjustment transactions from the refreshed Details page (PA Type, cost value, branch) so they can be sanity-checked against what's expected — this is a live-report check, complementing (not replacing) Task 5's independent EquipRDB comparison.

---

### Task 7: Update the reference doc

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Add the GlTrans shortcuts and Fact_PartsAdjustments to the Lakehouses section**

Add to the existing `DP_Staging` row's Contents: `Tables/GlTrans` — OneLake shortcut (passthrough) into `JD_EquipRDB_Production_Bronze.GlTrans`, verified 2026-09-09 (row count match, sample check) — see `.claude/queries/adhoc/dp-bronze-verify/verify_shortcut_gltrans.py`.

Add to the existing `DP_Presentation` row's Contents: `Tables/GlTrans` — OneLake shortcut into `DP_Staging.GlTrans`. `Tables/Fact_PartsAdjustments` — built by `Build_Gold_PartsAdjustments.Notebook` (`workspaces/DP - Presentation - Dev/Build_Gold_PartsAdjustments.Notebook`), joining `Silver_InTrans` (Type='A', since 2023-01-01) to deduplicated `GlTrans` (Dept=30, Acct=480, since 2023-01-01) on `RONumber = DocRef`. Verified 2026-09-09 via `verify_gold_parts_adjustments.py`: row count, total cost value, and total absolute cost value all match `EquipRDB` directly (not another copy of our own data). Also fixed a confirmed, unrelated bug while rebuilding: `LoadedDatetime` previously used `DateTime.LocalNow()` (returns UTC in the Fabric service, not local time) — now converts explicitly to `America/Chicago`.

- [ ] **Step 2: Commit**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record GlTrans shortcuts and Fact_PartsAdjustments gold table

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Final end-to-end check and follow-up investigation

**Files:** none

- [ ] **Step 1: Confirm both repos clean**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs" && git status --short
cd "C:\Users\bfox\Documents\Git-Projects\data-projects" && git status --short
```
Expected: both clean (or only unrelated pre-existing noise, not anything from this plan).

- [ ] **Step 2: Note the deferred investigation item**

`Fact_AdjustmentPairs`/`Fact_AdjPairs_Summary` (`data-projects/projects/parts adjustments - report/queries/fact table/`) are separate fact tables in this same report folder, not confirmed to depend on `InTrans_Incremental` or even to be used by the live report — check this before assuming they're out of scope forever, but don't investigate as part of this plan.

**Do not proceed to a Prod-tier plan for Fact_PartsAdjustments until every step above is checked off and Task 5's verification script shows a clean match.**
