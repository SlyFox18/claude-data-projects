/*
============================================================================
Query: InMaster_Raw
Dataflow: df_InMaster_Parts_Ordering_Raw
Location: LH_Master_Data → Dataflows → 01 - Raw Sources
============================================================================

PURPOSE: Parts master data from InMaster — provides stocking months,
sales class, category, and margin flag (user_field_3 = "LOW") for the
Non-JD Parts Order Tool. Filtered to non-JD franchises only at source.

GRAIN: One row per Branch + PartNumber (non-JD franchises only)

SOURCE: SQL Anywhere (ODBC: EquipRDB64) — InMaster table

REFRESH: Full refresh, once daily (Phase 1 of pipeline)

NOTE: Dataflow named df_InMaster_Parts_Ordering_Raw because df_InMaster_Raw
was already taken by an existing dataflow. Lakehouse table is InMaster_Raw.

KEY COLUMNS:
  MarginFlag (user_field_3) — only value in use is "LOW" (low margin parts)
  StockingMonths (STK_IN_MTH) — months in stocking, used in ROP context
  ProdGroup — contains vendor names for non-JD parts (not ROP group codes)
============================================================================
*/

let
    SQL = "
        SELECT
            BRANCH          AS Branch,
            FRANCHISE       AS Franchise,
            PART_NO         AS PartNumber,
            PART_DESC       AS Description,
            PROD_GROUP      AS ProdGroup,
            SALES_CLASS     AS SalesClass,
            CATEGORY        AS Category,
            VENDOR_CODE     AS VendorCode,
            MINIMUM_QTY     AS MinimumQty,
            MAXIMUM_QTY     AS MaximumQty,
            REORDER_CODE    AS ReorderCode,
            ACTIVITY_CODE   AS ActivityCode,
            STK_IN_MTH      AS StockingMonths,
            user_field_3    AS MarginFlag,
            CREATION_DATE   AS DateCreated,
            LAST_DEM_DATE   AS DateLastDemand,
            ModifiedDate    AS ModifiedDate
        FROM InMaster
        WHERE FRANCHISE NOT IN ('D', 'ZP', 'S', 'TD', 'TM', 'UD', 'UM', '95')
    ",
    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source