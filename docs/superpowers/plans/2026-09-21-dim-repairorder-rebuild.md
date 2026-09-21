# dim_RepairOrder Full Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore all 15 original columns to the Gold-layer `dim_RepairOrder` table (currently only 2 of 15 exist), fixing Parts Promo's core margin/discount-analysis DAX measures which depend on the missing columns, and completing Parts Promo's migration to the DP backend.

**Architecture:** Extend the existing `dim_repair_order` build cell inside `Build_Gold_PartsPromo.Notebook` (PySpark, not a new notebook) to compute the full 15-column design from `Silver_InTrans`, which it already reads. No changes to `Fact_PartsPromo`, `Fact_InTrans_AllPromo`, or any report TMDL file. Verify with a DuckDB script that independently recomputes every column directly against `EquipRDB` (the real source system) for the same repair orders, following this project's established real-ground-truth verification pattern.

**Tech Stack:** PySpark (Fabric notebook), DuckDB + `delta_scan()` against OneLake, `pyodbc` against `EquipRDB64`.

**Full design reference:** `docs/superpowers/specs/2026-09-21-dim-repairorder-rebuild-design.md` (approved).

---

## Context You Need

`Build_Gold_PartsPromo.Notebook/notebook-content.py` (in `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Parts Promo/`) builds three Gold tables from one shared `Silver_InTrans` read: `dim_RepairOrder`, `Fact_PartsPromo`, `Fact_InTrans_AllPromo`. Only `dim_RepairOrder` changes in this plan.

The current `dim_repair_order` build cell (lines 117–156) computes only `REF_NO` and `CustomerNo`, per a 2026-09-11 column-usage-depth audit that concluded the other 13 columns were unused. That audit predated Parts Promo's own DAX measures actually being pointed at this table — 5 of those 13 columns (`TotalPartsSales`, `TotalPartsCost`, `OriginalMargin`, `NetOrderValue`, `NetMargin`) are directly used by real, live measures. Brian's call (per the approved spec) is to restore the full original 15-column design, not just the 5 confirmed-used ones, since the table was originally designed as this complete set for this exact report.

`REF_NO` and `CustomerNo` are already computed correctly and must not change. The 13 columns being restored: `BranchKey`, `OrderDate`, `LastActivityDate`, `TotalPartsSales`, `TotalPartsCost`, `PartsCount`, `TotalPromoDiscount`, `PromoCount`, `NetOrderValue`, `OriginalMargin`, `NetMargin`, `DiscountAmount`, `DiscountPercent`.

**Grain:** one row per `REF_NO`, for orders with at least one promo line (`PartNumber` starting with `"*"`) — this is already correctly implemented via `promo_ros`/`orders_with_promo` and does not change.

**Column logic** (from the approved spec):
- `BranchKey`: first `Branch` value across the whole order's rows, cast to a 64-bit integer (a real fix being restored — an earlier version of this table left it as a string).
- `OrderDate` / `LastActivityDate`: min / max `TransDatetime` across the whole order's rows.
- `TotalPartsSales` / `TotalPartsCost` / `PartsCount`: `SUM(SaleValue)` / `SUM(CostValue)` / `COUNT(*)` over the order's **non-promo** rows only (`PartNumber` does NOT start with `"*"`, AND `Franchise != "ZP"`).
- `TotalPromoDiscount` / `PromoCount`: `SUM(SaleValue)` / `COUNT(*)` over the order's **promo** rows only (`PartNumber` starts with `"*"`) — no `Franchise` exclusion (promo parts are typically franchise `ZP` themselves; excluding them would zero this out).
- `NetOrderValue = TotalPartsSales + TotalPromoDiscount`
- `OriginalMargin = TotalPartsSales - TotalPartsCost`
- `NetMargin = NetOrderValue - TotalPartsCost`
- `DiscountAmount = ABS(TotalPromoDiscount)`
- `DiscountPercent = DiscountAmount / TotalPartsSales`, or `0` if `TotalPartsSales` is `0`.
- If an order has zero non-promo rows (or, in principle, zero promo rows), the corresponding sums/counts should be `0`, not `null` — every promo order gets a fully-populated row.

