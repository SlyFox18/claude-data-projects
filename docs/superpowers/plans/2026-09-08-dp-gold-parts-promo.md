# DP Gold Parts Promo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `dim_RepairOrder` and `Fact_PartsPromo` in a new `DP_Presentation` lakehouse, sourced from `Silver_InTrans` (Plan 3), reproducing the exact business logic of the existing production tables — then prove correctness against all 11 repair orders confirmed wrong in the original investigation, by comparing straight against the source system (`EquipRDB`), not just against our own pipeline. This is the actual payoff of the whole program: the moment the original Parts Promo bug gets provably fixed.

**Architecture:** One Fabric Notebook (`Build_Gold_PartsPromo`, PySpark) in `DP - Presentation - Dev`, reading `Silver_InTrans` directly from `DP - Staging - Dev` via its full OneLake path (cross-workspace Spark read, no shortcut needed — Spark can read any OneLake path it has permission for). Reproduces `dim_RepairOrder.pq` and `Fact_PartsPromo_v2.pq`'s exact business rules (promo = `PartNumber` starts with `*`; non-promo aggregates exclude `Franchise = 'ZP'`; promo aggregates do not). Full overwrite each run — these tables are small (promo-active orders only, not the full 20M+ row `InTrans`), so a full rebuild from the already-correct `Silver_InTrans` is cheap and simpler than incremental merge logic. Written via path-based `.save()` from the start this time (no `saveAsTable()` casing mistake to make).

**Tech Stack:** PySpark, authored directly as git-tracked notebook files (same pattern as Plan 3). Verification uses direct `pyodbc` queries against `EquipRDB` — the actual source system, not an intermediate copy — for the strongest possible proof.

**Known execution pattern:** file/git work is agent-executable; lakehouse creation and running the notebook need Brian.

---

### Task 1: Create the Presentation lakehouse

**Files:** none (Fabric tenant infrastructure)

- [ ] **Step 1: Brian creates the lakehouse**

Run in your own terminal:
```
fab mkdir "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse" -P capacityName=fabric1cap1
```

- [ ] **Step 2: Verify (agent-executed)**

```
fab get "DP - Presentation - Dev.Workspace/DP_Presentation.Lakehouse" -q "id"
```
Expected: a GUID. Record it — needed for Task 2's notebook metadata and Task 5.

---

### Task 2: Author the `Build_Gold_PartsPromo` notebook

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Presentation - Dev\Build_Gold_PartsPromo.Notebook\.platform`
- Create: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Presentation - Dev\Build_Gold_PartsPromo.Notebook\notebook-content.py`

- [ ] **Step 1: Write the `.platform` file**

Use a fresh UUID for `logicalId` (generate one — do not reuse Plan 3's).

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_PartsPromo"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<fresh UUID>"
  }
}
```

- [ ] **Step 2: Write the notebook content**

Replace `<DP_Presentation lakehouse ID from Task 1>` with the real value before committing.

```python
# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "<DP_Presentation lakehouse ID from Task 1>",
# META       "default_lakehouse_name": "DP_Presentation",
# META       "default_lakehouse_workspace_id": "73fd5443-240e-410a-990a-98827f32c087",
# META       "known_lakehouses": [
# META         {
# META           "id": "<DP_Presentation lakehouse ID from Task 1>"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Build_Gold_PartsPromo
# Purpose: Build dim_RepairOrder and Fact_PartsPromo from Silver_InTrans,
# reproducing the exact business logic of the existing production tables
# (dim_RepairOrder.pq / Fact_PartsPromo_v2.pq in
# projects/parts promo - report/queries/new report/), sourced from the new
# corrected backend instead of the buggy InTrans_Incremental.
#
# Business rules (unchanged from production):
# - A "promo order" is any RONumber with at least one PartNumber starting
#   with '*'.
# - dim_RepairOrder: one row per promo order. TotalPartsSales/TotalPartsCost/
#   PartsCount aggregate NON-promo lines EXCLUDING Franchise = 'ZP'.
#   TotalPromoDiscount/PromoCount aggregate promo lines with NO franchise
#   exclusion (promo parts typically ARE Franchise = 'ZP').
# - Fact_PartsPromo: one row per promo line item (PartNumber starts with
#   '*'), no franchise exclusion, no order-level aggregation — that's what
#   dim_RepairOrder is for.
#
# Reads Silver_InTrans directly from DP - Staging - Dev via its full OneLake
# path (cross-workspace Spark read — no shortcut needed for a same-tenant
# read like this). Full overwrite each run: these tables are small
# (promo-active orders only), so a full rebuild from Silver_InTrans (already
# deduped and correct) is simpler than incremental merge logic.

