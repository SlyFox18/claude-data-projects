/*
============================================================================
FACT_PLANTER_PART_SALES — ALL SALES OF PLANTER-CLASSIFIED PARTS
============================================================================

Purpose:     All part transactions where the part is planter-classified —
             regardless of whether the customer had an inspection. This
             powers the "Planter Part Sales" page (Page 2).
Grain:       One row per part transaction
Refresh:     Full refresh
Sources:     InTrans_Incremental, dim_Parts (Lakehouse — LH_Master_Data)

Business Use:
- Total planter parts revenue and cost (all customers, all branches)
- Customer breakdown of planter part purchases
- Location (branch) analysis — bar chart and pie chart
- Distinct purpose from Fact_PlanterInspectionParts:
    Fact_PlanterInspectionParts = parts on inspection invoices (any part)
    Fact_PlanterPartSales       = planter-classified parts on any invoice

Planter Part Identification (two criteria, both sourced from dim_Parts):
  1. CommodityCode IN ('310'-'318') — planter equipment commodity codes
  2. PartNumber contains "PLANTER" — catches promo and specialty planter parts
     (e.g. *PLANTER pre-planter parts promo is in dim_Parts)

  Both criteria are evaluated against dim_Parts (small table) to build a
  single part number lookup table, then InTrans_Incremental is joined to it
  once via Table.NestedJoin (folds to SQL).

Columns Output:
- BranchCode        Branch location
- InvoiceNumber     Invoice reference
- CustomerNumber    Customer account number
- PartNumber        Part identifier
- Description       Part description
- Franchise         Franchise code
- Quantity          Quantity sold
- SaleValue         Sale amount
- CostValue         Cost amount
- TransactionDate   Date of transaction (used by dim_DateTable)

Design Decisions:
- ZP franchise items INCLUDED. Filtering ZP out for "real parts" metrics is
  done in DAX (Franchise <> 'ZP'). ZP items are needed here so that the
  Planter Promo flag (*PLANTER / Franchise = 'ZP') can be detected for
  inspection customers in the same table.
- Date filter: >= 1/1/2025 consistent with the other fact tables.
- CRITICAL PERFORMANCE FIX: List.Contains inside Table.SelectRows breaks
  query folding on 10M+ row tables and causes timeouts. This query uses
  Table.NestedJoin instead, which folds to a SQL JOIN at the Lakehouse
  SQL endpoint. dim_Parts is filtered first (small operation), then
  InTrans_Incremental is joined to the resulting part number table once.
============================================================================
*/

let
    // ========================================================================
    // STEP 1: BUILD PLANTER PART NUMBER LOOKUP TABLE FROM DIM_PARTS
    // ========================================================================
    // dim_Parts is small — build the complete lookup here, then join InTrans
    // to it once. Avoids row-by-row evaluation against InTrans (10M+ rows).

    DimPartsSource = dim_Parts,

    // Criterion 1: Commodity codes 310-318 (planter equipment codes)
    PlanterByCommodityCode = Table.SelectRows(
        DimPartsSource,
        each [CommodityCode] = "310" or [CommodityCode] = "311"
          or [CommodityCode] = "312" or [CommodityCode] = "313"
          or [CommodityCode] = "314" or [CommodityCode] = "315"
          or [CommodityCode] = "316" or [CommodityCode] = "317"
          or [CommodityCode] = "318"
    ),

    // Criterion 2: PartNumber contains "PLANTER" (catches *PLANTER promo etc.)
    PlanterByName = Table.SelectRows(
        DimPartsSource,
        each Text.Contains([PartNumber] ?? "", "PLANTER")
    ),

    // Combine both criteria and keep only distinct PartNumbers
    PlanterPartNumbers = Table.Distinct(
        Table.SelectColumns(
            Table.Combine({PlanterByCommodityCode, PlanterByName}),
            {"PartNumber"}
        )
    ),

    // ========================================================================
    // STEP 2: LOAD AND DATE-FILTER INTRANS_INCREMENTAL
    // ========================================================================

    PartsSource = InTrans_Incremental,

    PartsFiltered = Table.SelectRows(
        PartsSource,
        each Date.From([TransDatetime]) >= #date(2025, 1, 1)
            and [Type] = "I"   // Invoice transactions only — excludes inter-branch transfers
    ),

    // ========================================================================
    // STEP 3: INNER JOIN INTRANS TO PLANTER PART NUMBER LIST
    // ========================================================================
    // Table.NestedJoin folds to a SQL JOIN at the Lakehouse endpoint.
    // One scan of InTrans, returns only rows where PartNumber is planter-classified.

    PlanterPartsJoin = Table.NestedJoin(
        PartsFiltered,
        {"PartNumber"},
        PlanterPartNumbers,
        {"PartNumber"},
        "PlanterMatch",
        JoinKind.Inner
    ),

    RemoveMatchColumn = Table.RemoveColumns(PlanterPartsJoin, {"PlanterMatch"}),

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
            {"Branch",        "BranchCode"},
            {"RONumber",      "InvoiceNumber"},
            {"CustomerNo",    "CustomerNumber"},
            {"Qty",           "Quantity"},
            {"TransDatetime", "TransactionDate"}
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
