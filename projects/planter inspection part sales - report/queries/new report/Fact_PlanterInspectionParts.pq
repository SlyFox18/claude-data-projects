/*
============================================================================
FACT_PLANTER_INSPECTION_PARTS — PARTS SOLD ON PLANTER INSPECTION INVOICES
============================================================================

Purpose:     All parts transactions on invoices linked to planter inspection
             work orders. Captures every line item (including discount/promo
             codes) sold on those invoices.
Grain:       One row per part transaction per invoice
Refresh:     Full refresh
Sources:     wkothsub, InTrans_Incremental (Lakehouse — LH_Master_Data)

Business Use:
- Total Parts Sale $ for Page 1 (filter Franchise <> 'ZP' in DAX)
- Total Parts Cost $ for Page 1 (filter Franchise <> 'ZP' in DAX)
- Customer-level parts breakdown (what was sold on each inspection invoice)
- Planter Promo flag: PartNumber = '*PLANTER' AND Franchise = 'ZP' on the
  invoice means the customer used the pre-planter parts promo
- Branch/location parts revenue breakdown
- Part Sales by Location bar chart

Key Logic — Invoice-Based Join:
  InTrans_Incremental.RONumber = Invoice Number (NOT work order number)
  This is the same join pattern used by Fact_WorkOrderParts in the
  Inspections report. Joining on work order number would produce wrong results.

Step 1:  Get distinct Branch + InvoiceNumber from wkothsub where
         JobCode = 'IS-PLANTER INSPECT' (same filter as Fact_PlanterInspections)
Step 2:  Filter InTrans_Incremental to the date range
Step 3:  Inner join InTrans to the invoice list on Branch + RONumber

All franchise codes are kept (including ZP). Filtering ZP out for "real parts"
measures is done in DAX so that the Planter Promo flag still works:
- Real parts:     Franchise <> 'ZP'
- Planter Promo:  PartNumber = '*PLANTER' AND Franchise = 'ZP'

Columns Output:
- BranchCode        Branch location
- InvoiceNumber     Links to Fact_PlanterInspections
- CustomerNumber    Customer account number (from InTrans CustomerNo)
- PartNumber        Part identifier
- Description       Part description
- Franchise         ZP = promo/discount item; others = real parts
- Quantity          Quantity sold
- SaleValue         Sale amount (negative for discounts/ZP items)
- CostValue         Cost amount
- TransactionDate   Date of part transaction (used by dim_DateTable)

Design Decisions:
- Date filter on InTrans: >= 1/1/2025 for performance (10M+ row table)
- Both join columns converted to TEXT before the join to prevent type errors
- No row deduplication needed here — unlike the shared InTrans_Incremental
  table, planter inspection invoices are a narrow, well-defined set with
  no known duplication issue
============================================================================
*/

let
    // ========================================================================
    // STEP 1: DERIVE PLANTER INSPECTION INVOICE LIST FROM WKOTHSUB
    // ========================================================================
    // Same filter criteria as Fact_PlanterInspections — keeps both tables
    // in sync if the date range ever changes.

    WkothsubSource = wkothsub,

    PlanterRows = Table.SelectRows(
        WkothsubSource,
        each [JobCode] = "IS-PLANTER INSPECT"
            and [InvoiceNumber] <> null
            and [InvoiceNumber] <> ""
            and [InvoiceDate] <> null
            and Date.From([InvoiceDate]) >= #date(2025, 1, 1)
    ),

    // Distinct Branch + InvoiceNumber — one invoice may have many job rows
    // in wkothsub but we only need unique invoice identifiers for the join
    InspectionInvoices = Table.Distinct(
        Table.SelectColumns(PlanterRows, {"Branch", "InvoiceNumber"})
    ),

    // Convert to TEXT before join to prevent numeric type mismatch errors
    InvoicesAsText = Table.TransformColumnTypes(
        InspectionInvoices,
        {
            {"Branch",        type text},
            {"InvoiceNumber", type text}
        }
    ),

    // ========================================================================
    // STEP 2: LOAD AND DATE-FILTER INTRANS_INCREMENTAL
    // ========================================================================
    // InTrans_Incremental is 10M+ rows — the date filter is critical for
    // performance before the join narrows it down further.

    PartsSource = InTrans_Incremental,

    PartsFiltered = Table.SelectRows(
        PartsSource,
        each Date.From([TransDatetime]) >= #date(2025, 1, 1)
    ),

    // Convert join columns to TEXT — RONumber in InTrans = Invoice Number
    PartsAsText = Table.TransformColumnTypes(
        PartsFiltered,
        {
            {"Branch",   type text},
            {"RONumber", type text}
        }
    ),

    // ========================================================================
    // STEP 3: INNER JOIN — KEEP ONLY PARTS ON PLANTER INSPECTION INVOICES
    // ========================================================================

    FilterToInspectionInvoices = Table.NestedJoin(
        PartsAsText,
        {"Branch", "RONumber"},       // InTrans columns
        InvoicesAsText,
        {"Branch", "InvoiceNumber"},  // wkothsub-derived invoice list
        "InspectionMatch",
        JoinKind.Inner
    ),

    RemoveMatchColumn = Table.RemoveColumns(
        FilterToInspectionInvoices,
        {"InspectionMatch"}
    ),

    // ========================================================================
    // STEP 4: SELECT ONLY NEEDED COLUMNS
    // ========================================================================

    SelectColumns = Table.SelectColumns(
        RemoveMatchColumn,
        {
            "Branch", "RONumber", "CustomerNo", "PartNumber", "Description",
            "Franchise", "Qty", "SaleValue", "CostValue", "TransDatetime"
        }
    ),

    // ========================================================================
    // STEP 5: RENAME TO REPORT-READY NAMES
    // ========================================================================

    RenameColumns = Table.RenameColumns(
        SelectColumns,
        {
            {"Branch",       "BranchCode"},
            {"RONumber",     "InvoiceNumber"},
            {"CustomerNo",   "CustomerNumber"},
            {"Qty",          "Quantity"},
            {"TransDatetime","TransactionDate"}
        }
    ),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================

    SetDataTypes = Table.TransformColumnTypes(
        RenameColumns,
        {
            {"BranchCode",      type text},
            {"InvoiceNumber",   type text},
            {"CustomerNumber",  type text},
            {"PartNumber",      type text},
            {"Description",     type text},
            {"Franchise",       type text},
            {"Quantity",        type number},
            {"SaleValue",       type number},
            {"CostValue",       type number},
            {"TransactionDate", type date}
        }
    )

in
    SetDataTypes
