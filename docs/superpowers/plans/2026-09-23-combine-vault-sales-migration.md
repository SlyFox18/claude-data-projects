# Combine Vault Sales Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Combine Vault Sales report from `LH_Master_Data` to `DP_Presentation`, building 3 genuinely new Gold-layer tables (`Fact_Branch12_Transactions`, `dim_Branch12_Parts`, `dim_BranchPartInventory`) and resolving the long-deferred circular dependency between the fact and `dim_Branch12_Parts`.

**Architecture:** A stable hash of `PartNumber` replaces `dim_Branch12_Parts`'s fragile sequential-index surrogate key, letting the fact compute its own `PartNumberKey` without joining the dimension. This turns the circular dependency into a clean one-directional build order: Fact → (`dim_Branch12_Parts`, `dim_BranchPartInventory`). Report-layer work follows the same exhaustive-audit-before-trim pattern used on every prior report this project, including the now-routine `dim_DateTable` "today-relative column" cross-check.

**Tech Stack:** PySpark notebooks in Microsoft Fabric (`DP - Presentation - Dev` workspace, `DP_Presentation` lakehouse), `fab` CLI for deployment, TMDL for the semantic model, DuckDB for verification.

---

## Critical shared detail: the `PartNumberKey` hash formula

**This exact expression must be used byte-for-byte in both `Build_Gold_Branch12Transactions.Notebook` and `Build_Gold_Branch12Parts.Notebook`.** If the two notebooks compute the hash even slightly differently (different case-folding, different whitespace handling, different hash function), `PartNumberKey` values won't align between the fact and dimension and every relationship in the report breaks silently.

```python
from pyspark.sql import functions as F

# PartNumber must already be cleaned (uppercased, trimmed, null-safe empty
# string) via the same pattern in both notebooks BEFORE this is applied:
#   F.upper(F.trim(F.coalesce(F.col("PartNumber"), F.lit(""))))
#
# Then the key:
PartNumberKeyExpr = F.when(F.col("PartNumber") == "", F.lit(-1)).otherwise(
    F.abs(F.xxhash64(F.col("PartNumber")))
).cast("long")
```