**Real-tool boundary:** Claude can write the notebook code and the DuckDB verification script and can run the verification script (it uses CLI-credential-chain OneLake/DuckDB access + `pyodbc`/`EquipRDB64`, already proven working all session). Claude **cannot** run the Fabric notebook itself — that's Brian's own action in the Fabric portal. Task 4 makes this handoff explicit.

---

### Task 1: Rewrite the `dim_repair_order` build cell for the full 15-column design

**Files:**
- Modify: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Presentation - Dev\Fact Tables\Parts Promo\Build_Gold_PartsPromo.Notebook\notebook-content.py` (lines 117–156, the `dim_repair_order` build cell, plus its header comment)

- [ ] **Step 1: Replace the build cell's header comment**

The current comment (lines 117–131) says the table was "TRIMMED 2026-09-11" to 2 columns because a usage audit found the other 13 unused. That's now stale — replace it with:

```python
# Build dim_RepairOrder
#
# RESTORED 2026-09-21, after Parts Promo's own DAX measures were confirmed
# (via a direct grep of _Measures.tmdl) to genuinely depend on 5 of the 13
# columns dropped in the 2026-09-11 trim: TotalPartsSales, TotalPartsCost,
# OriginalMargin, NetOrderValue, NetMargin. That trim's usage audit predated
# Parts Promo's own facts/dims actually being migrated to this backend and
# refreshed for real - the same "audit didn't cover this report yet" gap
# already found and fixed for dim_DateTable/dim_BranchLocation/dim_CustomerList/
# dim_Parts elsewhere in this project. Per Brian's own call
# (docs/superpowers/specs/2026-09-21-dim-repairorder-rebuild-design.md), all
# 15 original columns are restored here, not just the 5 confirmed-used ones -
# the table was originally, deliberately designed as this complete set for
# this exact report.
#
# BranchKey is cast to a 64-bit integer this time (Int64.Type in the original
# Power Query) - an earlier version of this table left it as a string; see
# the module header's "CORRECTED 2026-09-08" note above for that history.
```

- [ ] **Step 2: Replace the build cell's logic**

Replace lines 133–156 (from `promo_ros = (` through the final `print(...)` line) with:

```python
promo_ros = (
    silver.filter(F.col("PartNumber").startswith("*"))
    .select("RONumber").distinct()
)

orders_with_promo = silver.join(promo_ros, on="RONumber", how="inner")

# Order-level attributes computed across ALL of the order's rows (promo and
# non-promo lines both) - matches the original dim_RepairOrder.pq exactly:
# CustomerNo/BranchKey are "first value seen" for the order, OrderDate/
# LastActivityDate are the full order's min/max TransDatetime.
order_attrs = orders_with_promo.groupBy("RONumber").agg(
    F.first("CustomerNo").alias("CustomerNo"),
    F.first("Branch").cast("bigint").alias("BranchKey"),
    F.min("TransDatetime").alias("OrderDate"),
    F.max("TransDatetime").alias("LastActivityDate"),
)

# Non-promo lines: PartNumber does NOT start with '*', and Franchise != 'ZP'
# (ZP is the promo/discount franchise code - excluding it from the "real
# parts sale" aggregates matches the original .pq exactly).
non_promo_agg = (
    orders_with_promo
    .filter(~F.col("PartNumber").startswith("*") & (F.col("Franchise") != "ZP"))
    .groupBy("RONumber")
    .agg(
        F.sum("SaleValue").alias("TotalPartsSales"),
        F.sum("CostValue").alias("TotalPartsCost"),
        F.count(F.lit(1)).alias("PartsCount"),
    )
)

# Promo lines: PartNumber starts with '*'. No Franchise exclusion here -
# promo parts are typically franchise ZP themselves, so excluding ZP would
# zero this out.
promo_agg = (
    orders_with_promo
    .filter(F.col("PartNumber").startswith("*"))
    .groupBy("RONumber")
    .agg(
        F.sum("SaleValue").alias("TotalPromoDiscount"),
        F.count(F.lit(1)).alias("PromoCount"),
    )
)

dim_repair_order = (
    promo_ros
    .join(order_attrs, on="RONumber", how="left")
    .join(non_promo_agg, on="RONumber", how="left")
    .join(promo_agg, on="RONumber", how="left")
    # Every promo order gets a fully-populated row - an order with zero
    # non-promo lines (or, in principle, zero promo lines) should show 0,
    # not null, for these aggregates.
    .withColumn("TotalPartsSales", F.coalesce(F.col("TotalPartsSales"), F.lit(0.0)))
    .withColumn("TotalPartsCost", F.coalesce(F.col("TotalPartsCost"), F.lit(0.0)))
    .withColumn("PartsCount", F.coalesce(F.col("PartsCount"), F.lit(0)))
    .withColumn("TotalPromoDiscount", F.coalesce(F.col("TotalPromoDiscount"), F.lit(0.0)))
    .withColumn("PromoCount", F.coalesce(F.col("PromoCount"), F.lit(0)))
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
        "NetOrderValue", "OriginalMargin", "NetMargin",
        "DiscountAmount", "DiscountPercent",
    )
)

