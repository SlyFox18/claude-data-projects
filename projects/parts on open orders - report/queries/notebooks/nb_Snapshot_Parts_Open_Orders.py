# ============================================================================
# NOTEBOOK: nb_Snapshot_Parts_Open_Orders
# ============================================================================
#
# PURPOSE:
#   Takes a beginning-of-month snapshot of all currently open parts orders
#   and appends it to Fact_Parts_Open_Orders_Snapshot in LH_Master_Data.
#   Run on the 1st of each month (via Pipeline_Monthly_Open_Orders_Snapshot).
#
# GRAIN: One row per open order per SnapshotDate (beginning of month)
# SOURCE: Fact_Parts_Open_Tickets (already refreshed by daily pipeline)
# TARGET: Fact_Parts_Open_Orders_Snapshot (Delta table, append mode)
#
# SCHEDULING:
#   Monthly pipeline scheduled for 5:30 AM on the 1st of each month.
#   The 5:30 AM time ensures the daily pipeline (3:30 AM, ~80 min) has
#   already refreshed Fact_Parts_Open_Tickets before this runs.
#
# BACKFILL NOTE:
#   Because Fact_Parts_Open_Tickets only shows CURRENT open orders,
#   there is no way to backfill prior months. The snapshot history
#   begins from the first time this notebook runs.
#
# DUPLICATE PROTECTION:
#   The notebook checks for an existing snapshot before writing.
#   Safe to rerun — it will skip if the month is already captured.
#
# ============================================================================

# ============================================================================
# CELL 1 — SETUP
# Paste this into the first code cell of the Fabric notebook.
# ============================================================================

from pyspark.sql import functions as F
from datetime import date

# SnapshotDate is always the 1st of the CURRENT month.
# This is a permanent historical record — the date does not drift.
today = date.today()
snapshot_date = today.replace(day=1)
snapshot_table = "Fact_Parts_Open_Orders_Snapshot"

print(f"Snapshot date : {snapshot_date}")
print(f"Target table  : {snapshot_table}")
print(f"Run date      : {today}")


# ============================================================================
# CELL 2 — DUPLICATE GUARD
# Paste this into the second code cell.
# Prevents double-writing if the notebook is accidentally rerun.
# ============================================================================

snapshot_ready = False

try:
    existing = spark.sql(f"""
        SELECT COUNT(*) AS cnt
        FROM {snapshot_table}
        WHERE SnapshotDate = '{snapshot_date}'
    """).collect()[0]["cnt"]

    if existing > 0:
        print(f"SKIPPED: Snapshot for {snapshot_date} already exists ({existing} rows). No action taken.")
    else:
        print(f"No existing snapshot for {snapshot_date}. Ready to proceed.")
        snapshot_ready = True

except Exception as e:
    # Table does not exist yet — expected on the very first run.
    # saveAsTable will create it automatically on the first write.
    print(f"Note: Snapshot table not found (expected on first run). Will create on write.")
    print(f"Detail: {e}")
    snapshot_ready = True


# ============================================================================
# CELL 3 — READ AND WRITE SNAPSHOT
# Paste this into the third code cell.
# Only runs if snapshot_ready = True (set by Cell 2).
# ============================================================================

if not snapshot_ready:
    print("No action taken — snapshot for this month already exists.")
else:
    # Read the current open orders from the fact table.
    # This table is refreshed daily by the main pipeline.
    # Columns with special characters (#, $$) require backtick quoting in Spark SQL.
    df = spark.sql("""
        SELECT
            Location,
            Location_Name,
            Order_No,
            Invoice_Type,
            Order_Date,
            Days_Open,
            Aging,
            Aging_Sort_Order,
            `#_Parts_On_Order`,
            `#_On_Back_Order`,
            `Order_Total_$$`,
            `$$_Available`,
            `$$_BackOrdered`,
            Backorder_Pct,
            Customer,
            Salesman
        FROM Fact_Parts_Open_Tickets
    """)

    # Count rows before writing to avoid a second scan
    row_count = df.count()
    print(f"Open orders to snapshot: {row_count}")

    # Add the snapshot date (always the 1st of the current month)
    df = df.withColumn("SnapshotDate", F.lit(str(snapshot_date)).cast("date"))

    # Append to the snapshot table.
    # mode="append"    — never overwrites existing snapshots
    # mergeSchema=True — handles any future column additions gracefully
    df.write \
        .mode("append") \
        .option("mergeSchema", "true") \
        .saveAsTable(snapshot_table)

    print(f"SUCCESS: {row_count} rows written to {snapshot_table} for {snapshot_date}")


# ============================================================================
# CELL 4 — VERIFICATION (optional, run manually to confirm)
# Paste this into a fourth code cell.
# Use after the first few runs to confirm snapshot history is building correctly.
# ============================================================================

# Uncomment and run manually to check snapshot history:
#
# summary = spark.sql("""
#     SELECT
#         SnapshotDate,
#         COUNT(*) AS Order_Count,
#         ROUND(SUM(`Order_Total_$$`), 2) AS Total_Order_Value,
#         ROUND(SUM(`$$_BackOrdered`), 2) AS Total_Backordered
#     FROM Fact_Parts_Open_Orders_Snapshot
#     GROUP BY SnapshotDate
#     ORDER BY SnapshotDate DESC
# """)
# summary.show()
