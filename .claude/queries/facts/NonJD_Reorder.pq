/*
============================================================================
Query: NonJD_Reorder (Fact)
Notebook: nb_Fact_NonJD_Reorder
Location: LH_Master_Data → Notebooks
============================================================================

PURPOSE: Pre-calculates daily reorder recommendations for the Non-JD Parts
Order Tool. Joins raw parts data with InMaster, param_ROP_Matrix, and
param_FranchiseScope to produce one row per in-scope Branch+PartNumber
with ROP-based order quantities.

GRAIN: One row per Branch + PartNumber (in-scope franchises only)
       Row count: ~209,291 (as of 2026-05-29)

IMPLEMENTATION: PySpark Notebook (NOT a Dataflow Gen2)
  Row-by-row ROP matrix lookup (1,993 rows × ~200K parts) is O(400M)
  comparisons in Power Query M. In Spark it becomes a broadcast join — fast.

DEPENDENCIES:
  - NonJD_Parts_Ordering_Raw (Phase 1 — must refresh first)
  - InMaster_Raw             (Phase 1 — must refresh first)
  - param_ROP_Matrix         (Phase 3 — on-demand only)
  - param_FranchiseScope     (Phase 3 — on-demand only)

PIPELINE: Phase 4 (Facts) — Notebook activity, not Dataflow activity

NOTE: config_PartSettings (per-part user overrides) intentionally omitted
  from Phase 1. MinimumQty from source serves as EffectiveMin until
  SharePoint list is wired up in Phase 2.

ROP FORMULA:
  MonthCount        = months (of 60) where sales OR requests > 0; capped 0→1, >19→19
  AvgMonthlyDemand  = TotalRequests / MonthCount
  AvgMonthlySales   = TotalSales / MonthCount
  CalcROP           = AvgMonthlyDemand × Modifier (from matrix)
  StockingTarget    = MAX(WarehouseMin, MinimumQty, CEILING(CalcROP))
  RecommendedOrderQty = MAX(0, StockingTarget - QuantityOnHand - OnOrder)
  EstOrderValue     = RecommendedOrderQty × Cost
============================================================================

PySpark code (paste into a single notebook cell):

from pyspark.sql import functions as F

parts      = spark.read.table("NonJD_Parts_Ordering_Raw")
inmaster   = spark.read.table("InMaster_Raw")
rop_matrix = spark.read.table("param_ROP_Matrix")
fr_scope   = spark.read.table("param_FranchiseScope")

in_scope       = fr_scope.filter(F.col("IsIncluded") == True).select("Franchise")
parts_filtered = parts.join(in_scope, "Franchise", "inner").filter(F.col("Cost") > 0)

inmaster_cols = inmaster.select(
    "Branch", "PartNumber",
    "ProdGroup", "StockingMonths", "MarginFlag", "SalesClass", "Category"
)
with_inmaster = parts_filtered.join(inmaster_cols, ["Branch", "PartNumber"], "left")

sales_cols = [f"SalesMonth{i:02d}" for i in range(1, 61)]
req_cols   = [f"RequestsMonth{i:02d}" for i in range(1, 61)]

active_expr = " + ".join([f"CASE WHEN `{s}` > 0 OR `{r}` > 0 THEN 1 ELSE 0 END" for s, r in zip(sales_cols, req_cols)])
sales_expr  = " + ".join([f"COALESCE(`{c}`, 0)" for c in sales_cols])
req_expr    = " + ".join([f"COALESCE(`{c}`, 0)" for c in req_cols])

with_calcs = (
    with_inmaster
    .withColumn("MonthCount",       F.expr(active_expr))
    .withColumn("TotalSales",       F.expr(sales_expr))
    .withColumn("TotalRequests",    F.expr(req_expr))
    .withColumn("AvgMonthlyDemand", F.when(F.col("MonthCount") > 0, F.col("TotalRequests") / F.col("MonthCount")).otherwise(0.0))
    .withColumn("AvgMonthlySales",  F.when(F.col("MonthCount") > 0, F.col("TotalSales")    / F.col("MonthCount")).otherwise(0.0))
    .withColumn("MonthCountCapped",
        F.when(F.col("MonthCount") == 0, 1)
         .when(F.col("MonthCount") > 19, 19)
         .otherwise(F.col("MonthCount")))
)

rop_sel = rop_matrix.select(
    F.col("MonthCount").alias("ROP_MonthCount"),
    "DemandL", "DemandH", "SalesL", "SalesH",
    "Modifier", "WarehouseMin", "StockingWeeks", "TrendingCap",
    "SpikingModifier", "SpikingWarehouseStockingMin"
)

with_rop = with_calcs.join(
    F.broadcast(rop_sel),
    (F.col("MonthCountCapped") == F.col("ROP_MonthCount")) &
    (F.col("AvgMonthlyDemand") >= F.col("DemandL")) &
    (F.col("AvgMonthlyDemand") <  F.col("DemandH")) &
    (F.col("AvgMonthlySales")  >= F.col("SalesL"))  &
    (F.col("AvgMonthlySales")  <  F.col("SalesH")),
    "left"
).withColumn("Modifier_eff",     F.coalesce(F.col("Modifier"),     F.lit(1.0))) \
 .withColumn("WarehouseMin_eff", F.coalesce(F.col("WarehouseMin"), F.lit(1)))

result = (
    with_rop
    .withColumn("CalcROP", F.col("AvgMonthlyDemand") * F.col("Modifier_eff"))
    .withColumn("StockingTarget",
        F.ceil(F.greatest(
            F.col("WarehouseMin_eff").cast("double"),
            F.col("MinimumQty").cast("double"),
            F.col("CalcROP")
        )).cast("int")
    )
    .withColumn("RecommendedOrderQty",
        F.greatest(F.lit(0),
            F.col("StockingTarget") - F.col("QuantityOnHand").cast("int") - F.col("OnOrder").cast("int")
        ).cast("int")
    )
    .withColumn("EstOrderValue", F.col("RecommendedOrderQty").cast("double") * F.col("Cost"))
)

final = result.select(
    "Branch", "PartNumber", "Franchise", "Description", "VendorCode",
    "SLC", "Source", "CommodityCode", "DealerGroupCode",
    "QuantityOnHand", "OnOrder", "BackOrderQty", "MinimumQty", "MaximumQty",
    "Cost", "SellPrice1", "ListPrice", "Bin", "BulkBin",
    "SuperTo", "SuperFrom", "DateCreated", "DateLastRequested",
    "ReorderCode", "ActivityCode", "PackageQty",
    "Current12MoSales", "Previous12MoSales", "Current12MoRequests", "Previous12MoRequests",
    "Current12LostSalesQty", "Current12LostSalesValue",
    "SystemSuggestedOrderQty",
    "ProdGroup", "StockingMonths", "MarginFlag", "SalesClass", "Category",
    "MonthCount", "AvgMonthlyDemand", "AvgMonthlySales",
    "CalcROP", "StockingTarget", "RecommendedOrderQty", "EstOrderValue"
)

final.write.mode("overwrite").saveAsTable("Fact_NonJD_Reorder")
print(f"Done — {final.count():,} rows written to Fact_NonJD_Reorder")
*/
