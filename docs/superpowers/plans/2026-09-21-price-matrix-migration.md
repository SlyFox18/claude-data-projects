# Price Matrix Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix a real gap in the Gold-layer `Fact_Part_Transactions` table (4 columns Price Matrix's own live DAX measures depend on, wrongly believed unused), then migrate the Price Matrix report itself from `LH_Master_Data` to `DP_Presentation`.

**Architecture:** Extend `Build_Gold_PartTransactions.Notebook`'s existing build to add 4 derived columns (`EffectiveListSalVal`, `EffectiveListMargin`, `MatrixSaleGained`, `MatrixMarginGained`) computed from fields already available in `Silver_InTrans`. Correct two docs that currently claim these columns are unused. Then repoint Price Matrix's 9 data-bearing tables from `LH_Master_Data` to `DP_Presentation`, trimming genuinely-unused columns per a fresh exhaustive audit (not the stale one that caused this gap), and fixing a `DateTime.LocalNow()` bug along the way.

**Tech Stack:** PySpark (Fabric notebook), DuckDB + `delta_scan()`/`pyodbc` for verification, Power BI Desktop (`.pbip`/TMDL), `pbir` CLI for visual-level field usage.

**Full design reference:** `docs/superpowers/specs/2026-09-21-price-matrix-migration-design.md` (approved).

---

## Context You Need

`Build_Gold_PartTransactions.Notebook/notebook-content.py` (in `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Inventory Analysis/`) builds `Fact_Part_Transactions`, shared by two reports: `Inventory Analysis` (uses only 8 columns, unaffected by this plan) and `Price Matrix` (the report this plan migrates). The notebook's own header comment currently claims none of the old production table's 8 "matrix-pricing" columns are used by either report — **that claim is wrong for Price Matrix**, confirmed via direct DAX-text grep of `Price Matrix.SemanticModel/definition/tables/MeasuresTable.tmdl`, cross-checked against real report visuals/bookmarks. 4 of those 8 columns (`EffectiveListSalVal`, `EffectiveListMargin`, `MatrixSaleGained`, `MatrixMarginGained`) are genuinely used, in measures like `Effective List Sale Value for Parts in Range` and `Matrix Sale Gained for Parts in Range` — literally the report's namesake functionality.

**Real derivation logic** (traced from the original production query, `projects/price matrix - report/queries/fact tables/Fact_Part_Transactions.pq`):
- `SellPrice1SaleVal = SellPrice1 * Quantity` (intermediate only)
- `ListSaleVal = ListPrice * Quantity` (intermediate only)
- `% Change = (SellPrice1SaleVal - ListSaleVal) / SellPrice1SaleVal`, or `0` if `SellPrice1SaleVal` is `0` (intermediate only)
- `EffectiveListSalVal = SaleAmount` if `TransactionTradeType = "W"`, else `SaleAmount * (1 - % Change)`
- `EffectiveListMargin = EffectiveListSalVal - CostAmount`
- `MatrixSaleGained = SaleAmount - EffectiveListSalVal`
- `MatrixMarginGained = Margin - EffectiveListMargin`

`SellPrice1`, `ListPrice`, and `TradeType` (renamed `TransactionTradeType`, matching the original query) are real columns in `Silver_InTrans` but **not currently read** by `Build_Gold_PartTransactions.Notebook` — its current `spark.read.table("Silver_InTrans").select(...)` only pulls `TransDatetime`, `Branch`, `Franchise`, `PartNumber`, `Type`, `Qty`, `SaleValue`, `CostValue`, `Description`. All three need adding.

