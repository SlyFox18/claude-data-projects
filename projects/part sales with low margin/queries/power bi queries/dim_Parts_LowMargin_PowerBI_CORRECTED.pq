/*
============================================================================
DIM_PARTS_LOWMARGIN - CORRECTED HYBRID (InMaster + jdis_Part_Information)
============================================================================
Purpose: Low margin dimension combining CORRECT columns from both tables:
  - InMaster: LowMarginFlag, StockOrderPrice
  - jdis_Part_Information: InventoryCost, ListPrice, SellPrice1, QuantityOnHand, BulkBinQty

Source: Both InMaster AND jdis_Part_Information from Lakehouse
Usage: RELATED() function in calculated columns + inventory analysis

CRITICAL: BulkBinQty exists in jdis_Part_Information, NOT in InMaster!
============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD INMASTER FOR LOW MARGIN FLAG + STOCK ORDER PRICE
    // ========================================================================

    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="InMaster"]}[Data],

    // Select fields from InMaster
    InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
        "PartNumber",
        "Franchise",
        "Branch",
        "LowMarginFlag",        // user_field_3 - ONLY in InMaster
        "StockOrderPrice"       // STK_ORDER_PRICE - In InMaster
    }),

    // ========================================================================
    // STEP 2: LOAD JDIS_PART_INFORMATION FOR PRICING & INVENTORY COST
    // ========================================================================

    Source_jdis = Source_InMaster,
    dbo_jdis = Source_jdis{[Schema="dbo",Item="jdis_Part_Information"]}[Data],

    // Select inventory and pricing fields from jdis
    jdis_Fields = Table.SelectColumns(dbo_jdis, {
        "PartNumber",
        "Franchise",
        "Branch",

        // Pricing fields (current/active pricing from jdis)
        "ListPrice",            // Manufacturer list price
        "SellPrice1",           // Current selling price

        // Inventory fields (from jdis)
        "QuantityOnHand",       // Current on-hand quantity (jdis name, not OnHandQty)
        "BulkBinQty",           // Bulk bin quantity (ONLY in jdis, not InMaster)
        "InventoryCost"         // Inventory cost (ONLY in jdis)
    }),

    // ========================================================================
    // STEP 3: MERGE JDIS + INMASTER ON PARTNUMBER
    // ========================================================================
    /*
    Left join: jdis (main) LEFT JOIN InMaster
    Why: All parts in jdis, add InMaster fields where they exist
    */

    MergeInMaster = Table.NestedJoin(
        jdis_Fields,
        {"PartNumber"},
        InMaster_Fields,
        {"PartNumber"},
        "InMasterData",
        JoinKind.LeftOuter
    ),

    // Expand InMaster fields
    ExpandInMaster = Table.ExpandTableColumn(
        MergeInMaster,
        "InMasterData",
        {"LowMarginFlag", "StockOrderPrice"},
        {"LowMarginFlag", "StockOrderPrice"}
    ),

    // ========================================================================
    // STEP 4: CLEAN AND TRANSFORM
    // ========================================================================

    CleanFields = Table.TransformColumns(ExpandInMaster, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Branch", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"LowMarginFlag", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ========================================================================
    // STEP 5: REMOVE BLANKS AND DEDUPLICATE
    // ========================================================================

    RemoveBlankParts = Table.SelectRows(CleanFields, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Deduplicate by PartNumber (for simple join to fact table)
    RemoveDuplicates = Table.Distinct(RemoveBlankParts, {"PartNumber"}),

    // ========================================================================
    // STEP 6: ADD CALCULATED COLUMNS
    // ========================================================================

    // Add IsLowMarginFlagged boolean
    AddIsLowMarginFlagged = Table.AddColumn(
        RemoveDuplicates,
        "IsLowMarginFlagged",
        each [LowMarginFlag] = "LOW",
        type logical
    ),

    // Add OnHandQty (QuantityOnHand + BulkBinQty for total SOH)
    // Note: Some parts may not have BulkBinQty from InMaster (nulls from LEFT JOIN)
    AddOnHandQty = Table.AddColumn(
        AddIsLowMarginFlagged,
        "OnHandQty",
        each ([QuantityOnHand] ?? 0) + ([BulkBinQty] ?? 0),
        type number
    ),

    // ========================================================================
    // STEP 7: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(AddOnHandQty, {
        {"PartNumber", type text},
        {"Franchise", type text},
        {"Branch", type text},
        {"LowMarginFlag", type text},
        {"IsLowMarginFlagged", type logical},
        {"ListPrice", type number},
        {"SellPrice1", type number},
        {"QuantityOnHand", type number},
        {"InventoryCost", type number},
        {"StockOrderPrice", type number},
        {"BulkBinQty", type number},
        {"OnHandQty", type number}
    })

in
    FinalDataTypes

/*
============================================================================
CORRECTED COLUMN MAPPING
============================================================================

**From InMaster:**
- LowMarginFlag (user_field_3) - ONLY in InMaster
- StockOrderPrice (STK_ORDER_PRICE) - For MDP calculations

**From jdis_Part_Information:**
- ListPrice - Manufacturer list price
- SellPrice1 - Current selling price
- QuantityOnHand - Current on-hand quantity
- BulkBinQty - Bulk bin quantity (ONLY in jdis, NOT in InMaster)
- InventoryCost - Per-unit inventory cost

**Calculated:**
- IsLowMarginFlagged (boolean from LowMarginFlag = "LOW")
- OnHandQty (QuantityOnHand + BulkBinQty = Total SOH)

============================================================================
FINAL COLUMNS IN TABLE:
============================================================================
1. PartNumber (text) - from jdis
2. Franchise (text) - from jdis
3. Branch (text) - from jdis
4. LowMarginFlag (text) - from InMaster
5. IsLowMarginFlagged (boolean) - calculated
6. ListPrice (number) - from jdis
7. SellPrice1 (number) - from jdis
8. QuantityOnHand (number) - from jdis
9. BulkBinQty (number) - from jdis (NOT InMaster!)
10. InventoryCost (number) - from jdis
11. StockOrderPrice (number) - from InMaster
12. OnHandQty (number) - calculated (QuantityOnHand + BulkBinQty)

============================================================================
USAGE IN DAX MEASURES:
============================================================================

Total SOH Qty = SUM(dim_Parts_LowMargin[OnHandQty])
    // Uses the calculated OnHandQty field

Inventory Cost = SUM(dim_Parts_LowMargin[InventoryCost])
    // From jdis

MDP Value = SUM(dim_Parts_LowMargin[StockOrderPrice]) * [Total SOH Qty]
    // StockOrderPrice from InMaster

% Difference = DIVIDE(
    ([MDP Value] - [Inventory Cost]),
    ([MDP Value] + [Inventory Cost]) / 2,
    0
)

============================================================================
*/