dim_count = dim_repair_order.count()
final_col_count = len(dim_repair_order.columns)
print(f"dim_RepairOrder rows (one per promo-active order): {dim_count:,}")
print(f"dim_RepairOrder columns: {final_col_count} (expect 15 - full column set restored 2026-09-21)")
```

- [ ] **Step 3: Update the module-level header comment**

Lines 32–38 describe `dim_RepairOrder` as "one row per promo order (REF_NO)... plus CustomerNo" and reference "the 2026-09-11 trim note further down for why this is no longer the full order-level metrics table it originally was." Replace that bullet with:

```python
# - dim_RepairOrder: one row per promo order (REF_NO), the relationship key
#   to Fact_PartsPromo/Fact_InTrans_AllPromo, with the full 15-column
#   order-level metrics design (customer/branch/date attributes plus
#   sales/cost/margin/discount aggregates) - see the "RESTORED 2026-09-21"
#   note on the build cell below for why this was trimmed to 2 columns and
#   then restored.
```

- [ ] **Step 4: Update the verification cell to select all 15 columns**

The existing verification cell (lines 283–297) only selects `REF_NO, CustomerNo`. Update the `spark.sql` query to select every column, so the printed sanity check actually shows the restored data:

```python
check = spark.sql(f"""
    SELECT REF_NO, BranchKey, CustomerNo, OrderDate, LastActivityDate,
           TotalPartsSales, TotalPartsCost, PartsCount,
           TotalPromoDiscount, PromoCount,
           NetOrderValue, OriginalMargin, NetMargin,
           DiscountAmount, DiscountPercent
    FROM delta.`Tables/dim_RepairOrder`
    WHERE REF_NO IN ({",".join(f"'{r}'" for r in known_bad_ros)})
    ORDER BY REF_NO
""").toPandas()
```

(Only the `SELECT` line changes — `known_bad_ros`, the `FROM`/`WHERE`/`ORDER BY` clauses, and everything after stay as-is.)

- [ ] **Step 5: Save the file**

No test framework applies to a Fabric notebook — the real test is Task 3's independent DuckDB verification against `EquipRDB` (ground truth), run after Brian executes the notebook in Task 4. Do not attempt to run PySpark locally; there is no local Spark environment for this project.

**Real correction (found during code-quality review, fixed in a follow-up commit):** the plan's own `non_promo_agg` filter as originally written above used `F.col("Franchise") != "ZP"`. Under Spark's three-valued null logic, `!=` against a null `Franchise` evaluates to `NULL` (not `true`), so those rows were silently dropped from the aggregate — a real divergence from the original Power Query's `<>` comparison, where `null <> "ZP"` is `true` (row included). Both the spec-compliance and code-quality reviewers independently caught this. Fixed by using `~F.col("Franchise").eqNullSafe("ZP")` instead, which correctly treats a null `Franchise` as not-ZP (included) — see commit `777cebc8` in `fabric-workspace-docs`. The code block above has been left as originally planned for historical accuracy; implementers following this plan in the future should use the null-safe form.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Parts Promo/Build_Gold_PartsPromo.Notebook/notebook-content.py"
git commit -m "Restore full 15-column dim_RepairOrder design in Build_Gold_PartsPromo

Fixes Parts Promo's core margin/discount DAX measures, which depend on
5 of the 13 columns dropped in the 2026-09-11 trim (TotalPartsSales,
TotalPartsCost, OriginalMargin, NetOrderValue, NetMargin). Per Brian's
call, restores all 15 original columns, not just the 5 confirmed-used
ones - the table was originally designed as this complete set.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Write the ground-truth verification script

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\.claude\queries\adhoc\dp-bronze-verify\verify_dim_repairorder_full_rebuild.py`