**Real-tool boundary:** Claude writes/commits the notebook code, doc corrections, and DuckDB verification scripts, and can run the verification scripts directly. Claude **cannot** run the Fabric notebook — that's Brian's action (Task 4). For the report-layer work: Brian publishes Price Matrix as-is to `RP - Dev` first (Task 6) — **Claude must not touch any TMDL file before that publish happens** (per the corrected Batch 1 workflow: Desktop's own in-memory state silently overwrites an external file edit if the report is open, so pre-editing is unsafe and pointless). Once published and confirmed not open in Desktop, Claude edits the `RP - Dev` copies directly (Tasks 7-10). The actual Desktop refresh/publish confirmation is Brian's action (Task 11).

---

### Task 1: Extend `Build_Gold_PartTransactions.Notebook` with the 4 matrix-pricing columns

**Files:**
- Modify: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Presentation - Dev\Fact Tables\Inventory Analysis\Build_Gold_PartTransactions.Notebook\notebook-content.py`

- [ ] **Step 1: Add `TradeType`, `SellPrice1`, `ListPrice` to the initial `Silver_InTrans` read**

Find:
```python
intrans = spark.read.table("Silver_InTrans").select(
    "TransDatetime", "Branch", "Franchise", "PartNumber", "Type",
    "Qty", "SaleValue", "CostValue", "Description",
)
```
Replace with:
```python
intrans = spark.read.table("Silver_InTrans").select(
    "TransDatetime", "Branch", "Franchise", "PartNumber", "Type",
    "Qty", "SaleValue", "CostValue", "Description",
    "TradeType", "SellPrice1", "ListPrice",
)
```

- [ ] **Step 2: Carry the 3 new fields through the rename step**

Find:
```python
renamed = filtered.select(
    F.col("TransDatetime").alias("TransactionDate"),
    F.col("Branch"),
    F.col("Franchise"),
    F.col("PartNumber"),
    F.col("Type"),
    F.col("Qty").alias("Quantity"),
    F.col("SaleValue").alias("SaleAmount"),
    F.col("CostValue").alias("CostAmount"),
    F.col("Description"),
)
```
Replace with:
```python
renamed = filtered.select(
    F.col("TransDatetime").alias("TransactionDate"),
    F.col("Branch"),
    F.col("Franchise"),
    F.col("PartNumber"),
    F.col("Type"),
    F.col("Qty").alias("Quantity"),
    F.col("SaleValue").alias("SaleAmount"),
    F.col("CostValue").alias("CostAmount"),
    F.col("Description"),
    F.col("TradeType").alias("TransactionTradeType"),
    F.col("SellPrice1"),
    F.col("ListPrice"),
)
```

- [ ] **Step 3: Insert the matrix-pricing derivation between `with_margin` and `with_sales_type`**

Find:
```python
with_margin = (
    renamed
    .withColumn("Margin", F.col("SaleAmount") - F.col("CostAmount"))
    .withColumn(
        "MarginPercent",
        F.when(F.col("SaleAmount") != 0, (F.col("SaleAmount") - F.col("CostAmount")) / F.col("SaleAmount"))
         .otherwise(F.lit(None).cast("double")),
    )
)

# SalesType - the one column confirmed directly used in a Price Matrix
# visual. Computed from Description, which is then dropped (not itself
# used by either report).
with_sales_type = with_margin.withColumn(
    "SalesType",
    F.when(F.col("Description").contains("Inv No."), "Work Order").otherwise("Over the Counter"),
).drop("Description")
```
Replace with:
```python
with_margin = (
    renamed
    .withColumn("Margin", F.col("SaleAmount") - F.col("CostAmount"))
    .withColumn(
        "MarginPercent",
        F.when(F.col("SaleAmount") != 0, (F.col("SaleAmount") - F.col("CostAmount")) / F.col("SaleAmount"))
         .otherwise(F.lit(None).cast("double")),
    )
)

# Matrix-pricing columns - RESTORED 2026-09-21. Confirmed genuinely used by
# Price Matrix's own live DAX measures (Effective List Sale Value for Parts
# in Range, Matrix Sale Gained for Parts in Range, etc.), contradicting this
# notebook's own prior "not used anywhere" claim above - see the corrected
# header comment and docs/superpowers/specs/2026-09-21-price-matrix-migration-design.md.
# Derivation traced from the original production query (projects/price
# matrix - report/queries/fact tables/Fact_Part_Transactions.pq).
# SellPrice1SaleVal/ListSaleVal/% Change are intermediates only - nothing
# references them directly, so they're not persisted as output columns.
with_matrix_pricing = (
    with_margin
    .withColumn("_SellPrice1SaleVal", F.col("SellPrice1") * F.col("Quantity"))
    .withColumn("_ListSaleVal", F.col("ListPrice") * F.col("Quantity"))
    .withColumn(
        "_PctChange",
        F.when(F.col("_SellPrice1SaleVal") != 0, (F.col("_SellPrice1SaleVal") - F.col("_ListSaleVal")) / F.col("_SellPrice1SaleVal"))
         .otherwise(F.lit(0.0)),
    )
    .withColumn(
        "EffectiveListSalVal",
        F.when(F.col("TransactionTradeType") == "W", F.col("SaleAmount"))
         .otherwise(F.col("SaleAmount") * (F.lit(1.0) - F.col("_PctChange"))),
    )
    .withColumn("EffectiveListMargin", F.col("EffectiveListSalVal") - F.col("CostAmount"))
    .withColumn("MatrixSaleGained", F.col("SaleAmount") - F.col("EffectiveListSalVal"))
    .withColumn("MatrixMarginGained", F.col("Margin") - F.col("EffectiveListMargin"))
    .drop("_SellPrice1SaleVal", "_ListSaleVal", "_PctChange")
)

# SalesType - the one column confirmed directly used in a Price Matrix
# visual. Computed from Description, which is then dropped (not itself
# used by either report).
with_sales_type = with_matrix_pricing.withColumn(
    "SalesType",
    F.when(F.col("Description").contains("Inv No."), "Work Order").otherwise("Over the Counter"),
).drop("Description")
```

- [ ] **Step 4: Add the 4 new columns to the final `select(...)`**

Find:
```python
fact_part_transactions = with_branch.select(
    "TransactionDate", "Branch", "BranchKey", "FranchiseKey", "PartNumber",
    "PartNumberKey", "Type", "Quantity", "SaleAmount", "CostAmount",
    "Margin", "MarginPercent", "SalesType",
)
```
Replace with:
```python
fact_part_transactions = with_branch.select(
    "TransactionDate", "Branch", "BranchKey", "FranchiseKey", "PartNumber",
    "PartNumberKey", "Type", "Quantity", "SaleAmount", "CostAmount",
    "Margin", "MarginPercent", "SalesType",
    "EffectiveListSalVal", "EffectiveListMargin", "MatrixSaleGained", "MatrixMarginGained",
)
```

`TransactionTradeType`, `SellPrice1`, and `ListPrice` are intentionally NOT in this final select — confirmed via the same DAX-text grep that found the 4 real columns, nothing in Price Matrix references them directly; they're pure intermediate inputs to `EffectiveListSalVal`.

- [ ] **Step 5: Update the sample/diagnostic cell's null-check to sanity-check the new columns too**

Find:
```python
print("\n-- Null key rates (any large unexpected gap is worth investigating) --")
null_check = spark.sql("""
    SELECT
        SUM(CASE WHEN BranchKey IS NULL THEN 1 ELSE 0 END) AS NullBranchKey,
        SUM(CASE WHEN PartNumberKey IS NULL THEN 1 ELSE 0 END) AS NullPartNumberKey,
        SUM(CASE WHEN FranchiseKey IS NULL THEN 1 ELSE 0 END) AS NullFranchiseKey,
        COUNT(*) AS TotalRows
    FROM delta.`Tables/Fact_Part_Transactions`
""").toPandas()
print(null_check.to_string())
```
Replace with:
```python
print("\n-- Null key rates (any large unexpected gap is worth investigating) --")
null_check = spark.sql("""
    SELECT
        SUM(CASE WHEN BranchKey IS NULL THEN 1 ELSE 0 END) AS NullBranchKey,
        SUM(CASE WHEN PartNumberKey IS NULL THEN 1 ELSE 0 END) AS NullPartNumberKey,
        SUM(CASE WHEN FranchiseKey IS NULL THEN 1 ELSE 0 END) AS NullFranchiseKey,
        SUM(CASE WHEN EffectiveListSalVal IS NULL THEN 1 ELSE 0 END) AS NullEffectiveListSalVal,
        COUNT(*) AS TotalRows
    FROM delta.`Tables/Fact_Part_Transactions`
""").toPandas()
print(null_check.to_string())

print("\n-- Matrix-pricing self-consistency (internal arithmetic wiring check) --")
matrix_check = spark.sql("""
    SELECT
        SUM(CASE WHEN ABS(EffectiveListMargin - (EffectiveListSalVal - CostAmount)) > 0.01 THEN 1 ELSE 0 END) AS EffectiveListMarginMismatches,
        SUM(CASE WHEN ABS(MatrixSaleGained - (SaleAmount - EffectiveListSalVal)) > 0.01 THEN 1 ELSE 0 END) AS MatrixSaleGainedMismatches,
        SUM(CASE WHEN ABS(MatrixMarginGained - (Margin - EffectiveListMargin)) > 0.01 THEN 1 ELSE 0 END) AS MatrixMarginGainedMismatches
    FROM delta.`Tables/Fact_Part_Transactions`
""").toPandas()
print("(all three expect 0 - these check the notebook's own internal arithmetic, not against external source)")
print(matrix_check.to_string())
```

**Real correction (found during code-quality review, fixed in a follow-up commit):** the `_PctChange` guard as originally written (`F.when(F.col("_SellPrice1SaleVal") != 0, ...).otherwise(F.lit(0.0))`) was inconsistent — a null `SellPrice1` silently defaulted to `0.0` (treated as "no price change"), while a null `ListPrice` cascaded to a null result instead, with no comment explaining either as deliberate. Fixed by adding an explicit `.isNull()` branch first, so both null inputs now propagate null consistently (matching the sibling `MarginPercent` column's own null-preserving pattern), while a genuinely zero `SellPrice1SaleVal` still resolves to `0.0` per the original production formula's intent — see commit `c98228e4` in `fabric-workspace-docs`. The code block above has been left as originally planned for historical accuracy; implementers following this plan in the future should use the null-safe 3-branch form.

- [ ] **Step 6: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inventory Analysis/Build_Gold_PartTransactions.Notebook/notebook-content.py"
git commit -m "Restore 4 matrix-pricing columns to Fact_Part_Transactions

EffectiveListSalVal, EffectiveListMargin, MatrixSaleGained, and
MatrixMarginGained are genuinely used by Price Matrix's own live DAX
measures - the prior 'not used anywhere' audit only checked
visual-level references, not DAX measure bodies, and missed this.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Correct the two wrong "not used anywhere" claims

**Files:**
- Modify: `C:\Users\bfox\Documents\Git-Projects\data-projects\docs\architecture\lh-master-data-facts-catalog.md`
- Modify: `C:\Users\bfox\Documents\Git-Projects\fabric-workspace-docs\workspaces\DP - Presentation - Dev\Fact Tables\Inventory Analysis\Build_Gold_PartTransactions.Notebook\notebook-content.py`

- [ ] **Step 1: Correct the facts catalog**

In `docs/architecture/lh-master-data-facts-catalog.md`, find the `Fact_Part_Transactions REDESIGNED` section's real-usage-audit bullet describing Price Matrix (the paragraph starting `- \`Price Matrix\` imports nearly all 70+ real columns wholesale...` and ending `...despite the report's own name.`). Add a note directly after that paragraph:

