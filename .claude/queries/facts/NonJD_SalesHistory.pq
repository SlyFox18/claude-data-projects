/*
============================================================================
Query: NonJD_SalesHistory (Fact)
Notebook: nb_Fact_NonJD_SalesHistory
Location: LH_Master_Data → Notebooks
============================================================================

PURPOSE: Unpivots the 60-month wide sales and demand history from
NonJD_Parts_Ordering_Raw into a row-per-month format for the
Part Information history grid in the ordering tool.

GRAIN: One row per Branch + PartNumber + MonthOffset (1=most recent, 60=oldest)

IMPLEMENTATION: PySpark Notebook (NOT a Dataflow Gen2)
  Power Query M cannot efficiently unpivot 120 columns × ~200K rows.
  The stack() SparkSQL function handles this in a single pass.

DEPENDENCIES: NonJD_Parts_Ordering_Raw (must refresh first)

PIPELINE: Phase 4 (Facts) — Notebook activity, not Dataflow activity
============================================================================

PySpark code (paste into a single notebook cell):

from pyspark.sql import functions as F

df = spark.read.table("NonJD_Parts_Ordering_Raw")

identity_cols = ["Branch", "PartNumber", "Franchise"]

stack_args = ", ".join(
    [f"{i}, `SalesMonth{i:02d}`, `RequestsMonth{i:02d}`" for i in range(1, 61)]
)
stack_expr = f"stack(60, {stack_args}) as (MonthOffset, SalesQty, DemandCount)"

result = (
    df.selectExpr(*identity_cols, stack_expr)
      .select(
          F.col("Branch").cast("string"),
          F.col("PartNumber").cast("string"),
          F.col("Franchise").cast("string"),
          F.col("MonthOffset").cast("int"),
          F.col("SalesQty").cast("int"),
          F.col("DemandCount").cast("int")
      )
)

result.write.mode("overwrite").saveAsTable("Fact_NonJD_SalesHistory")
print(f"Done — {result.count():,} rows written to Fact_NonJD_SalesHistory")
*/
