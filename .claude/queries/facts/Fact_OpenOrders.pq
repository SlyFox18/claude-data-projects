/*
============================================================================
Query: Fact_OpenOrders
Dataflow: df_OpenOrders
Location: LH_Master_Data → Dataflows → 04 - Fact
============================================================================

PURPOSE: All currently open (not-yet-invoiced) work orders with their job codes.
Combined with Fact_JobCodePartFrequency in the Recommendations DAX calculated
table to produce part recommendations.

GRAIN: One row per WorkOrder × JobCode
SOURCE: WKROFILE (open order filter) INNER JOIN wkothsub (job codes)
FILTER: ro_closed_ind = 'N' (open orders only)

NOTE: wkothsub has 2023+ scope via incremental refresh. Open orders older than
3 years without recent modifications may not have job codes visible here.
In practice this affects a negligible number of orders.

OUTPUT COLUMNS:
  WorkOrderNumber  TEXT  — work order / RO number
  BranchCode       TEXT  — branch identifier
  CustomerNumber   TEXT  — customer account (joins to dim_CustomerList)
  JobCode          TEXT  — job code on this open order
  OpenDate         DATE  — work order creation date

REFRESH: Full daily, Phase 4 — small dataset (hundreds to low thousands of rows)
============================================================================
*/

let
    // =====================================================================
    // STEP 1: OPEN WORK ORDERS FROM WKROFILE
    // Adjust the WHERE clause if Task 1 found a different status value.
    // =====================================================================
    SQL_OpenOrders =
        "SELECT
             BRANCH        AS BranchCode,
             RO_NUMBER     AS WorkOrderNumber,
             CHARGE_ACCT   AS CustomerNumber,
             Creation_Date AS OpenDate
         FROM WKROFILE
         WHERE ro_closed_ind = 'N'",

    OpenOrders = Odbc.Query("dsn=EquipRDB64", SQL_OpenOrders),
    OpenOrders_Typed = Table.TransformColumnTypes(OpenOrders, {
        {"BranchCode",      type text},
        {"WorkOrderNumber", type text},
        {"CustomerNumber",  type text},
        {"OpenDate",        type date}
    }),

    // =====================================================================
    // STEP 2: JOB CODES FROM wkothsub FOR OPEN ORDERS
    // Open orders have no invoice number yet (INVOICE_NO is null/empty).
    // =====================================================================
    SQL_Jobs =
        "SELECT
             RO_BRANCH AS BranchCode,
             RO_NUMBER AS WorkOrderNumber,
             JOB_CODE  AS JobCode
         FROM wkothsub
         WHERE INVOICE_NO IS NULL
            OR INVOICE_NO = ''",

    Jobs = Odbc.Query("dsn=EquipRDB64", SQL_Jobs),
    Jobs_Typed = Table.TransformColumnTypes(Jobs, {
        {"BranchCode",      type text},
        {"WorkOrderNumber", type text},
        {"JobCode",         type text}
    }),

    // =====================================================================
    // STEP 3: JOIN OPEN ORDERS TO JOB CODES
    // INNER JOIN — only include open orders that have at least one job code.
    // =====================================================================
    Joined = Table.NestedJoin(
        OpenOrders_Typed, {"WorkOrderNumber", "BranchCode"},
        Jobs_Typed,       {"WorkOrderNumber", "BranchCode"},
        "Jobs",
        JoinKind.Inner
    ),
    Expanded = Table.ExpandTableColumn(Joined, "Jobs", {"JobCode"}),
    WithJobCodes = Table.SelectRows(Expanded,
        each [JobCode] <> null and [JobCode] <> ""),

    // =====================================================================
    // FINAL TYPES
    // =====================================================================
    Final = Table.TransformColumnTypes(WithJobCodes, {
        {"WorkOrderNumber", type text},
        {"BranchCode",      type text},
        {"CustomerNumber",  type text},
        {"JobCode",         type text},
        {"OpenDate",        type date}
    })
in
    Final