```markdown
**Correction (2026-09-21):** the claim above that none of the matrix-pricing
columns are used is wrong. A direct grep of `MeasuresTable.tmdl`'s actual DAX
measure bodies (not just visual-level field references, which is what the
original audit checked) found 4 of the 8 matrix-pricing columns
(`EffectiveListSalVal`, `EffectiveListMargin`, `MatrixSaleGained`,
`MatrixMarginGained`) genuinely referenced by real measures (`Effective List
Sale Value for Parts in Range`, `Matrix Sale Gained for Parts in Range`, and
others), confirmed placed on real report visuals and bookmarks. See
`docs/superpowers/specs/2026-09-21-price-matrix-migration-design.md` for the
full finding and the fix. `CustomerNo` is also DAX-referenced but its
measure (`Customer Concentration`) isn't placed on any page - confirmed
genuinely unused, unlike the other 4.
```

- [ ] **Step 2: Correct the notebook's own header comment**

In `Build_Gold_PartTransactions.Notebook/notebook-content.py`, find the "REAL USAGE AUDIT" comment block (the one describing "only 6 more columns are ever actually referenced... NONE of the matrix-pricing columns... are referenced anywhere in either report"). Add directly after that block, before the `# DECISION` comment:

```python
#
# CORRECTION (2026-09-21): the claim above that none of the matrix-pricing
# columns are used is wrong for Price Matrix. A direct grep of
# MeasuresTable.tmdl's actual DAX measure bodies (not just visual-level
# field references, which is what the audit above checked) found 4 of the
# 8 matrix-pricing columns genuinely referenced by real, live measures -
# see this cell's own "RESTORED 2026-09-21" comment below for the fix and
# docs/superpowers/specs/2026-09-21-price-matrix-migration-design.md for
# the full finding.
```