`-1` is reserved as a literal sentinel for blank/missing `PartNumber` only (matching the original's "Unknown" convention) — never hashed.

---

### Task 1: `Build_Gold_Branch12Transactions.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Transactions.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Transactions.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

This notebook is self-contained — it does **not** depend on `dim_Branch12_Parts` at all (that's the whole point of the hash-based key). It only needs `Silver_InTrans`, already confirmed present in `DP_Presentation` with all required columns (`TransDatetime, ModifiedDate, RONumber, Type, PartNumber, Description, Franchise, Qty, CostValue, SellPrice1, ListPrice, TransferBranch, Branch`).

- [ ] **Step 1: Create the Fabric folder**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab mkdir "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder"
```
Expected: folder created (or "already exists" if a prior partial run created it — that's fine).

- [ ] **Step 2: Write the notebook**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Transactions.Notebook/notebook-content.py`:

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

# Build_Gold_Branch12Transactions
# Purpose: Reproduce production's Fact_Branch12_Transactions
# (df_Fact_Branch12_Transactions.Dataflow in LH_Master_Data), part of the
# Combine Vault Sales migration (2026-09-23).
#
# SOURCE: Silver_InTrans (already shortcut/built in DP_Presentation).
#
# GRAIN: One row per Branch 12 parts transaction. Negative Qty = sale
# (transfer out), positive Qty = inventory addition (transfer in).
#
# REAL DEPARTURE FROM PRODUCTION: the original looked up PartNumberKey via
# a join to dim_Branch12_Parts. This notebook computes PartNumberKey as a
# stable hash of PartNumber instead, so this fact is fully self-contained
# and does not need dim_Branch12_Parts to exist first - this is what
# resolves the circular dependency between the fact and dim_Branch12_Parts
# (both used to read the other's last materialized state). The same hash
# formula is used verbatim in Build_Gold_Branch12Parts.Notebook so the two
# tables' keys align. See docs/superpowers/specs/
# 2026-09-23-combine-vault-sales-migration-design.md for the full design.
#
# All other business logic (IsSale/IsTransfer flags, SalesQty/CostValue/
# SaleValue/MarginDollars sign-correction) ported faithfully - no bugs
# found in that logic, nothing to fix.

print("=" * 80)
print("BUILD_GOLD_BRANCH12TRANSACTIONS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from datetime import datetime, timedelta
from pyspark.sql import functions as F
import pytz

# STEP 1: DST-safe "now" in US/Central, matching the pattern already used
# on Build_Gold_FirstPassFill.Notebook - replaces the original's naive
# DateTime.LocalNow() (which returns UTC in the Fabric service, not local).
central = pytz.timezone("America/Chicago")
today_central = datetime.now(pytz.utc).astimezone(central).date()
range_start = today_central - timedelta(days=365 * 3)

# STEP 2: load and filter to Branch 12, last 3 years.
source = spark.read.table("Silver_InTrans")
branch12 = source.filter(F.col("Branch") == "12").filter(
    F.to_date("TransDatetime") >= F.lit(range_start)
)
print(f"Branch 12 transactions, last 3 years: {branch12.count():,}")

# STEP 3: select essential columns.
selected = branch12.select(
    "TransDatetime", "ModifiedDate", "RONumber", "Type", "PartNumber",
    "Description", "Franchise", "Qty", "CostValue", "SellPrice1", "ListPrice",
    "TransferBranch",
)

# STEP 4: clean text fields.
cleaned = (
    selected
    .withColumn("PartNumber", F.upper(F.trim(F.coalesce(F.col("PartNumber"), F.lit("")))))
    .withColumn("Description", F.initcap(F.trim(F.coalesce(F.col("Description"), F.lit("")))))
    .withColumn("Franchise", F.upper(F.trim(F.coalesce(F.col("Franchise"), F.lit("")))))
    .withColumn("Type", F.upper(F.trim(F.coalesce(F.col("Type"), F.lit("")))))
    .withColumn("RONumber", F.upper(F.trim(F.coalesce(F.col("RONumber").cast("string"), F.lit("")))))
    .withColumn(
        "TransferBranch",
        F.when(F.col("TransferBranch").isNull(), None)
         .otherwise(F.upper(F.trim(F.col("TransferBranch")))),
    )
    .withColumn("Qty", F.coalesce(F.col("Qty").cast("double"), F.lit(0.0)))
    .withColumn("CostValue", F.coalesce(F.col("CostValue").cast("double"), F.lit(0.0)))
    .withColumn("SellPrice1", F.coalesce(F.col("SellPrice1").cast("double"), F.lit(0.0)))
    .withColumn("ListPrice", F.coalesce(F.col("ListPrice").cast("double"), F.lit(0.0)))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# STEP 5: Branch 12 business logic - sales identification.
# CRITICAL: negative Qty = SALE (transfer out), positive Qty = INVENTORY
# ADDITION (transfer in). Faithful port of the original's logic.
with_sale_flags = (
    cleaned
    .withColumn("IsSale", F.col("Qty") < 0)
    .withColumn("RawQty", F.col("Qty"))
    .withColumn("SalesQty", F.when(F.col("Qty") < 0, F.abs(F.col("Qty"))).otherwise(F.lit(0.0)))
    .withColumn("InventoryAddQty", F.when(F.col("Qty") > 0, F.col("Qty")).otherwise(F.lit(0.0)))
)

# STEP 6: cost value correction - CostValue is stored negative for sales.
with_cost = (
    with_sale_flags
    .withColumnRenamed("CostValue", "RawCostValue")
    .withColumn(
        "CostValue",
        F.when(F.col("IsSale"), F.abs(F.col("RawCostValue"))).otherwise(F.col("RawCostValue")),
    )
)

# STEP 7: sale value calculation.
with_sale_value = with_cost.withColumn(
    "SaleValue",
    F.when(F.col("IsSale"), F.col("SellPrice1") * F.col("SalesQty")).otherwise(F.lit(0.0)),
)

# STEP 8: margin calculations.
with_margin = (
    with_sale_value
    .withColumn(
        "MarginDollars",
        F.when(F.col("IsSale"), F.col("SaleValue") - F.col("CostValue")).otherwise(F.lit(0.0)),
    )
    .withColumn(
        "MarginPercent",
        F.when(
            F.col("IsSale") & (F.col("SaleValue") > 0),
            F.col("MarginDollars") / F.col("SaleValue"),
        ).otherwise(F.lit(0.0)),
    )
)

# STEP 9: date key for dim_DateTable relationship.
with_date = (
    with_margin
    .withColumn("Date", F.to_date("TransDatetime"))
    .withColumn(
        "DateKey",
        (F.year("Date") * 10000 + F.month("Date") * 100 + F.dayofmonth("Date")).cast("long"),
    )
)

# STEP 10: transaction type intelligence.
with_type_desc = with_date.withColumn(
    "TransactionTypeDescription",
    F.when(F.col("IsSale"), F.lit("Sale (Transfer Out)"))
     .when(F.col("Type") == "T", F.lit("Inventory Addition (Transfer In)"))
     .when(F.col("Type") == "A", F.lit("Adjustment"))
     .when(F.col("Type") == "R", F.lit("Return"))
     .otherwise(F.col("Type")),
).withColumn("IsTransfer", F.col("Type") == "T")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# STEP 11: PartNumberKey - stable hash, NOT a lookup to dim_Branch12_Parts.
# Must match Build_Gold_Branch12Parts.Notebook's formula exactly.
with_key = with_type_desc.withColumn(
    "PartNumberKey",
    F.when(F.col("PartNumber") == "", F.lit(-1))
     .otherwise(F.abs(F.xxhash64(F.col("PartNumber"))))
     .cast("long"),
)

# STEP 12: time intelligence helpers.
with_time = (
    with_key
    .withColumn("Year", F.year("Date").cast("long"))
    .withColumn("Month", F.month("Date").cast("long"))
    .withColumn("MonthName", F.date_format("Date", "MMMM"))
    .withColumn("Quarter", F.quarter("Date").cast("long"))
)

# STEP 13: final column selection, matching the original's logical order.
fact_branch12_transactions = with_time.select(
    "DateKey", "PartNumberKey", "Date", "PartNumber",
    "TransDatetime", "RONumber", "Type", "TransactionTypeDescription",
    "IsSale", "IsTransfer", "TransferBranch",
    "SalesQty", "InventoryAddQty", "SaleValue", "CostValue",
    "MarginDollars", "MarginPercent",
    "RawQty", "RawCostValue", "SellPrice1", "ListPrice",
    "Description", "Franchise",
    "Year", "Month", "MonthName", "Quarter",
    "ModifiedDate",
)

fact_count = fact_branch12_transactions.count()
print(f"Fact_Branch12_Transactions rows: {fact_count:,}")

fact_branch12_transactions.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/Fact_Branch12_Transactions")
print("Gold build complete: Fact_Branch12_Transactions written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql(
    "SELECT * FROM delta.`Tables/Fact_Branch12_Transactions` LIMIT 10"
).toPandas()
print("Sample rows:")
print(sample.to_string())

sales_check = spark.sql("""
    SELECT
        SUM(CASE WHEN IsSale THEN SaleValue ELSE 0 END) AS TotalSaleValue,
        SUM(CASE WHEN IsSale THEN MarginDollars ELSE 0 END) AS TotalMargin,
        MIN(CASE WHEN IsSale THEN SalesQty END) AS MinSalesQty,
        MIN(CASE WHEN IsSale THEN CostValue END) AS MinCostValue
    FROM delta.`Tables/Fact_Branch12_Transactions`
""").toPandas()
print("\\nSales sanity check (MinSalesQty/MinCostValue should be >= 0):")
print(sales_check.to_string())

key_check = spark.sql("""
    SELECT PartNumber, COUNT(DISTINCT PartNumberKey) AS distinct_keys
    FROM delta.`Tables/Fact_Branch12_Transactions`
    GROUP BY PartNumber
    HAVING COUNT(DISTINCT PartNumberKey) > 1
""").toPandas()
print(f"\\nPartNumbers with inconsistent PartNumberKey (expect 0): {len(key_check)}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 3: Write the `.platform` file**

Generate a new GUID for `logicalId` (any v4 UUID; record the real value used in the execution note below).

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",
  "metadata": {
    "type": "Notebook",
    "displayName": "Build_Gold_Branch12Transactions"
  },
  "config": {
    "version": "2.0",
    "logicalId": "<generated-guid>"
  }
}
```

- [ ] **Step 4: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Transactions.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Transactions.Notebook" --format .py -f
```
Expected: `'Build_Gold_Branch12Transactions.Notebook' imported`. **If this instead fails with a generic `[InvalidInput]` error on an update** (not expected here since this is a fresh create, but possible if re-running after a partial failure), use the raw API workaround documented in `feedback_fab_import_update_broken_use_raw_api` memory: base64-encode both files into an `updateDefinition` payload and `fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/items/<itemId>/updateDefinition" -i <payload.json>`.

- [ ] **Step 5: Get the real notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Transactions.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Transactions.Notebook" --timeout 300
```
Expected: job instance status `Completed`, no `failureReason`. Record the real notebookId from the `fab get` output.

- [ ] **Step 6: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```
Expected: HTTP 200, `Fact_Branch12_Transactions` listed with `status: "Success"`.

- [ ] **Step 7: Register in `deploy/dp_backend_scope.json`**

Read the file first to match its exact existing single-line-per-entry style, then insert a new entry for `Build_Gold_Branch12Transactions` (tier=gold, cadence=daily) using the real notebookId from Step 5, via a precise Edit-tool text insertion — never a full `json.dump()` rewrite (confirmed multiple times this project that reformats the whole file into a large unwanted diff). Validate JSON afterward: `python -c "import json; json.load(open('deploy/dp_backend_scope.json'))"`.

- [ ] **Step 8: DuckDB verification against real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

lh_tables = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_tables = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, path in [("OLD", f"{lh_tables}/Fact_Branch12_Transactions"), ("NEW", f"{dp_tables}/Fact_Branch12_Transactions")]:
    r = con.execute(f"""
        SELECT COUNT(*) AS rows,
               SUM(CASE WHEN IsSale THEN SaleValue ELSE 0 END) AS total_sale_value,
               SUM(CASE WHEN IsSale THEN MarginDollars ELSE 0 END) AS total_margin,
               MAX(TransDatetime) AS max_trans_date
        FROM delta_scan('{path}')
    """).fetchone()
    print(f"{label}: rows={r[0]:,}, total_sale_value={r[1]:,.2f}, total_margin={r[2]:,.2f}, max_date={r[3]}")
```
Expected: row counts and `total_sale_value`/`total_margin` within a few percent (production's own 3-year rolling window means exact match isn't expected — both windows are computed at slightly different run times — but the magnitude should be very close). Report the real numbers found, don't assume a match without running this.

- [ ] **Step 9: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Transactions.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_Branch12Transactions.Notebook

Self-contained Gold build for Fact_Branch12_Transactions - computes
PartNumberKey via a stable hash instead of joining dim_Branch12_Parts,
resolving the circular dependency between the two tables.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 2: `Build_Gold_Branch12Parts.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Parts.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Parts.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

**Depends on Task 1** — reads `Fact_Branch12_Transactions`, which must already exist. `Silver_PartInformation` already confirmed present with all required columns (`PartNumber, Description, Franchise, Source, SLC, DealerGroupCode, CommodityCode, VendorCode, QuantityOnHand, BinQty, BulkBinQty, PendingQty, BackOrderQty, Bin, BulkBin, Returnable, Cost, SellPrice1, ListPrice, InventoryCost, Branch`).

- [ ] **Step 1: Write the notebook**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Parts.Notebook/notebook-content.py`:

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

# Build_Gold_Branch12Parts
# Purpose: Reproduce production's dim_Branch12_Parts
# (df_Dim_Branch12_Parts.Dataflow in LH_Master_Data), part of the
# Combine Vault Sales migration (2026-09-23).
#
# SOURCE: Silver_PartInformation (Branch 12 only) + Fact_Branch12_Transactions
# (must already be built - see Build_Gold_Branch12Transactions.Notebook).
#
# REAL DEPARTURE FROM PRODUCTION: PartNumberKey was originally a plain
# sequential index (Table.AddIndexColumn over alphabetically-sorted parts),
# regenerated from scratch every refresh - the same shift-risk pattern
# already fixed once on dim_Parts (the CustomerKey incident). Replaced here
# with the exact same stable PartNumber hash used in
# Build_Gold_Branch12Transactions.Notebook, so keys align between the fact
# and this dimension without either needing the other's specific prior
# state. Brian approved this fix 2026-09-23 (not a faithful port on this
# one point, deliberately).

print("=" * 80)
print("BUILD_GOLD_BRANCH12PARTS")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from datetime import datetime, timedelta
from pyspark.sql import functions as F
import pytz

# STEP 1: load Branch 12 parts master.
source = spark.read.table("Silver_PartInformation")
branch12_parts = source.filter(F.col("Branch") == "12")
print(f"Branch 12 parts: {branch12_parts.count():,}")

# STEP 2: select essential columns.
selected = branch12_parts.select(
    "PartNumber", "Description", "Franchise", "Source", "SLC",
    "DealerGroupCode", "CommodityCode", "VendorCode",
    "QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty",
    "Bin", "BulkBin", "Returnable", "Cost", "SellPrice1", "ListPrice",
    "InventoryCost",
)

# STEP 3: clean text fields.
cleaned = (
    selected
    .withColumn("PartNumber", F.upper(F.trim(F.coalesce(F.col("PartNumber"), F.lit("")))))
    .withColumn("Description", F.initcap(F.trim(F.coalesce(F.col("Description"), F.lit("")))))
    .withColumn("Franchise", F.upper(F.trim(F.coalesce(F.col("Franchise"), F.lit("")))))
    .withColumn("Source", F.upper(F.trim(F.coalesce(F.col("Source"), F.lit("")))))
    .withColumn("SLC", F.upper(F.trim(F.coalesce(F.col("SLC"), F.lit("")))))
    .withColumn("DealerGroupCode", F.upper(F.trim(F.coalesce(F.col("DealerGroupCode"), F.lit("")))))
    .withColumn("CommodityCode", F.upper(F.trim(F.coalesce(F.col("CommodityCode"), F.lit("")))))
    .withColumn("VendorCode", F.upper(F.trim(F.coalesce(F.col("VendorCode"), F.lit("")))))
    .withColumn("Bin", F.upper(F.trim(F.coalesce(F.col("Bin"), F.lit("")))))
    .withColumn("BulkBin", F.upper(F.trim(F.coalesce(F.col("BulkBin"), F.lit("")))))
    .withColumn("Returnable", F.upper(F.trim(F.coalesce(F.col("Returnable"), F.lit("N")))))
    .withColumn("QuantityOnHand", F.col("QuantityOnHand").cast("double"))
    .withColumn("BinQty", F.col("BinQty").cast("double"))
    .withColumn("BulkBinQty", F.col("BulkBinQty").cast("double"))
    .withColumn("PendingQty", F.col("PendingQty").cast("double"))
    .withColumn("BackOrderQty", F.col("BackOrderQty").cast("double"))
    .withColumn("Cost", F.col("Cost").cast("double"))
    .withColumn("SellPrice1", F.col("SellPrice1").cast("double"))
    .withColumn("ListPrice", F.col("ListPrice").cast("double"))
    .withColumn("InventoryCost", F.col("InventoryCost").cast("double"))
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# STEP 4: R12 metrics from the fact table - DST-safe "now", same pattern
# as Build_Gold_Branch12Transactions.Notebook and Build_Gold_FirstPassFill.
central = pytz.timezone("America/Chicago")
today_central = datetime.now(pytz.utc).astimezone(central).date()
days365_ago = today_central - timedelta(days=365)

fact = spark.read.table("Fact_Branch12_Transactions")
fact_last365 = fact.filter(
    (F.col("Date") >= F.lit(days365_ago))
    & (F.col("Date") <= F.lit(today_central))
    & (F.col("IsSale") == True)  # noqa: E712
)

# R12_Sales_Qty uses SalesQty (already the positive absolute-value "quantity
# sold" figure) rather than the original's raw Qty - the new fact schema
# doesn't carry a plain Qty column, and SalesQty is already filtered to
# IsSale=True here, so it's the same real-world quantity the original
# metric intended (the original's List.Sum of negative Qty would need an
# ABS anyway to be a meaningful "R12 sales quantity" display figure).
r12_metrics = fact_last365.groupBy("PartNumber").agg(
    F.count(F.lit(1)).cast("long").alias("Demands"),
    F.sum("SalesQty").alias("R12_Sales_Qty"),
    F.sum("SaleValue").alias("R12_Sales_Dollars"),
)

# STEP 5: merge R12 metrics onto parts dimension.
merged = cleaned.join(r12_metrics, "PartNumber", "left")
with_metrics = (
    merged
    .withColumn("Demands", F.coalesce(F.col("Demands"), F.lit(0)).cast("long"))
    .withColumn("R12_Sales_Qty", F.coalesce(F.col("R12_Sales_Qty"), F.lit(0.0)))
    .withColumn("R12_Sales_Dollars", F.coalesce(F.col("R12_Sales_Dollars"), F.lit(0.0)))
)

# STEP 6: convenience flags.
with_flags = (
    with_metrics
    .withColumn("IsAvailable", F.coalesce(F.col("QuantityOnHand"), F.lit(0.0)) > 0)
    .withColumn("HasRecentSales", F.col("Demands") > 0)
    .withColumn("IsReturnable", F.col("Returnable") == "Y")
)

# STEP 7: unit-level margin.
with_margin = (
    with_flags
    .withColumn(
        "Unit Margin Dollars",
        F.coalesce(F.col("SellPrice1"), F.lit(0.0)) - F.coalesce(F.col("Cost"), F.lit(0.0)),
    )
    .withColumn(
        "Unit Margin Percent",
        F.when(
            F.coalesce(F.col("SellPrice1"), F.lit(0.0)) > 0,
            F.col("Unit Margin Dollars") / F.col("SellPrice1"),
        ).otherwise(F.lit(0.0)),
    )
)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# STEP 8: deduplicate (arbitrary, matching the original's Table.Distinct -
# Branch 12 parts shouldn't have real Branch+PartNumber duplicates since
# Branch is already fixed to '12', but preserved for safety) and drop
# blank PartNumber rows.
deduped = with_margin.dropDuplicates(["PartNumber"])
non_blank = deduped.filter(F.col("PartNumber") != "")

# STEP 9: PartNumberKey - the exact same hash formula as
# Build_Gold_Branch12Transactions.Notebook. Must match byte-for-byte.
with_key = non_blank.withColumn(
    "PartNumberKey",
    F.when(F.col("PartNumber") == "", F.lit(-1))
     .otherwise(F.abs(F.xxhash64(F.col("PartNumber"))))
     .cast("long"),
)

# STEP 10: Unknown placeholder row for orphaned fact transactions.
unknown_row = spark.createDataFrame(
    [(-1, "UNKNOWN", "Unknown Part", "UNKNOWN", 0.0, 0.0, 0.0, 0.0, 0.0, "", "",
      False, 0, 0.0, 0.0, False, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
      "UNKNOWN", "UNKNOWN", "UNKNOWN", "UNKNOWN", "N", False)],
    schema=[
        "PartNumberKey", "PartNumber", "Description", "Franchise",
        "QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty",
        "Bin", "BulkBin", "IsAvailable", "Demands", "R12_Sales_Qty",
        "R12_Sales_Dollars", "HasRecentSales", "Cost", "SellPrice1",
        "ListPrice", "InventoryCost", "Unit Margin Dollars", "Unit Margin Percent",
        "Source", "SLC", "DealerGroupCode", "VendorCode", "Returnable", "IsReturnable",
    ],
)

final_columns = [
    "PartNumberKey", "PartNumber", "Description", "Franchise",
    "QuantityOnHand", "BinQty", "BulkBinQty", "PendingQty", "BackOrderQty",
    "Bin", "BulkBin", "IsAvailable", "Demands", "R12_Sales_Qty",
    "R12_Sales_Dollars", "HasRecentSales", "Cost", "SellPrice1",
    "ListPrice", "InventoryCost", "Unit Margin Dollars", "Unit Margin Percent",
    "Source", "SLC", "DealerGroupCode", "VendorCode", "Returnable", "IsReturnable",
]

dim_branch12_parts = with_key.select(*final_columns).unionByName(
    unknown_row.select(*final_columns)
)

part_count = dim_branch12_parts.count()
print(f"dim_Branch12_Parts rows: {part_count:,}")

dim_branch12_parts.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/dim_Branch12_Parts")
print("Gold build complete: dim_Branch12_Parts written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/dim_Branch12_Parts` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

dup_check = spark.sql("""
    SELECT PartNumberKey, COUNT(*) AS n
    FROM delta.`Tables/dim_Branch12_Parts`
    GROUP BY PartNumberKey
    HAVING COUNT(*) > 1
""").toPandas()
print(f"\\nDuplicate PartNumberKey rows (expect 0): {len(dup_check)}")

key_alignment = spark.sql("""
    SELECT COUNT(*) AS unmatched_fact_rows
    FROM delta.`Tables/Fact_Branch12_Transactions` f
    LEFT ANTI JOIN delta.`Tables/dim_Branch12_Parts` d
        ON f.PartNumberKey = d.PartNumberKey
""").toPandas()
print(f"\\nFact rows with no matching PartNumberKey in dim (expect 0, proves hash alignment): {key_alignment.iloc[0]['unmatched_fact_rows']}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

Same pattern as Task 1 Step 3, `displayName: "Build_Gold_Branch12Parts"`, a new generated GUID.

- [ ] **Step 3: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Parts.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Parts.Notebook" --format .py -f
```
Expected: `'Build_Gold_Branch12Parts.Notebook' imported`.

- [ ] **Step 4: Get the real notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Parts.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_Branch12Parts.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`. **The "key alignment" check in the notebook's own output cell (Step 1's last cell) must show 0 unmatched fact rows** — if it doesn't, the hash formula in this notebook doesn't match Task 1's exactly; stop and diff the two `PartNumberKeyExpr` blocks before proceeding.

- [ ] **Step 5: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `deploy/dp_backend_scope.json`**

Same precise-Edit-insertion pattern as Task 1 Step 7, entry for `Build_Gold_Branch12Parts` (tier=gold, cadence=daily), using the real notebookId from Step 4.

- [ ] **Step 7: DuckDB verification against real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

lh_tables = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_tables = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, path in [("OLD", f"{lh_tables}/dim_Branch12_Parts"), ("NEW", f"{dp_tables}/dim_Branch12_Parts")]:
    r = con.execute(f"""
        SELECT COUNT(*) AS rows, SUM(InventoryCost) AS total_inventory_cost,
               SUM(Demands) AS total_demands, SUM(R12_Sales_Dollars) AS total_r12_dollars
        FROM delta_scan('{path}')
    """).fetchone()
    print(f"{label}: rows={r[0]:,}, total_inventory_cost={r[1]:,.2f}, total_demands={r[2]:,}, total_r12_dollars={r[3]:,.2f}")
```
Expected: row counts close (both scoped to Branch 12 parts, should match closely since the parts master doesn't change much); `total_r12_dollars` may differ somewhat from production's own stale rolling window, same caveat as Task 1 Step 8 — report the real numbers.

- [ ] **Step 8: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_Branch12Parts.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_Branch12Parts.Notebook

Uses the same PartNumber hash as Build_Gold_Branch12Transactions,
replacing the original's fragile sequential-index PartNumberKey and
completing the circular-dependency fix.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-23):** Completed by implementer subagent, DONE_WITH_CONCERNS — 2 real bugs found in this plan's own notebook code (not just deviations), both confirmed correct and necessary:
1. **`VendorCode` type mismatch**: `Silver_PartInformation.VendorCode` is real-schema `INTEGER`, not string — the plan's code called `F.upper(F.trim(...))` on it directly, which fails. Fixed with `.cast("string")` before trim/upper.
2. **Space-containing Delta column names**: `"Unit Margin Dollars"`/`"Unit Margin Percent"` (with spaces) violate this project's own documented Delta naming rule ("Delta tables reject column names with spaces") — this plan's own PySpark code missed applying that rule when porting the original Power Query column names literally. Renamed to `UnitMarginDollars`/`UnitMarginPercent` in the actual deployed table, matching the convention every other Gold notebook in this repo already uses.

**Real impact on Task 5**: the report's `dim_Branch12_Parts.tmdl` currently has `column 'Unit Margin Dollars'` with `sourceColumn: Unit Margin Dollars` (and the same pattern for `'Unit Margin Percent'`) — confirmed via direct read. The column **display name** can stay as-is (report-facing, unaffected), but **`sourceColumn:` must be updated** to the real deployed names `UnitMarginDollars`/`UnitMarginPercent` during Task 5's repoint, or the report will fail to refresh with a "column not found" error. Task 5's implementer must apply this rename in addition to the plain connection-string swap.

Verified results: notebookId `00fa8f68-4523-47f1-ae1b-efa8dd3ff34d`, commit `b68ebae7`. Row count 1,490 (exact match vs. production). `total_inventory_cost` exact match ($278,217.82). Key-alignment check (fact→dim anti-join): **0 unmatched rows**, confirmed independently via DuckDB — proves the `PartNumberKey` hash formula matches Task 1's exactly, unaffected by the 2 fixes above.

---

### Task 3: `Build_Gold_BranchPartInventory.Notebook`

**Files:**
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_BranchPartInventory.Notebook/notebook-content.py`
- Create: `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_BranchPartInventory.Notebook/.platform`
- Modify: `fabric-workspace-docs/deploy/dp_backend_scope.json`

**Depends on Task 1** — reads `Fact_Branch12_Transactions` for the compound-key scope. Independent of Task 2 (does not touch `dim_Branch12_Parts` at all).

**No new business logic here — this is a faithful, unmodified port.** The compound-key join and the deliberate absence of an `IsSale` filter must be preserved exactly (2 real production attempts to tighten this scope were both reverted for corrupting the report's Grand Total — see the design spec's Problem Statement).

- [ ] **Step 1: Write the notebook**

Create `workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_BranchPartInventory.Notebook/notebook-content.py`:

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

# Build_Gold_BranchPartInventory
# Purpose: Reproduce production's dim_BranchPartInventory
# (df_Dim_BranchPartInventory.Dataflow in LH_Master_Data), part of the
# Combine Vault Sales migration (2026-09-23).
#
# SOURCE: Silver_PartInformation (excl. Branch 12) + Fact_Branch12_Transactions
# (must already be built - see Build_Gold_Branch12Transactions.Notebook).
#
# GRAIN: One row per (Branch, PartNumber) pair the vault has actually
# transferred to that specific branch - NOT every branch that happens to
# independently stock a given vault part.
#
# DELIBERATELY NO IsSale FILTER: production tried and reverted an
# IsSale=True condition on this join twice (2026-07-07) - it corrupted the
# report's Grand Total for unrelated measures in ways not fully understood.
# Faithful, unmodified port - do not add filtering here. See
# df_Dim_BranchPartInventory.Dataflow's own header comment and
# projects/combine vault sales - reports/CLAUDE.md for the full history.

print("=" * 80)
print("BUILD_GOLD_BRANCHPARTINVENTORY")
print("=" * 80)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

# STEP 1: (TransferBranch, PartNumber) pairs the vault has actually
# transferred to.
fact = spark.read.table("Fact_Branch12_Transactions")
vault_transfer_pairs = (
    fact.filter(F.col("TransferBranch").isNotNull())
    .select("TransferBranch", "PartNumber")
    .distinct()
)

# STEP 2: parts master for all branches except Branch 12.
parts = spark.read.table("Silver_PartInformation")
not_vault = parts.filter(F.col("Branch") != "12")

# STEP 3: inner join on the compound key - scoped to real transfer history
# only. Do not loosen to PartNumber alone (see header comment above).
scoped = not_vault.join(
    vault_transfer_pairs,
    (not_vault["Branch"] == vault_transfer_pairs["TransferBranch"])
    & (not_vault["PartNumber"] == vault_transfer_pairs["PartNumber"]),
    "inner",
).select(
    not_vault["Branch"],
    not_vault["PartNumber"],
    not_vault["QuantityOnHand"],
    not_vault["BinQty"],
)

# STEP 4: final types and sort.
dim_branch_part_inventory = (
    scoped
    .withColumn("Branch", F.col("Branch").cast("string"))
    .withColumn("PartNumber", F.col("PartNumber").cast("string"))
    .withColumn("QuantityOnHand", F.col("QuantityOnHand").cast("double"))
    .withColumn("BinQty", F.col("BinQty").cast("double"))
    .orderBy("PartNumber", "Branch")
)

row_count = dim_branch_part_inventory.count()
print(f"dim_BranchPartInventory rows: {row_count:,}")

dim_branch_part_inventory.write.format("delta").mode("overwrite").option(
    "overwriteSchema", "true"
).save("Tables/dim_BranchPartInventory")
print("Gold build complete: dim_BranchPartInventory written.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

sample = spark.sql("SELECT * FROM delta.`Tables/dim_BranchPartInventory` LIMIT 10").toPandas()
print("Sample rows:")
print(sample.to_string())

compound_key_check = spark.sql("""
    SELECT Branch, PartNumber, COUNT(*) AS n
    FROM delta.`Tables/dim_BranchPartInventory`
    GROUP BY Branch, PartNumber
    HAVING COUNT(*) > 1
""").toPandas()
print(f"\\nDuplicate (Branch, PartNumber) rows (expect 0): {len(compound_key_check)}")

vault_excluded_check = spark.sql("""
    SELECT COUNT(*) AS branch12_rows
    FROM delta.`Tables/dim_BranchPartInventory`
    WHERE Branch = '12'
""").toPandas()
print(f"Branch 12 rows present (expect 0, Branch 12 excluded by design): {vault_excluded_check.iloc[0]['branch12_rows']}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
```

- [ ] **Step 2: Write the `.platform` file**

Same pattern, `displayName: "Build_Gold_BranchPartInventory"`, a new generated GUID.

- [ ] **Step 3: Import to Fabric**

```bash
export PATH="$HOME/.local/bin:$PATH"
export PYTHONIOENCODING=utf-8
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
fab import "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_BranchPartInventory.Notebook" \
  -i "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_BranchPartInventory.Notebook" --format .py -f
```

- [ ] **Step 4: Get the real notebookId and run it**

```bash
fab get "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_BranchPartInventory.Notebook" -q "id"
fab job run "DP - Presentation - Dev.Workspace/Fact Tables.Folder/Combine Vault Sales.Folder/Build_Gold_BranchPartInventory.Notebook" --timeout 300
```
Expected: `Completed`, no `failureReason`.

- [ ] **Step 5: Refresh SQL analytics endpoint metadata**

```bash
fab api -X post "workspaces/73fd5443-240e-410a-990a-98827f32c087/sqlEndpoints/18effb0e-7bc2-47a1-854c-f4f2e8129145/refreshMetadata"
```

- [ ] **Step 6: Register in `deploy/dp_backend_scope.json`**

Same pattern, entry for `Build_Gold_BranchPartInventory` (tier=gold, cadence=daily), using the real notebookId from Step 4.

- [ ] **Step 7: DuckDB verification against real production**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")

lh_tables = "abfss://b48cdb35-7ce3-46de-96df-d70db77649cb@onelake.dfs.fabric.microsoft.com/3e74497b-8c51-4a1a-91a1-888c59118f48/Tables"
dp_tables = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

for label, path in [("OLD", f"{lh_tables}/dim_BranchPartInventory"), ("NEW", f"{dp_tables}/dim_BranchPartInventory")]:
    r = con.execute(f"SELECT COUNT(*) AS rows, COUNT(DISTINCT Branch) AS distinct_branches FROM delta_scan('{path}')").fetchone()
    print(f"{label}: rows={r[0]:,}, distinct_branches={r[1]}")
```
Expected: row counts close (both scoped identically by real transfer history off the same fact table logic — should track closely, not necessarily exact given the 1-day-behind eventual-consistency the fact table has vs. production's own separate refresh cadence).

- [ ] **Step 8: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/DP - Presentation - Dev/Fact Tables/Combine Vault Sales/Build_Gold_BranchPartInventory.Notebook/" deploy/dp_backend_scope.json
git commit -m "Add Build_Gold_BranchPartInventory.Notebook

Faithful port of the compound-key (TransferBranch, PartNumber) scoped
join - no logic changes, including the deliberate absence of an
IsSale filter (reverted twice in production for corrupting the
report's Grand Total).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 4: Report-layer exhaustive real-usage audit

**Files:** none — investigation only. Findings get documented directly in this plan before Task 5 proceeds (same discipline as every prior report this project).

- [x] **Step 1: Audit all 6 real data tables**

For `Fact_Branch12_Transactions`, `dim_Branch12_Parts`, `dim_BranchLocation`, `dim_BranchPartInventory`, `dim_DateTable`, `dim_Parts`: run `pbir fields list "Combine Vault Sales.Report"`, grep every `.tmdl` measure/column DAX body in `MeasuresTable.tmdl` for each table's columns, and check every `.bookmark.json` file under `workspaces/RP - Dev/Combine Vault Sales.Report/definition/bookmarks/` for filter references (bookmark-only usage is a confirmed real blind spot from a prior report this project — Pin Capture's `IsRolling12Months`).

- [x] **Step 2: Explicit `dim_DateTable` cross-check**

Cross-reference every DAX-confirmed-used `dim_DateTable` column against the real 14-column `DP_Presentation.dim_DateTable` schema (`DateKey, Date, Year, Quarter, Month, Day, WeekOfYear, DayOfWeek, MonthName, MonthNameShort, MonthYear, SortableMonthYear, QuarterYear, IsWeekend`). `IsRolling365Days` is already confirmed used by the `Sales R12` measure (per the report's own `CLAUDE.md`) and is **not** in that list — this one is already known, but check for any other genuinely-used "today-relative" column the DAX grep surfaces.

- [x] **Step 3: Document findings**

Add a "### Task 4 Findings" section to this plan file recording, for each of the 6 tables: confirmed-used columns (keep), confident-unused columns (trim), and ambiguous columns (leave as-is, note why). Check every table for `sortByColumn` properties before trimming (a sort-by column can be silently referenced without appearing in any measure). Explicitly record the `IsRolling365Days` restoration decision (expected: restore as a DAX calculated column).

---

### Task 4 Findings

**Execution note (2026-09-23):** Audit completed by implementer subagent via `pbir fields list`, DAX-body grep against `MeasuresTable.tmdl` (this report's measures table, not `_Measures`), grep against all 10 `.bookmark.json` files, `relationships.tmdl` cross-reference, and `sortByColumn` inspection.

**Two real findings beyond what the plan anticipated:**
1. **`IsRolling730Days` is a second genuinely-used today-relative `dim_DateTable` column**, not previously documented anywhere (not in the report's own `CLAUDE.md`). Used alongside `IsRolling365Days` in 3 measures (`Sales Previous R12`, `Demands Previous R12`, `Qty Previous R12`) to compute a "previous 12 months" comparison window (days 366–730 back). Both columns need restoring in Task 5, not just `IsRolling365Days`.
2. **`dim_DateTable[MonthYear]` is a real bookmark-only usage** — confirmed via `"Entity": "dim_DateTable"` / `"Property": "MonthYear"` in 2 bookmark files, zero hits in DAX or `pbir fields list`. This is exactly the blind-spot class the bookmark-check step exists to catch (same pattern as Pin Capture's `IsRolling12Months`). Must be kept.

**Resolved from Task 2's open question:** `dim_Branch12_Parts['Unit Margin Dollars']`/`['Unit Margin Percent']` are confirmed **genuinely unused** — zero hits anywhere in the report (DAX, `pbir fields list`, bookmarks). Task 5 should **trim these two columns entirely**, not rename-and-keep.

**Per-table findings:**

#### Fact_Branch12_Transactions
- **Keep:** DateKey, PartNumberKey, Date, PartNumber, TransDatetime, IsSale, SalesQty, SaleValue, CostValue, MarginDollars, SellPrice1, Qty, TransferBranch
- **Trim:** RONumber, Type, TransactionTypeDescription, IsTransfer, InventoryAddQty, MarginPercent, RawQty, RawCostValue, ListPrice, Description, Franchise, Year, Month, MonthName, Quarter, ModifiedDate
- **sortByColumn:** none

#### dim_Branch12_Parts
- **Keep:** PartNumberKey, PartNumber, Description, QuantityOnHand, BinQty, BulkBinQty, PendingQty, IsAvailable, Cost, InventoryCost
- **Trim:** Franchise, Source, SLC, DealerGroupCode, CommodityCode, VendorCode, BackOrderQty, Bin, BulkBin, SellPrice1, ListPrice, Demands (report's own `Demands` measure recomputes live from the fact table via `COUNTROWS`+`TODAY()-365`, does NOT read this pre-computed column), HasRecentSales, Returnable, IsReturnable, R12_Sales_Qty, R12_Sales_Dollars, `'Unit Margin Dollars'`, `'Unit Margin Percent'`
- **sortByColumn:** none

#### dim_BranchLocation
- **Keep:** Branch, BranchID, BranchName
- **Trim:** BranchKey, BranchType, LocationID, State, City, ServiceCapacity, MarketPresence, TerritoryCoverage, OperationalPriority, RegionalClassification, ServiceHours, DistanceFromHub, DataQualityScore
- **sortByColumn:** none

#### dim_BranchPartInventory
- **Keep:** Branch, PartNumber, QuantityOnHand, BinQty (all 4 — this table has only 4 columns and all are used in the `(By Location)` measures)
- **Trim:** none
- **sortByColumn:** none

#### dim_DateTable
- **Keep:** DateKey, Date, Year, Month, MonthYearDate, MonthYear (bookmark-only — see finding above), SortableMonthYear (sortByColumn target of MonthYear), Month (also sortByColumn target of MonthNameShort), **IsRolling365Days**, **IsRolling730Days** (both need restoring as DAX calculated columns — see finding above)
- **Trim:** Quarter, Day, WeekOfYear, DayOfWeek, DayOfWeekName, DayOfWeekNameShort, QuarterYear, DateDisplayName, IsWeekend, IsWeekday, IsCurrentYear, IsCurrentMonth, DaysFromToday, Season, IsPeakSeason, FiscalYear, FiscalQuarter, MonthSort, QuarterSort, YearOffset, IsBusinessDay, WorkingDaysInMonth, WorkingDaysInQuarter, WorkingDaysInYear, IsPreviousYear, IsPreviousMonth, IsPreviousQuarter, IsYearToDate, IsQuarterToDate, IsMonthToDate, IsRolling6Months, IsRolling12Months, IsRolling24Months, IsRolling36Months, IsRolling48Months, IsRolling4Quarters, IsRolling8Quarters, IsRolling52Weeks, IsRolling1095Days, IsRolling1460Days, IsRolling180Days, IsRolling545Days, IsRolling45Days, IsRolling120Days, IsRolling270Days, IsRolling450Days, IsRolling13Weeks, IsRolling26Weeks, IsRolling104Weeks, IsRolling156Weeks, IsLast30Days, IsLast60Days, IsLast90Days, IsNext30Days, IsSameMonthLastYear, IsSameQuarterLastYear, RollingPeriodCategory
- **Ambiguous:** MonthNameShort — has its own `sortByColumn: Month` configured but zero direct DAX/visual/bookmark reference found; left as-is (keep) per the "unsure → keep" rule.
- **sortByColumn:** yes — `MonthNameShort → Month`, `MonthYear → SortableMonthYear`. Note: `Quarter`, `Day`, `WeekOfYear`, `DayOfWeek` are all present in the real 14-column `DP_Presentation.dim_DateTable` schema regardless of this report's own usage, so trimming them here is cosmetic only — no restoration risk.

#### dim_Parts
- **Keep:** PartNumberKey only — required for the bidirectional relationship to `dim_Branch12_Parts.PartNumberKey` and the inactive relationship from `Fact_Branch12_Transactions`.
- **Trim:** PartNumber, Description, Franchise, Source, SLC, DealerGroupCode, CommodityCode, VendorCode, QuantityOnHand, BackOrderQty, StockStatus, IsAvailable, InventoryCost, SellPrice1, ListPrice, Current12MoSales, HasRecentSales, ActivityStatus, Returnable, IsReturnable, IsHighValue (all 21 non-key columns — zero hits across every check)
- **sortByColumn:** none
- **Note:** this shared dimension is used in this report only for its relationship key — a more aggressive trim than the other 5 tables, but fully verified, not a gap.

---

### Task 5: Report-layer repoint and trim

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/Fact_Branch12_Transactions.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/dim_Branch12_Parts.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/dim_BranchPartInventory.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/dim_DateTable.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/dim_Parts.tmdl`

**Depends on Task 4's findings.**

- [ ] **Step 1: Swap connection strings on all 6 tables**

Replace every occurrence of the old connection string with the new one in each `partition <table> = m` block:
```
Old: Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")
New: Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")
```

- [ ] **Step 2: Restore `IsRolling365Days` on `dim_DateTable` if confirmed used**

Read the real current file first, then add a DAX calculated column (day-based window, not month-based like `IsRolling12Months`'s `EOMONTH` pattern):
```
column IsRolling365Days = ```

		VAR RefDate = MAX('Data Refresh'[Date])
		VAR StartOfRollingPeriod = RefDate - 365
		RETURN
		dim_DateTable[Date] >= StartOfRollingPeriod && dim_DateTable[Date] <= RefDate
		```
```

- [ ] **Step 3: Apply trims per Task 4 Findings**

Apply the confirmed-unused column removals to each of the 5 non-`dim_DateTable` tables (`Fact_Branch12_Transactions`, `dim_Branch12_Parts`, `dim_BranchLocation`, `dim_BranchPartInventory`, `dim_Parts`) per Task 4's documented findings, verifying column-for-column against those findings after editing.

- [ ] **Step 4: Verify no stray connection strings remain**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/"
```
Expected: zero matches.

- [ ] **Step 5: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Combine Vault Sales.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Combine Vault Sales to DP_Presentation

All 6 data tables repointed. Any genuinely-used dim_DateTable
today-relative columns (starting from the known IsRolling365Days
usage) restored as DAX calculated columns. Trimmed per the Task 4
exhaustive audit where confident, left as-is where ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

---

### Task 6: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Combine Vault Sales.pbip`

- [x] **Step 1: Confirm it doesn't already exist**

```bash
ls "workspaces/RP - Dev/" | grep "Combine Vault"
```
Expected: only `Combine Vault Sales.Report` and `Combine Vault Sales.SemanticModel` — no `.pbip`.

- [x] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Combine Vault Sales.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [x] **Step 3: Commit and push**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Combine Vault Sales.pbip"
git commit -m "Add Combine Vault Sales.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin dev
```

**Execution note (2026-09-23):** Committed and pushed clean — commit `4feeeec5` on `fabric-workspace-docs/dev` (`ba960e82..4feeeec5`), content exactly as specified.

---

### Task 7: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [x] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 1-6's commits.

- [x] **Step 2: Open Combine Vault Sales from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors (would mean Task 4's audit missed a real usage, or a `dim_DateTable` today-relative column wasn't caught) or relationship errors on `dim_Branch12_Parts` ↔ `Fact_Branch12_Transactions` (would mean the hash-based `PartNumberKey` doesn't align — check Task 2's own "key alignment" verification output first if this happens). Report back for investigation rather than assuming.

- [x] **Step 3: Visually confirm real output**

Against the real, currently-live production version — specifically the Restock Tool and Greater than Zero pages (the ones most dependent on `dim_BranchPartInventory` and the R12 metrics), to confirm the new Gold tables produce equivalent output.

- [x] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [x] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 8).

**Execution note (2026-09-23):** Brian confirmed: "This looks great, nothing looks of concern for this one that I could see from a quick scan of the pages. Re-published and committed."

---

### Task 8: Post-publish verification and catalog update

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`

- [x] **Step 1: DuckDB row-count check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = [
    "Fact_Branch12_Transactions", "dim_Branch12_Parts", "dim_BranchPartInventory",
    "dim_BranchLocation", "dim_DateTable", "dim_Parts",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

**Execution note (2026-09-23):** All 6 tables present and populated: `Fact_Branch12_Transactions` 5,132 rows, `dim_Branch12_Parts` 1,490, `dim_BranchLocation` 69, `dim_BranchPartInventory` 2,125, `dim_DateTable` 4,018, `dim_Parts` 316,696.

- [x] **Step 2: Update the catalog doc**

Mark Combine Vault Sales complete in `docs/architecture/report-migration-catalog.md`, matching the completion-note pattern already used for First Pass Fill and MD Invoices With No Freight. Note this is the 3rd and last report in this batch, and the real circular-dependency resolution (hash-based `PartNumberKey` replacing the sequential index) as the headline finding — this closes out a blocker that's been on record since the original dims and facts catalog audits.

**Execution note (2026-09-23):** Catalog doc updated with the full completion note, covering the circular-dependency resolution, the 2 real bugs found during the build (VendorCode type, Delta space-column naming), and the 2 real audit findings (IsRolling730Days, MonthYear bookmark usage). This completes the 3-report batch.

---

## Self-Review Notes

**Spec coverage:** The design spec's 4 architecture sections (3.1 fact notebook, 3.2 dim notebook, 3.3 branch-part-inventory notebook, 3.4 report-layer repoint) map to Tasks 1, 2, 3, and 5 respectively. The spec's verification plan maps to Task 1 Step 8, Task 2 Step 7, Task 3 Step 7, and Task 8 Step 1. The spec's explicit non-goals (no change to production dataflows, no "fixing" `dim_BranchPartInventory`'s known limitation) are respected throughout — Task 3's notebook code and comments explicitly preserve the no-`IsSale`-filter behavior.

**Placeholder scan:** Task 4's findings feed Task 5 Steps 2-3 — a real sequential dependency, matching the pattern proven on every prior report this project. Task 1/2/3 Step 8/7/7 (DuckDB verification) explicitly calls for reporting real run-time numbers rather than assuming a match, since production's own rolling windows are computed at different times than the new backend's runs.

**Type consistency:** The `PartNumberKeyExpr` hash formula is stated once at the top of the plan and referenced (not re-derived) in both Task 1 Step 2 and Task 2 Step 1's notebook code — verified identical: `F.when(F.col("PartNumber") == "", F.lit(-1)).otherwise(F.abs(F.xxhash64(F.col("PartNumber")))).cast("long")` in both. Task 1's final column list (`DateKey, PartNumberKey, Date, PartNumber, TransDatetime, RONumber, Type, TransactionTypeDescription, IsSale, IsTransfer, TransferBranch, SalesQty, InventoryAddQty, SaleValue, CostValue, MarginDollars, MarginPercent, RawQty, RawCostValue, SellPrice1, ListPrice, Description, Franchise, Year, Month, MonthName, Quarter, ModifiedDate`) is referenced consistently by Task 2's R12 metrics logic (uses `Date`, `IsSale`, `SalesQty`, `SaleValue`, `PartNumber` — all present) and Task 3's compound-key join (uses `TransferBranch`, `PartNumber` — both present).
