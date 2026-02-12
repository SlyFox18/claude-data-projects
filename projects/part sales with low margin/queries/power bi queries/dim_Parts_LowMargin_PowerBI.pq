/*
============================================================================
DIM_PARTS_LOWMARGIN - FOR POWER BI DIRECT IMPORT
============================================================================
Purpose: Lightweight dimension with low margin fields from InMaster
Source: InMaster table from Lakehouse
Usage: RELATED() function in calculated columns
============================================================================
*/

let
    // ========================================================================
    // STEP 1: CONNECT TO INMASTER FROM LAKEHOUSE
    // ========================================================================

    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InMaster = Source{[Schema="dbo",Item="InMaster"]}[Data],

    // ========================================================================
    // STEP 2: SELECT LOW MARGIN FIELDS + INVENTORY FIELDS
    // ========================================================================
    /*
    Includes fields for both:
    - Transaction analysis (Page 1): LowMarginFlag, StockOrderPrice, ListPrice
    - Inventory analysis (Pages 2 & 3): BulkBinQty, OnHandQty, Cost
    */

    SelectColumns = Table.SelectColumns(dbo_InMaster, {
        "PartNumber",
        "Franchise",
        "Branch",

        // Low margin flag fields
        "LowMarginFlag",
        "StockOrderPrice",
        "ListPrice",

        // Inventory quantity fields (for SOH calculations)
        "BulkBinQty",
        "OnHandQty",

        // Cost field (for inventory discrepancy analysis)
        "Cost"              // This is the inventory cost
    }),

    // ========================================================================
    // STEP 3: CLEAN AND TRANSFORM
    // ========================================================================

    CleanFields = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Branch", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"LowMarginFlag", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ========================================================================
    // STEP 4: REMOVE BLANKS AND DEDUPLICATE
    // ========================================================================

    RemoveBlankParts = Table.SelectRows(CleanFields, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Deduplicate by PartNumber (for simple join to fact table)
    RemoveDuplicates = Table.Distinct(RemoveBlankParts, {"PartNumber"}),

    // ========================================================================
    // STEP 5: ADD BOOLEAN FLAG
    // ========================================================================

    AddIsLowMarginFlagged = Table.AddColumn(
        RemoveDuplicates,
        "IsLowMarginFlagged",
        each [LowMarginFlag] = "LOW",
        type logical
    ),

    // ========================================================================
    // STEP 6: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(AddIsLowMarginFlagged, {
        {"PartNumber", type text},
        {"Franchise", type text},
        {"Branch", type text},
        {"LowMarginFlag", type text},
        {"IsLowMarginFlagged", type logical},
        {"StockOrderPrice", type number},
        {"ListPrice", type number},
        {"BulkBinQty", type number},
        {"OnHandQty", type number},
        {"Cost", type number}
    })

in
    FinalDataTypes

/*
============================================================================
USAGE IN POWER BI MODEL:

1. Create relationship (inactive):
   Fact_InTrans[PartNumber] → dim_Parts_LowMargin[PartNumber]

2. Add calculated columns to Fact_InTrans:

   LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])
   StockOrderPrice = RELATED(dim_Parts_LowMargin[StockOrderPrice])
   ListPriceManuf = RELATED(dim_Parts_LowMargin[ListPrice])

3. Use in measures and filtering

Expected Refresh Time: <30 seconds
Expected Row Count: ~1M parts
============================================================================
*/