- [ ] **Step 3: Commit both**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add docs/architecture/lh-master-data-facts-catalog.md
git commit -m "Correct wrong Fact_Part_Transactions usage claim in facts catalog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"

cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Inventory Analysis/Build_Gold_PartTransactions.Notebook/notebook-content.py"
git commit -m "Correct wrong matrix-pricing usage claim in notebook header

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

Note: this second commit will be combined with Task 1's commit into one push once both are ready — Task 1's Step 6 and this step can be committed separately but should be pushed together before Task 4.

---

### Task 3: Push, then hand off to Brian to run the notebook

**Files:** none.

- [ ] **Step 1: Push to origin**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git push origin dev
```

(Learned this session: Fabric's Git integration reads from GitHub, not the local clone — a commit that's only local is invisible to the portal.)

- [ ] **Step 2: Brian — pull the change into the workspace and run the notebook**

In the `DP - Presentation - Dev` workspace's Git integration pane, sync/update so `Build_Gold_PartTransactions` picks up Task 1's commit. Run the notebook (directly, or via `Pipeline_DP_Daily_Refresh`).

- [ ] **Step 3: Confirm success**

Check the notebook's own printed output: the null-check should show `NullEffectiveListSalVal` at a reasonable level (not 100% null — would indicate `SellPrice1`/`ListPrice` aren't populating), and the matrix-pricing self-consistency check should show all 3 mismatch counts at `0`. Report back before Task 4 proceeds.

---

### Task 4: Write and run the ground-truth verification script

**Files:**
- Create: `C:\Users\bfox\Documents\Git-Projects\data-projects\.claude\queries\adhoc\dp-bronze-verify\verify_fact_parttransactions_matrix_pricing.py`

`Fact_Part_Transactions` has no persisted natural row key (unlike `dim_RepairOrder`'s `REF_NO`), so this script matches sample rows between the Gold table and `EquipRDB` using a composite of already-present columns (`Branch`, `PartNumber`, `TransactionDate`, `SaleAmount`) — selective enough for spot-check verification, not a guaranteed-unique key. Combined with Task 1's internal self-consistency check (already proven `0` mismatches), this is sufficient to confirm the real, external-facing input (the `TransactionTradeType`/`SellPrice1`/`ListPrice`-driven `EffectiveListSalVal` formula) is correct.

- [ ] **Step 1: Write the script**

```python
"""
FACT_PART_TRANSACTIONS MATRIX-PRICING VERIFICATION - GROUND TRUTH PROOF
============================================================================
Independently recomputes EffectiveListSalVal (and its 3 dependents:
EffectiveListMargin, MatrixSaleGained, MatrixMarginGained) directly against
EquipRDB for a sample of real Type IN ('C','I') transactions, and compares
against Build_Gold_PartTransactions.Notebook's real output in
DP_Presentation.

No natural row key is persisted on this table, so rows are matched between
Gold and EquipRDB via a composite of Branch/PartNumber/TransactionDate/
SaleAmount - selective enough for spot-check verification. The notebook's
own internal self-consistency check (EffectiveListMargin/MatrixSaleGained/
MatrixMarginGained arithmetic, verified 0 mismatches in Task 1) already
proves those 3 are wired correctly off EffectiveListSalVal; this script's
job is verifying EffectiveListSalVal's own external inputs
(SellPrice1/ListPrice/TransactionTradeType) are correct.

Run manually after Brian confirms the notebook ran successfully
(Task 3 of docs/superpowers/plans/2026-09-21-price-matrix-migration.md).
============================================================================
"""