This extends the existing `verify_gold_parts_promo.py` pattern (2026-09-08, which independently checked `TotalPartsSales`/`TotalPartsCost`/`PartsCount` against `EquipRDB` directly for the same 11 known-tricky orders, before the 2026-09-11 trim removed those columns) to the full 15-column design, and adds 5 arbitrary real orders so the check isn't only proving the already-known-tricky cases.

- [ ] **Step 1: Write the script**

```python
"""
DIM_REPAIRORDER FULL REBUILD VERIFICATION - GROUND TRUTH PROOF
============================================================================
Independently recomputes all 15 dim_RepairOrder columns directly against
EquipRDB (the real source system) - not against another copy of our own
data - for the 11 repair orders confirmed wrong in the original
investigation plus 5 arbitrary real promo orders, and compares against
Build_Gold_PartsPromo.Notebook's real output in DP_Presentation.

Extends the pre-trim verify_gold_parts_promo.py pattern (2026-09-08) to
the full restored 15-column design
(docs/superpowers/specs/2026-09-21-dim-repairorder-rebuild-design.md).

Run manually after Brian confirms the notebook ran successfully in Fabric
(Task 4 of docs/superpowers/plans/2026-09-21-dim-repairorder-rebuild.md).
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

KNOWN_BAD_ROS = [
    "1986984", "1981941", "1984493", "1987016", "1986996",
    "1985073", "1979395", "1985078", "1985139", "1987116", "1987002",
]

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Pull 5 arbitrary real promo orders too, not just the known-bad 11 -
# guards against a fix that only happens to work for the already-known
# tricky cases.
# ------------------------------------------------------------------
known_bad_placeholders = ",".join(f"'{r}'" for r in KNOWN_BAD_ROS)
sample_ros = con.execute(f"""
    SELECT DISTINCT REF_NO
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO NOT IN ({known_bad_placeholders})
    ORDER BY REF_NO
    LIMIT 5
""").df()["REF_NO"].tolist()

ALL_ROS = KNOWN_BAD_ROS + sample_ros
placeholders = ",".join(f"'{r}'" for r in ALL_ROS)

# ------------------------------------------------------------------
# Pull the new gold table's values
# ------------------------------------------------------------------
gold = con.execute(f"""
    SELECT REF_NO, BranchKey, CustomerNo, OrderDate, LastActivityDate,
           TotalPartsSales, TotalPartsCost, PartsCount,
           TotalPromoDiscount, PromoCount,
           NetOrderValue, OriginalMargin, NetMargin,
           DiscountAmount, DiscountPercent
    FROM delta_scan('{dp_base}/dim_RepairOrder')
    WHERE REF_NO IN ({placeholders})
""").df()

# ------------------------------------------------------------------
# Pull ground truth directly from EquipRDB, same business rules as the
# spec: non-promo excludes Franchise='ZP', promo does not. Real source
# column names confirmed against .claude/queries/raw-tables/
# Raw_InTrans_Incremental.pq: BRANCH, customer_no, REF_NO, PART_NO,
# FRANCHISE, Trans_Datetime, SALE_VAL, COST_VAL.
#
# "(FRANCHISE IS NULL OR FRANCHISE != 'ZP')" rather than a plain
# "FRANCHISE != 'ZP'" - SQL's != also evaluates to unknown/false against
# NULL, same three-valued-logic trap found and fixed in the notebook's
# own PySpark filter (see the plan's "Real correction" note on Task 1).
# Must match the notebook's eqNullSafe behavior or this ground-truth
# check would silently validate against the wrong rule.
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()

cur.execute(f"""
    SELECT REF_NO,
           MIN(BRANCH) AS SRC_BranchKey,
           MIN(customer_no) AS SRC_CustomerNo,
           MIN(Trans_Datetime) AS SRC_OrderDate,
           MAX(Trans_Datetime) AS SRC_LastActivityDate
    FROM InTrans
    WHERE Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
order_rows = cur.fetchall()
order_attrs = pd.DataFrame.from_records(
    [tuple(r) for r in order_rows],
    columns=["REF_NO", "SRC_BranchKey", "SRC_CustomerNo", "SRC_OrderDate", "SRC_LastActivityDate"],
)

cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPartsSales, SUM(COST_VAL) AS SRC_TotalPartsCost, COUNT(*) AS SRC_PartsCount
    FROM InTrans
    WHERE PART_NO NOT LIKE '*%'
      AND (FRANCHISE IS NULL OR FRANCHISE != 'ZP')
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
non_promo_rows = cur.fetchall()
non_promo = pd.DataFrame.from_records(
    [tuple(r) for r in non_promo_rows],
    columns=["REF_NO", "SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount"],
)

cur.execute(f"""
    SELECT REF_NO, SUM(SALE_VAL) AS SRC_TotalPromoDiscount, COUNT(*) AS SRC_PromoCount
    FROM InTrans
    WHERE PART_NO LIKE '*%'
      AND Trans_Datetime >= '2022-01-01'
      AND REF_NO IN ({placeholders})
    GROUP BY REF_NO
""")
promo_rows = cur.fetchall()
promo = pd.DataFrame.from_records(
    [tuple(r) for r in promo_rows],
    columns=["REF_NO", "SRC_TotalPromoDiscount", "SRC_PromoCount"],
)

# ------------------------------------------------------------------
# Assemble source-side dim_RepairOrder from scratch, independently of
# the notebook's own PySpark logic - same derivation rules, computed
# fresh in pandas.
# ------------------------------------------------------------------
source = order_attrs.merge(non_promo, on="REF_NO", how="left").merge(promo, on="REF_NO", how="left")
for col in ["SRC_TotalPartsSales", "SRC_TotalPartsCost", "SRC_PartsCount", "SRC_TotalPromoDiscount", "SRC_PromoCount"]:
    source[col] = source[col].fillna(0)

source["SRC_NetOrderValue"] = source["SRC_TotalPartsSales"] + source["SRC_TotalPromoDiscount"]
source["SRC_OriginalMargin"] = source["SRC_TotalPartsSales"] - source["SRC_TotalPartsCost"]
source["SRC_NetMargin"] = source["SRC_NetOrderValue"] - source["SRC_TotalPartsCost"]
source["SRC_DiscountAmount"] = source["SRC_TotalPromoDiscount"].abs()
source["SRC_DiscountPercent"] = source.apply(
    lambda r: 0.0 if r["SRC_TotalPartsSales"] == 0 else r["SRC_DiscountAmount"] / r["SRC_TotalPartsSales"],
    axis=1,
)

# ------------------------------------------------------------------
# Compare
# ------------------------------------------------------------------
source["REF_NO"] = source["REF_NO"].astype(str)
gold["REF_NO"] = gold["REF_NO"].astype(str)
merged = source.merge(gold, on="REF_NO", how="outer", indicator=True)

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 250)
print(f"Orders checked: {len(merged)} (expect {len(ALL_ROS)})")
print(merged.to_string(index=False))

NUMERIC_PAIRS = [
    ("SRC_TotalPartsSales", "TotalPartsSales"),
    ("SRC_TotalPartsCost", "TotalPartsCost"),
    ("SRC_PartsCount", "PartsCount"),
    ("SRC_TotalPromoDiscount", "TotalPromoDiscount"),
    ("SRC_PromoCount", "PromoCount"),
    ("SRC_NetOrderValue", "NetOrderValue"),
    ("SRC_OriginalMargin", "OriginalMargin"),
    ("SRC_NetMargin", "NetMargin"),
    ("SRC_DiscountAmount", "DiscountAmount"),
    ("SRC_DiscountPercent", "DiscountPercent"),
]

mismatch_mask = merged["_merge"] != "both"
for src_col, gold_col in NUMERIC_PAIRS:
    diff = (merged[src_col] - merged[gold_col]).abs()
    mismatch_mask = mismatch_mask | (diff > 0.01)

mismatches = merged[mismatch_mask]
print(f"\nOrders with a real mismatch on any of the 10 aggregate/calculated columns")
print(f"(off by >$0.01, or missing from one side): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All checked orders match EquipRDB ground truth exactly across all 10 aggregate/calculated columns.")
    print("BranchKey/CustomerNo/OrderDate/LastActivityDate are in the printed table above for manual eyeball")
    print("confirmation (identifiers/dates, not tolerance-compared numerics).")
```

