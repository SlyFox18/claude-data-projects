# How to Get Row Counts for Lakehouse Tables

Quick methods to get row counts for documentation purposes.

## Method 1: SQL Endpoint (Fastest)

In Fabric, go to your Lakehouse → SQL Endpoint:

```sql
SELECT COUNT(*) as CountRows FROM jdis_Part_Information;
```

**Pros:** Fast, exact count
**Cons:** Requires SQL endpoint access

## Method 2: Power Query in Dataflow

Add a step in your dataflow or create a test query:

```powerquery
let
    Source = YourLakehouseTable,
    Count = Table.RowCount(Source)
in
    Count
```

**Pros:** Works in existing dataflow
**Cons:** Loads entire table to count

## Method 3: Lakehouse Explorer

In Fabric Lakehouse:
1. Right-click table → Properties
2. Look for row count (may not always be available/current)

**Pros:** No query needed
**Cons:** May not be accurate or available

## Method 4: Power BI Desktop

If table is in your semantic model:
1. Open Power BI Desktop
2. Go to Data view
3. Select table
4. Look at bottom status bar (shows row count)

**Pros:** Exact count if model is refreshed
**Cons:** Requires Desktop and loaded model

## Recommended Approach for Documentation

**For raw tables:** Use SQL Endpoint method (Method 1)
**For dimensions/facts:** Use Power BI Desktop (Method 4) or SQL Endpoint

## Quick Reference SQL for All Raw Tables

```sql
-- Get row counts for all tables
SELECT 'jdis_Part_Information' as TableName, COUNT(*) as RowCount FROM jdis_Part_Information
UNION ALL
SELECT 'InMaster', COUNT(*) FROM InMaster
UNION ALL
SELECT 'Fact_InTrans', COUNT(*) FROM Fact_InTrans
UNION ALL
SELECT 'vhstock', COUNT(*) FROM vhstock;
-- Add more tables as needed
```

Copy all results at once for faster documentation!