import duckdb
import pyodbc
import pandas as pd

DP_PRESENTATION_WS_ID = "73fd5443-240e-410a-990a-98827f32c087"   # DP - Presentation - Dev workspace
DP_PRESENTATION_LH_ID = "966efc8a-16f9-423b-aa43-e368fcd8fb91"   # DP_Presentation lakehouse
dp_base = f"abfss://{DP_PRESENTATION_WS_ID}@onelake.dfs.fabric.microsoft.com/{DP_PRESENTATION_LH_ID}/Tables"

con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

# ------------------------------------------------------------------
# Pull a sample of 20 real rows from the Gold table - Franchise 7
# (Price Matrix's own real filter, FranchiseKey = 7) isn't a column on
# this table, so sample broadly across real transactions instead.
# ------------------------------------------------------------------
sample = con.execute(f"""
    SELECT Branch, PartNumber, TransactionDate, SaleAmount, CostAmount,
           EffectiveListSalVal
    FROM delta_scan('{dp_base}/Fact_Part_Transactions')
    WHERE SaleAmount != 0
    ORDER BY TransactionDate DESC
    LIMIT 20
""").df()
print(f"Sample rows pulled from Gold: {len(sample)} (expect 20)")

# ------------------------------------------------------------------
# For each sampled row, pull the matching real InTrans row(s) from
# EquipRDB and independently recompute EffectiveListSalVal.
# ------------------------------------------------------------------
cn = pyodbc.connect('DSN=EquipRDB64', timeout=30)
cur = cn.cursor()

