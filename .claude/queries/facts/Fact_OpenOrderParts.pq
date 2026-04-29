/*
============================================================================
Query: Fact_OpenOrderParts
Dataflow: df_OpenOrderParts
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: Parts already committed to open (not-yet-invoiced) work orders.
Used in the Recommendations DAX calculated table to suppress parts that are
already on the order from appearing as recommendations.

GRAIN: One row per WorkOrder × PartNumber
SOURCE: InSalPar (part lines) → InSalOrd (order header) → WkRoFile (status)

JOIN CHAIN:
  InSalPar.FILE_NO = InSalOrd.FILE_NO
  InSalOrd.RO_NUMBER + RO_BRANCH = WkRoFile.RO_NUMBER + BRANCH

FILTERS:
  InSalOrd.TYPE = 'W'         (work orders only, not other order types)
  WkRoFile.ro_closed_ind = 'N' (open orders only)

NOTE: In Fabric Dataflow Gen2, insalpar and insalord are already Lakehouse
tables (raw Phase 1 dataflows). Use Lakehouse connectors for those two
tables. WkRoFile is also in the Lakehouse. Replace ODBC sources below with
Lakehouse connectors when building in Fabric.

OUTPUT COLUMNS:
  WorkOrderNumber  TEXT  — work order / RO number
  BranchCode       TEXT  — branch identifier
  PartNumber       TEXT  — part number already on this open order

REFRESH: Full daily, Phase 4 — small dataset
============================================================================
*/

let
    // =====================================================================
    // STEP 1: PART LINES FROM InSalPar
    // FILE_NO is the order header key that links to InSalOrd.
    // In Fabric: use Lakehouse connector → insalpar table.
    // =====================================================================
    SQL_Parts =
        "SELECT
             FILE_NO AS FileNumber,
             PART_NO AS PartNumber
         FROM InSalPar
         WHERE PART_NO IS NOT NULL
           AND PART_NO <> ''",

    Parts = Odbc.Query("dsn=EquipRDB64", SQL_Parts),
    Parts_Typed = Table.TransformColumnTypes(Parts, {
        {"FileNumber", type text},
        {"PartNumber", type text}
    }),

    // =====================================================================
    // STEP 2: ORDER HEADERS FROM InSalOrd — WORK ORDERS ONLY
    // TYPE = 'W' filters to work orders (excludes other order types).
    // In Fabric: use Lakehouse connector → insalord table.
    // =====================================================================
    SQL_Orders =
        "SELECT
             FILE_NO   AS FileNumber,
             RO_NUMBER AS WorkOrderNumber,
             RO_BRANCH AS BranchCode
         FROM InSalOrd
         WHERE TYPE = 'W'",

    Orders = Odbc.Query("dsn=EquipRDB64", SQL_Orders),
    Orders_Typed = Table.TransformColumnTypes(Orders, {
        {"FileNumber",      type text},
        {"WorkOrderNumber", type text},
        {"BranchCode",      type text}
    }),

    // =====================================================================
    // STEP 3: OPEN ORDER STATUS FROM WkRoFile
    // Join to confirm the work order is still open (not yet invoiced).
    // In Fabric: use Lakehouse connector → WKROFILE table.
    // =====================================================================
    SQL_OpenWOs =
        "SELECT
             RO_NUMBER AS WorkOrderNumber,
             BRANCH    AS BranchCode
         FROM WkRoFile
         WHERE ro_closed_ind = 'N'",

    OpenWOs = Odbc.Query("dsn=EquipRDB64", SQL_OpenWOs),
    OpenWOs_Typed = Table.TransformColumnTypes(OpenWOs, {
        {"WorkOrderNumber", type text},
        {"BranchCode",      type text}
    }),

    // =====================================================================
    // STEP 4: JOIN InSalPar → InSalOrd (via FILE_NO)
    // =====================================================================
    PartsWithOrders = Table.NestedJoin(
        Parts_Typed,  {"FileNumber"},
        Orders_Typed, {"FileNumber"},
        "Orders",
        JoinKind.Inner
    ),
    PartsWithOrdersExpanded = Table.ExpandTableColumn(
        PartsWithOrders, "Orders",
        {"WorkOrderNumber", "BranchCode"}
    ),

    // =====================================================================
    // STEP 5: JOIN TO WkRoFile (OPEN ORDERS ONLY)
    // INNER JOIN — only include parts for orders that are currently open.
    // =====================================================================
    OpenOrderParts = Table.NestedJoin(
        PartsWithOrdersExpanded, {"WorkOrderNumber", "BranchCode"},
        OpenWOs_Typed,           {"WorkOrderNumber", "BranchCode"},
        "OpenStatus",
        JoinKind.Inner
    ),

    // =====================================================================
    // FINAL COLUMNS — drop join artifacts, keep only what DAX needs
    // =====================================================================
    Selected = Table.SelectColumns(
        OpenOrderParts,
        {"WorkOrderNumber", "BranchCode", "PartNumber"}
    ),

    Final = Table.TransformColumnTypes(Selected, {
        {"WorkOrderNumber", type text},
        {"BranchCode",      type text},
        {"PartNumber",      type text}
    })
in
    Final
