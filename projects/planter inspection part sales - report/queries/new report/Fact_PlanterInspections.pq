/*
============================================================================
FACT_PLANTER_INSPECTIONS — PLANTER INSPECTION LABOR & WORK ORDER SUMMARY
============================================================================

Purpose:     One row per invoiced planter inspection job per work order.
             Tracks the inspection event, associated labor revenue, customer,
             and branch. This is the "spine" of the Inspection Part Sales page —
             everything else joins back to InvoiceNumber.
Grain:       One row per planter inspection job per work order (invoiced only)
Refresh:     Full refresh (small dataset, ~100-500 rows per season, fast)
Sources:     wkothsub, WKROFILE (Lakehouse — LH_Master_Data)

Business Use:
- Total Planter Inspections count (COUNTROWS or DISTINCTCOUNT on WorkOrderNumber)
- Total Labor $ from planter inspections (SUM InvoicedLaborAmount)
- Customer list of who received a planter inspection
- "Inspections with Part Sales" KPI — DAX join to Fact_PlanterInspectionParts
- "Planter Promo" KPI — DAX check for *PLANTER part on the invoice
- Branch/location breakdown of inspection activity

Columns Output:
- BranchCode            Branch location identifier
- WorkOrderNumber       Work order number
- InvoiceNumber         Invoice number — links to Fact_PlanterInspectionParts
- CustomerNumber        Customer account number (CHARGE_ACCT from WKROFILE)
- InvoicedLaborAmount   Labor amount invoiced for the inspection
- InvoiceDate           Invoice date (used by dim_DateTable relationship)
- WorkOrderCreationDate When the work order was opened

Design Decisions:
- Date filter: InvoiceDate >= 1/1/2025 at source for performance. The date
  dimension and slicer handle any further narrowing at report time.
- Only includes invoiced rows (InvoiceNumber not null/empty). Uninvoiced
  work orders are excluded — we need the invoice number to join parts.
- CustomerNumber comes from WKROFILE.AccountNumber (= CHARGE_ACCT), which
  matches dim_CustomerList.CustomerNumber.
- LEFT JOIN to WKROFILE is used defensively; 100% match rate expected.
============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD SOURCE TABLES
    // ========================================================================

    WkothsubSource = wkothsub,
    WkrofileSource = WKROFILE,

    // ========================================================================
    // STEP 2: FILTER WKOTHSUB TO PLANTER INSPECTIONS
    // ========================================================================
    // Keep only:
    //   - IS-PLANTER INSPECT job code
    //   - Invoiced rows (InvoiceNumber present, InvoiceDate >= 2025-01-01)

    PlanterInspections = Table.SelectRows(
        WkothsubSource,
        each [JobCode] = "IS-PLANTER INSPECT"
            and [InvoiceNumber] <> null
            and [InvoiceNumber] <> ""
            and [InvoiceDate] <> null
            and Date.From([InvoiceDate]) >= #date(2025, 1, 1)
    ),

    // Select only the columns needed — avoids carrying unused fields forward
    InspectionColumns = Table.SelectColumns(
        PlanterInspections,
        {"Branch", "WorkOrder", "InvoiceNumber", "InvLabor", "InvoiceDate"}
    ),

    // ========================================================================
    // STEP 3: GET CUSTOMER NUMBER AND CREATION DATE FROM WKROFILE
    // ========================================================================
    // AccountNumber = CHARGE_ACCT = the customer billed for the work order

    WkrofileColumns = Table.SelectColumns(
        WkrofileSource,
        {"Branch", "WorkOrder", "AccountNumber", "CreatedOn"}
    ),

    JoinWkrofile = Table.NestedJoin(
        InspectionColumns,
        {"Branch", "WorkOrder"},
        WkrofileColumns,
        {"Branch", "WorkOrder"},
        "WkrofileMatch",
        JoinKind.LeftOuter
    ),

    ExpandWkrofile = Table.ExpandTableColumn(
        JoinWkrofile,
        "WkrofileMatch",
        {"AccountNumber", "CreatedOn"},
        {"CustomerNumber", "WorkOrderCreationDate"}
    ),

    // ========================================================================
    // STEP 4: RENAME COLUMNS TO REPORT-READY NAMES
    // ========================================================================

    RenameColumns = Table.RenameColumns(
        ExpandWkrofile,
        {
            {"Branch",      "BranchCode"},
            {"WorkOrder",   "WorkOrderNumber"},
            {"InvLabor",    "InvoicedLaborAmount"}
        }
    ),

    // ========================================================================
    // STEP 5: SET DATA TYPES
    // ========================================================================

    // CustomerNumber comes from WKROFILE.AccountNumber (CHARGE_ACCT), which the
    // Lakehouse stores as a float (e.g. 28840.000000). Convert to integer then
    // text to get a clean account number string that matches dim_CustomerList.
    CleanCustomerNumber = Table.TransformColumns(
        RenameColumns,
        {{"CustomerNumber", each if _ = null then null else Text.From(Int64.From(_)), type text}}
    ),

    SetDataTypes = Table.TransformColumnTypes(
        CleanCustomerNumber,
        {
            {"BranchCode",            type text},
            {"WorkOrderNumber",       type text},
            {"InvoiceNumber",         type text},
            {"CustomerNumber",        type text},
            {"InvoicedLaborAmount",   type number},
            {"InvoiceDate",           type date},
            {"WorkOrderCreationDate", type date}
        }
    )

in
    SetDataTypes