results = []
for _, row in sample.iterrows():
    cur.execute("""
        SELECT SELL_PRICE1, LIST_PRICE, QTY, TRADE_TYPE, SALE_VAL
        FROM InTrans
        WHERE BRANCH = ? AND PART_NO = ? AND Trans_Datetime = ? AND SALE_VAL = ?
    """, row["Branch"], row["PartNumber"], row["TransactionDate"], float(row["SaleAmount"]))
    src_rows = cur.fetchall()

    if len(src_rows) != 1:
        results.append({
            "Branch": row["Branch"], "PartNumber": row["PartNumber"],
            "Match": f"AMBIGUOUS ({len(src_rows)} source rows matched)" if src_rows else "NOT FOUND",
            "Gold_EffectiveListSalVal": row["EffectiveListSalVal"],
            "Src_EffectiveListSalVal": None,
        })
        continue

    sell_price1, list_price, qty, trade_type, sale_val = src_rows[0]
    sell_price1 = float(sell_price1) if sell_price1 is not None else 0.0
    list_price = float(list_price) if list_price is not None else 0.0
    qty = float(qty) if qty is not None else 0.0
    sale_val = float(sale_val)

    sell_price1_sale_val = sell_price1 * qty
    list_sale_val = list_price * qty
    pct_change = 0.0 if sell_price1_sale_val == 0 else (sell_price1_sale_val - list_sale_val) / sell_price1_sale_val
    src_effective_list_sal_val = sale_val if trade_type == "W" else sale_val * (1 - pct_change)

    results.append({
        "Branch": row["Branch"], "PartNumber": row["PartNumber"],
        "Match": "OK",
        "Gold_EffectiveListSalVal": row["EffectiveListSalVal"],
        "Src_EffectiveListSalVal": src_effective_list_sal_val,
    })

results_df = pd.DataFrame(results)
results_df["Diff"] = (results_df["Gold_EffectiveListSalVal"] - results_df["Src_EffectiveListSalVal"]).abs()

pd.set_option("display.max_columns", None)
pd.set_option("display.width", 200)
print(results_df.to_string(index=False))

matched = results_df[results_df["Match"] == "OK"]
mismatches = matched[matched["Diff"] > 0.01]
unmatched = results_df[results_df["Match"] != "OK"]

print(f"\nMatched rows: {len(matched)} (expect close to 20 - some ambiguous/not-found matches from the")
print(f"composite key are possible on a high-volume table and are reported separately, not counted as failures)")
print(f"Unmatched/ambiguous rows: {len(unmatched)}")
print(f"Real mismatches among matched rows (off by >$0.01): {len(mismatches)} (expect 0)")
if len(mismatches):
    print(mismatches.to_string(index=False))
else:
    print("All matched rows' EffectiveListSalVal match EquipRDB ground truth exactly.")
```

- [ ] **Step 2: Run the script**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
python .claude/queries/adhoc/dp-bronze-verify/verify_fact_parttransactions_matrix_pricing.py
```