print("=" * 80)
print("BUILD_GOLD_PARTSPROMO")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

SILVER_PATH = "abfss://ab15d64d-c7ba-415d-9bcf-7feb1ef9b201@onelake.dfs.fabric.microsoft.com/876255e0-d462-4697-adc1-4a655f5bb101/Tables/Silver_InTrans"
START_DATE = "2022-01-01"  # matches the existing production Fact_PartsPromo_v2.pq / dim_RepairOrder.pq StartDate

silver = spark.read.format("delta").load(SILVER_PATH).filter(F.col("TransDatetime") >= START_DATE)

row_count = silver.count()
print(f"Silver_InTrans rows loaded (>= {START_DATE}): {row_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Build dim_RepairOrder

promo_ros = (
    silver.filter(F.col("PartNumber").startswith("*"))
    .select("RONumber").distinct()
)

orders_with_promo = silver.join(promo_ros, on="RONumber", how="inner")

# Order-level attributes (Branch/CustomerNo/dates) come from the WHOLE
# order's rows, not just the non-promo subset - matches the original
# Power Query's Table.Group behavior exactly.
order_attrs = orders_with_promo.groupBy("RONumber").agg(
    F.first("Branch").alias("BranchKey"),
    F.first("CustomerNo").alias("CustomerNo"),
    F.min("TransDatetime").alias("OrderDate"),
    F.max("TransDatetime").alias("LastActivityDate"),
)

non_promo_non_zp = orders_with_promo.filter(
    (~F.col("PartNumber").startswith("*")) & (F.col("Franchise") != "ZP")
)
non_promo_agg = non_promo_non_zp.groupBy("RONumber").agg(
    F.sum(F.coalesce(F.col("SaleValue"), F.lit(0.0))).alias("TotalPartsSales"),
    F.sum(F.coalesce(F.col("CostValue"), F.lit(0.0))).alias("TotalPartsCost"),
    F.count(F.lit(1)).alias("PartsCount"),
)

promo_rows = orders_with_promo.filter(F.col("PartNumber").startswith("*"))
promo_agg = promo_rows.groupBy("RONumber").agg(
    F.sum(F.coalesce(F.col("SaleValue"), F.lit(0.0))).alias("TotalPromoDiscount"),
    F.count(F.lit(1)).alias("PromoCount"),
)

dim_repair_order = (
    promo_ros
    .join(order_attrs, on="RONumber", how="left")
    .join(non_promo_agg, on="RONumber", how="left")
    .join(promo_agg, on="RONumber", how="left")
    .fillna(0.0, subset=["TotalPartsSales", "TotalPartsCost", "TotalPromoDiscount"])
    .fillna(0, subset=["PartsCount", "PromoCount"])
    .withColumn("NetOrderValue", F.col("TotalPartsSales") + F.col("TotalPromoDiscount"))
    .withColumn("OriginalMargin", F.col("TotalPartsSales") - F.col("TotalPartsCost"))
    .withColumn("NetMargin", F.col("NetOrderValue") - F.col("TotalPartsCost"))
    .withColumn("DiscountAmount", F.abs(F.col("TotalPromoDiscount")))
    .withColumn(
        "DiscountPercent",
        F.when(F.col("TotalPartsSales") == 0, F.lit(0.0))
        .otherwise(F.col("DiscountAmount") / F.col("TotalPartsSales")),
    )
    .withColumnRenamed("RONumber", "REF_NO")
    .select(
        "REF_NO", "BranchKey", "CustomerNo", "OrderDate", "LastActivityDate",
        "TotalPartsSales", "TotalPartsCost", "PartsCount",
        "TotalPromoDiscount", "PromoCount",
        "NetOrderValue", "OriginalMargin", "NetMargin", "DiscountAmount", "DiscountPercent",
    )
)

dim_count = dim_repair_order.count()
print(f"dim_RepairOrder rows (one per promo-active order): {dim_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Build Fact_PartsPromo

fact_parts_promo = (
    silver
    .filter(F.col("PartNumber").startswith("*"))
    .select(
        F.col("Branch"),
        F.col("RONumber").alias("REF_NO"),
        F.col("PartNumber").alias("PART_NO"),
        F.col("TransDatetime"),
        F.col("CustomerNo"),
        F.col("Franchise"),
        F.col("Type"),
        F.col("Description"),
        F.col("Qty"),
        F.col("SaleValue"),
        F.col("CostValue"),
    )
)

fact_count = fact_parts_promo.count()
print(f"Fact_PartsPromo rows (one per promo line item): {fact_count:,}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write both tables - path-based .save(), not saveAsTable(), to preserve
# exact PascalCase (see Plan 3 / feedback_fabric_saveastable_casing.md).

dim_repair_order.write.format("delta").mode("overwrite").save("Tables/dim_RepairOrder")
fact_parts_promo.write.format("delta").mode("overwrite").save("Tables/Fact_PartsPromo")

print("Gold build complete: dim_RepairOrder and Fact_PartsPromo written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Verification - the 11 orders confirmed wrong in the original investigation
# (docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md).
# Full source-vs-gold cross-check happens independently in Task 4 (against
# EquipRDB directly, not just this notebook's own output) - this cell is a
# quick in-notebook sanity check, not the final proof.

known_bad_ros = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]

check = spark.sql(f"""
    SELECT REF_NO, TotalPartsSales, TotalPartsCost, PartsCount
    FROM delta.`Tables/dim_RepairOrder`
    WHERE REF_NO IN ({",".join(f"'{r}'" for r in known_bad_ros)})
    ORDER BY REF_NO
""").toPandas()

print(f"Rows found for the 11 known-bad orders: {len(check)} (expect 11 - if fewer, one or more orders")
print("didn't make it into dim_RepairOrder at all, which is itself a problem worth investigating)")
print(check.to_string())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Commit both files**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Build_Gold_PartsPromo.Notebook"
git commit -m "Add Build_Gold_PartsPromo notebook

Builds dim_RepairOrder and Fact_PartsPromo from Silver_InTrans,
reproducing the existing production business logic (promo/non-promo
aggregation, ZP franchise exclusion) on the corrected backend.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git fetch origin dev
git rebase origin/dev
git push origin dev
```

---

### Task 3: Sync and run the notebook

**Files:** none (Fabric portal action — Brian's)

- [ ] **Step 1: Pull the notebook into the workspace**

`DP - Presentation - Dev` → **Source control** → **Update all**.

- [ ] **Step 2: Run all cells**

Much smaller job than Plan 3's — `Silver_InTrans` filtered to promo-active orders since 2022 is a small fraction of 20M+ rows. Should run in well under a minute.

- [ ] **Step 3: Report back the output**

Specifically: `Silver_InTrans` rows loaded, `dim_RepairOrder` row count, `Fact_PartsPromo` row count, and the last cell's 11-row table for the known-bad orders.

---

### Task 4: Independent verification against the real source (agent-executed)

**Files:**
- Create: `.claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py`

This is the actual proof the original bug is fixed — comparing the new `dim_RepairOrder` straight against `EquipRDB` (the real source system), not against our own pipeline at any layer, for all 11 orders confirmed wrong in the original investigation (not just RO 1985073).

- [ ] **Step 1: Write the verification script**

```python
"""
DP GOLD PARTS PROMO VERIFICATION - THE ACTUAL PROOF
============================================================================
Compares the new dim_RepairOrder (built by Build_Gold_PartsPromo.Notebook,
Plan 4) against EquipRDB - the real source system - for all 11 repair
orders confirmed wrong in the original investigation
(docs/superpowers/specs/2026-09-04-jd-bronze-data-platform-redesign-design.md).

This is deliberately NOT comparing against another copy of our own data -
it's comparing against ground truth, the same way the original bug was
first proven.

Business rule under test: TotalPartsSales/TotalPartsCost = SUM(SaleValue/
CostValue) for non-promo (PART_NO NOT LIKE '*%') lines EXCLUDING
Franchise = 'ZP', per RONumber, since 2022-01-01. Matches dim_RepairOrder.pq
and this plan's notebook exactly.

Run manually after Task 3 confirms the notebook ran successfully.
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "<DP_Presentation lakehouse ID from Task 1>"
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

KNOWN_BAD_ROS = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]

# ------------------------------------------------------------------
# Pull the new gold table's values
# ------------------------------------------------------------------
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

placeholders = ",".join(f"'{r}'" for r in KNOWN_BAD_ROS)
gold = con.execute(f"""
    SELECT REF_NO, TotalPartsSales, TotalPartsCost, PartsCount
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO IN ({placeholders})
""").df()

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB - same business rule
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()
cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPartsSales, SUM(COST_VAL) AS SRC_TotalPartsCost, COUNT(*) AS SRC_PartsCount
    FROM InTrans
    WHERE PART_NO NOT LIKE '*%'
      AND FRANCHISE != 'ZP'
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
src_rows = cur.fetchall()
source = pd.DataFrame.from_records(
    [tuple(r) for r in src_rows],
    columns=["REF_NO", "SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount"],
)
source["REF_NO"] = source["REF_NO"].astype(str)
source["SRC_TotalPartsSales"] = source["SRC_TotalPartsSales"].astype(float)
source["SRC_TotalPartsCost"] = source["SRC_TotalPartsCost"].astype(float)

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
gold["REF_NO"] = gold["REF_NO"].astype(str)
merged = source.merge(gold, on="REF_NO", how="outer", indicator=True)
merged["SalesDiff"] = (merged["SRC_TotalPartsSales"] - merged["TotalPartsSales"]).abs()
merged["CostDiff"] = (merged["SRC_TotalPartsCost"] - merged["TotalPartsCost"]).abs()

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)
print(f"Orders checked: {len(merged)} (expect 11)")
print(merged.to_string(index=False))

mismatches = merged[(merged["SalesDiff"] > 0.01) | (merged["CostDiff"] > 0.01) | (merged["_merge"] != "both")]
print(f"\nOrders with a real mismatch (sales/cost off by >$0.01, or missing from one side): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All 11 previously-wrong orders now match the real source exactly.")
```

- [ ] **Step 2: Fill in the lakehouse ID placeholder, then run it**

```
export PATH="$HOME/.local/bin:$PATH"
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
python ".claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py"
```

Expected: 11 orders checked, 0 mismatches — every order that was wrong on the old backend now matches `EquipRDB` exactly on the new one.

**If any mismatch remains:** stop, do not proceed to Task 5 or claim the fix works — investigate that specific order the same way the original bug was found (compare source vs. each layer: `EquipRDB` → JD Bronze → `Silver_InTrans` → `dim_RepairOrder`, narrowing down which layer introduces the discrepancy).

- [ ] **Step 3: Commit the verification script**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_gold_parts_promo.py
git commit -m "Add gold Parts Promo verification - the actual bug-fix proof

Compares dim_RepairOrder against EquipRDB directly (not another copy
of our own data) for all 11 orders confirmed wrong in the original
investigation.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 5: Update the Variable Library and reference doc

**Files:**
- Modify: `docs/architecture/data-platform-workspaces.md`

- [ ] **Step 1: Brian updates the Variable Library**

`DP - Staging - Dev` → `DP - Environment Config`: set `presentation_lakehouse_id` to the real `DP_Presentation` lakehouse GUID (from Task 1) in both the `Default` and `Dev` value sets, leave `Prod` as `not-yet-created`. Save, commit.

- [ ] **Step 2: Verify the commit (agent-executed)**

```
cd "C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs"
git fetch origin dev
git show "origin/dev:workspaces/DP - Staging - Dev/DP - Environment Config.VariableLibrary/variables.json"
```
Expected: `presentation_lakehouse_id` shows the real GUID.

- [ ] **Step 3: Update the reference doc**

Add `DP_Presentation` to the Lakehouses table and a `dim_RepairOrder` / `Fact_PartsPromo` section, matching the style already used for `Silver_InTrans` — table contents, row counts, and the Task 4 verification result (11/11 orders matching source).

- [ ] **Step 4: Commit and push**

```bash
cd "C:\Users\bfox\Documents\Git-Projects\data-projects"
git add docs/architecture/data-platform-workspaces.md
git commit -m "Record DP_Presentation lakehouse, dim_RepairOrder, Fact_PartsPromo

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

## Explicitly out of scope for this plan

Repointing the actual Parts Promo semantic model (TMDL partitions) at these new gold tables, and validating in `RP - Dev`, is deliberately a separate follow-on plan — it touches the report layer (Desktop/TMDL), not just the backend, and deserves its own careful pass rather than being a rider on the gold-layer build. This plan's job is proving the gold tables themselves are correct; the next plan's job is putting them in front of the actual report.