**Real correction (found during code-quality review, fixed in a follow-up commit):** pyodbc returns Python `Decimal` objects for EquipRDB's `DECIMAL`/`NUMERIC` columns (`SALE_VAL`, `COST_VAL`, `BRANCH`, and the `COUNT(*)` results), which would raise `TypeError` when compared against the gold table's `float64` columns in the mismatch-detection loop. Fixed by adding `.astype(float)` casts on `order_attrs["SRC_BranchKey"]`, `non_promo["SRC_TotalPartsSales"/"SRC_TotalPartsCost"/"SRC_PartsCount"]`, and `promo["SRC_TotalPromoDiscount"/"SRC_PromoCount"]` immediately after each DataFrame is built — see commit `50234dec` in `data-projects`. The code block above has been left as originally planned for historical accuracy; run the actual committed file, not this block, when executing Step 2.

- [ ] **Step 2: Run the script**

This step requires Task 4 (Brian running the notebook) to have completed first, since it queries the real `dim_RepairOrder` table in `DP_Presentation`. Do not run it until Task 4 confirms the notebook ran successfully.

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_dim_repairorder_full_rebuild.py
```

Expected: `Orders checked: 16 (expect 16)`, then `Orders with a real mismatch...: 0 (expect 0)`.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_dim_repairorder_full_rebuild.py
git commit -m "Add ground-truth verification for full dim_RepairOrder rebuild

Independently recomputes all 15 columns against EquipRDB for the 11
known-tricky orders plus 5 arbitrary real ones, extending the pre-trim
verify_gold_parts_promo.py pattern to the restored column set.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Handoff — Brian runs the notebook in Fabric

This is Brian's own action; Claude cannot drive the Fabric portal interactively.

- [ ] **Step 1: Pull the committed notebook change into the Fabric workspace**

In the `DP - Presentation - Dev` workspace's Git integration pane, sync/update the `Build_Gold_PartsPromo` notebook so it picks up Task 1's commit.

- [ ] **Step 2: Run the notebook**

Open `Build_Gold_PartsPromo` in the Fabric portal and run all cells (or trigger it via `Pipeline_DP_Daily_Refresh`, if that's more convenient — the notebook's own `notebookId` is unchanged, only its internal code changed).

- [ ] **Step 3: Confirm success**

Check the notebook's own output:
- `dim_RepairOrder columns: 15 (expect 15 - full column set restored 2026-09-21)`
- The verification cell's printed table shows all 15 columns (not just `REF_NO`/`CustomerNo`) with real, non-null values for the 11 known-bad orders.

Report back with a screenshot or a copy of the printed output before Task 2 Step 2 runs.

---

### Task 4: Run the ground-truth verification and confirm

**Files:** none (uses Task 2's script)

- [ ] **Step 1: Run the verification script**

Now that Task 3 has confirmed the notebook ran, execute Task 2's script:

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_dim_repairorder_full_rebuild.py
```