Expected: `0` real mismatches among matched rows. If most/all rows come back `NOT FOUND` or `AMBIGUOUS`, the composite match key isn't selective enough on this table's real data — investigate rather than assuming correctness either way (don't just widen the tolerance or drop the check).

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/data-projects"
git add .claude/queries/adhoc/dp-bronze-verify/verify_fact_parttransactions_matrix_pricing.py
git commit -m "Add ground-truth verification for Fact_Part_Transactions matrix pricing

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Brian — publish Price Matrix as-is to RP - Dev

**Files:** none — Brian's action in Power BI Desktop/Fabric portal.

- [ ] **Step 1: Confirm Price Matrix isn't open anywhere in Desktop**

- [ ] **Step 2: Open Price Matrix from its current production location and publish unmodified to `RP - Dev`**

Do not change the data source yet — this publish is only to create a clean `RP - Dev` baseline (still pointed at `LH_Master_Data`) while `RP - Parts Reports` stays untouched as the production fallback, exactly like Batch 1's real final workflow.

- [ ] **Step 3: In the Fabric portal for `RP - Dev`, Source control → Commit**

This pushes the unmodified baseline into `fabric-workspace-docs`. Report back once done — Claude's role resumes at Task 6 once this lands and is confirmed not open in Desktop.

---

### Task 6: Exhaustive real-usage audit across all 9 tables

**Files:** none — investigation only. Findings get documented directly in this plan (per this project's established discipline) before Task 7 proceeds.

- [ ] **Step 1: Run `pbir fields list` for visual-level usage**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Price Matrix.Report"
```

- [ ] **Step 2: Grep every measure table's DAX text for column references, per table**

This is the check that caught this whole plan's central finding — do not skip it or rely on Step 1 alone.

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition"
for tbl in Fact_Inventory Fact_Part_Transactions dim_BranchLocation dim_DateTable dim_DealerGroupCode dim_Franchise dim_Parts dim_SLC dim_Source dim_VendorCode; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_%]+)\]/\1/" | sort -u
done
```

- [ ] **Step 3: Cross-reference each table's real usage against its current TMDL column declarations**

For each of the 9 tables, compare Step 1 + Step 2's real usage against the table's own `.tmdl` file's declared `column` blocks. Document the findings directly in this plan (add a subsection here per table: columns confirmed used, columns confirmed safe to trim).

- [ ] **Step 4: Check for the `DateTime.LocalNow()` bug beyond `Fact_Part_Transactions`**

```bash
grep -rn "DateTime.LocalNow" "workspaces/RP - Dev/Price Matrix.SemanticModel/"
```

Confirm whether `Data Refresh.tmdl` or any other table has this pattern beyond the already-known `Fact_Part_Transactions.tmdl` instance.

- [ ] **Step 5: Check for raw `PartNumber` text usage (control-character exposure)**

```bash
grep -rn "PartNumber" "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/relationships.tmdl"
grep -rln "\[PartNumber\]" "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/"*.tmdl
```

Confirm whether any relationship or M-query transform joins/filters on raw `PartNumber` text (as opposed to `PartNumberKey`), which would expose the known `dim_Parts` control-character issue.

---

### Task 7: Repoint all 9 tables' SQL connections

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Fact_Inventory.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Fact_Part_Transactions.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_DealerGroupCode.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_Franchise.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_Parts.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_SLC.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_Source.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/dim_VendorCode.tmdl`

- [ ] **Step 1: Edit each table's partition source**

In each of the 9 files, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item="<TableName>"` changes — every table exists in `DP_Presentation` under its exact real name (confirmed via `fab ls` this session).

- [ ] **Step 2: Confirm no `LH_Master_Data` references remain**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Price Matrix.SemanticModel/"
```
Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Price Matrix to DP_Presentation

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 8: Fix the `DateTime.LocalNow()` bug

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Fact_Part_Transactions.tmdl`
- Modify (if Task 6 Step 4 found the same pattern): `fabric-workspace-docs/workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Data Refresh.tmdl`

- [ ] **Step 1: Fix `Fact_Part_Transactions.tmdl`'s rolling-window filter**

Find:
```
				    FilteredRows = Table.SelectRows(dbo_Fact_Part_Transactions, each [TransactionDate] >= Date.AddMonths(Date.From(DateTime.LocalNow()), -13)),
```
Replace with (per `.claude/queries/DATA-REFRESH-TEMPLATE.pq`'s established fix pattern):
```
				    LocalNow = DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -6),
				    FilteredRows = Table.SelectRows(dbo_Fact_Part_Transactions, each [TransactionDate] >= Date.AddMonths(Date.From(LocalNow), -13)),
```

- [ ] **Step 2: If Task 6 Step 4 found the same pattern in `Data Refresh.tmdl`, fix it the same way**

(Exact replacement depends on that file's real current content — read it first, apply the same `DateTimeZone.SwitchZone(DateTimeZone.UtcNow(), -6)` pattern.)

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Fact_Part_Transactions.tmdl"
git commit -m "Fix DateTime.LocalNow() UTC-not-local bug in Price Matrix

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 9: Trim genuinely-unused columns per Task 6's findings

**Files:** determined by Task 6 Step 3's documented findings — likely all 9 tables, `Fact_Part_Transactions.tmdl` most heavily (68 declared columns vs. ~14 confirmed used).

- [ ] **Step 1: For each table with unused columns, remove the unused `column` blocks from the TMDL AND add a matching `Table.SelectColumns` to the M query**

Per the Batch 0 lesson: a TMDL-only trim doesn't survive a Desktop refresh — Power Query re-detects and silently re-adds any column the underlying query can still return. Both the model declaration and the M query itself must be trimmed together.

The exact column lists come from Task 6 Step 3's findings, documented in this plan before this task starts — do not guess or trim speculatively.

- [ ] **Step 2: Confirm each trimmed table's declared column count matches its M query's real output count**

```bash
grep -c "^\tcolumn " "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/Fact_Part_Transactions.tmdl"
```
(repeat per trimmed table) — cross-check against the `Table.SelectColumns` list in that same file's M query.

- [ ] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Price Matrix.SemanticModel/definition/tables/"*.tmdl
git commit -m "Trim genuinely-unused columns on Price Matrix per exhaustive audit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 10: Push all report-layer changes

**Files:** none.

- [ ] **Step 1: Push to origin**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git push origin dev
```

---

### Task 11: Brian — pull into RP - Dev, refresh, publish, and confirm

**Files:** none — Brian's action.

- [ ] **Step 1: In the `RP - Dev` workspace's Git integration pane, sync/update to pick up Tasks 7-9's commits**

- [ ] **Step 2: Open Price Matrix from `RP - Dev` in Desktop, refresh**

Watch for "column does not exist" errors — same pattern as Batch 1. If any appear, that means Task 6's audit missed a real usage; investigate before assuming the trim is wrong, matching this project's established discipline.

- [ ] **Step 3: Visually confirm the matrix-pricing visuals**

Specifically check the visuals/measures that depend on the 4 restored columns (`Matrix Performance Summary`, `Matrix ROI Analysis`, `Effective List Sale Value for Parts in Range`, etc.) against the real, currently-live `RP - Parts Reports` production report's output.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs a final post-publish DuckDB row-count/spot-check against `DP_Presentation` to close out the migration (same pattern as every prior report migration's final verification step).

---

## Self-Review Notes

**Spec coverage:** Section 3 (backend fix) → Task 1. Section 4 (doc correction) → Task 2. Section 5 (report-layer migration: publish-first workflow, exhaustive audit, repoint, trim, `DateTime.LocalNow()` fix, `PartNumber` check) → Tasks 5-9. Section 6 (verification: ground-truth script + Brian's visual confirmation) → Tasks 4 and 11. Section 2/7 (out of scope: `CustomerNo`, the ~55 other raw columns, `Fact_Inventory`'s own build, `Inventory Analysis`) → no task touches any of these.

**Placeholder scan:** Task 8 Step 2 and Task 9 have content that depends on Task 6's findings rather than a fully pre-specified diff — this is a real sequential dependency (the audit has to happen before its findings can be trimmed), not a placeholder; Task 6 itself is fully concrete (exact commands, no guessing).

**Type consistency:** Column names (`EffectiveListSalVal`, `EffectiveListMargin`, `MatrixSaleGained`, `MatrixMarginGained`) match exactly across Task 1's notebook code, Task 1 Step 5's diagnostic query, and Task 4's verification script — cross-checked against the spec's own derivation table.