- [ ] **Step 2: Confirm zero mismatches**

If mismatches are found, do not proceed — this means either the PySpark logic (Task 1) or the ground-truth SQL (Task 2) has a real bug; go back to `systematic-debugging` rather than guessing at a fix. If zero mismatches, dim_RepairOrder is confirmed correct against real source data.

- [ ] **Step 3: Report to Brian**

Summarize the verification result (16 orders checked, 0 mismatches across all 10 aggregate/calculated columns) so Brian can decide whether to visually confirm Parts Promo's margin/discount visuals in Desktop before considering this done — matching this project's established three-way verification pattern (DuckDB/ground-truth + Brian's own visual confirmation) used throughout Batch 1.

---

## Self-Review Notes

**Spec coverage:** Section 2 (full 15-column scope) → Task 1. Section 3 (column derivations) → Task 1 Step 2. Section 4 (architecture: extend existing cell, no other file changes) → Task 1 confines all logic changes to the one cell; Tasks 2–4 touch no other files. Section 5 (verification plan: independent computation, known-bad + arbitrary orders) → Task 2. Section 6 (out of scope: facts, report TMDL, 4 other dims) → no task touches any of those files.

**Placeholder scan:** No TBD/TODO; every step has literal code or literal commands.

**Type consistency:** Column names (`BranchKey`, `TotalPartsSales`, etc.) match exactly between Task 1's PySpark `.select(...)` list, Task 1 Step 4's verification `SELECT`, and Task 2's DuckDB `SELECT` — cross-checked against the spec's own column table.
