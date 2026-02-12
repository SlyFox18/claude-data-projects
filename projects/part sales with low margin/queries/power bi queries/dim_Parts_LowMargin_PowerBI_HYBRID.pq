/*
============================================================================
DIM_PARTS_LOWMARGIN - HYBRID (InMaster + jdis_Part_Information)
============================================================================
Purpose: Low margin dimension combining:
  - InMaster: user_field_3 (LOW flag) - NOT in jdis
  - jdis_Part_Information: Inventory Cost, pricing - CURRENT data

Source: Both InMaster AND jdis_Part_Information from Lakehouse
Usage: RELATED() function in calculated columns + inventory analysis
============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD INMASTER FOR LOW MARGIN FLAG
    // ========================================================================

    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="InMaster"]}[Data],

    // Select only the LOW flag field from InMaster
    InMaster_LowFlag = Table.SelectColumns(dbo_InMaster, {
        "PartNumber",
        "Franchise",
        "Branch",
        "LowMarginFlag"     // user_field_3 - ONLY exists in InMaster
    }),

    // ========================================================================
    // STEP 2: LOAD JDIS_PART_INFORMATION FOR PRICING & INVENTORY
    // ========================================================================

    Source_jdis = Source_InMaster,
    dbo_jdis = Source_jdis{[Schema="dbo",Item="jdis_Part_Information"]}[Data],

    // Select inventory and pricing fields from jdis
    jdis_Inventory = Table.SelectColumns(dbo_jdis, {
        "PartNumber",
        "Franchise",
        "Branch",

        // Pricing fields (current/active pricing)
        "StockOrderPrice",
        "ListPrice",
        "SellPrice1",

        // Inventory fields
        "OnHandQty",
        "BulkBinQty",
        "InventoryCost"     // THIS is the key field from jdis, not InMaster
    }),

    // ========================================================================
    // STEP 3: MERGE INMASTER + JDIS ON PARTNUMBER
    // ========================================================================
    /*
    Left join: jdis (main) LEFT JOIN InMaster (for LOW flag)
    Why: All parts in jdis, add LOW flag where it exists in InMaster
    */

    MergeInMasterFlag = Table.NestedJoin(
        jdis_Inventory,
        {"PartNumber"},
        InMaster_LowFlag,
        {"PartNumber"},
        "InMasterData",
        JoinKind.LeftOuter
    ),

    // Expand only the LowMarginFlag from InMaster
    ExpandLowFlag = Table.ExpandTableColumn(
        MergeInMasterFlag,
        "InMasterData",
        {"LowMarginFlag"},
        {"LowMarginFlag"}
    ),

    // ========================================================================
    // STEP 4: CLEAN AND TRANSFORM
    // ========================================================================

    CleanFields = Table.TransformColumns(ExpandLowFlag, {
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
    // STEP 6: ADD BOOLEAN FLAG
    // ========================================================================

    AddIsLowMarginFlagged = Table.AddColumn(
        RemoveDuplicates,
        "IsLowMarginFlagged",
        each [LowMarginFlag] = "LOW",
        type logical
    ),

    // ========================================================================
    // STEP 7: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(AddIsLowMarginFlagged, {
        {"PartNumber", type text},
        {"Franchise", type text},
        {"Branch", type text},
        {"LowMarginFlag", type text},
        {"IsLowMarginFlagged", type logical},
        {"StockOrderPrice", type number},
        {"ListPrice", type number},
        {"SellPrice1", type number},
        {"BulkBinQty", type number},
        {"OnHandQty", type number},
        {"InventoryCost", type number}
    })

in
    FinalDataTypes

/*
============================================================================
WHY THIS HYBRID APPROACH?
============================================================================

**Problem**:
- LowMarginFlag (user_field_3) ONLY exists in InMaster
- InventoryCost, current pricing exist in jdis_Part_Information
- InMaster has ON_HAND_VAL but not InventoryCost as a per-unit cost

**Solution**:
- Load jdis for current pricing & inventory cost (main source)
- LEFT JOIN InMaster to add LowMarginFlag where it exists
- Result: Best of both tables

**Columns in final table:**
- PartNumber, Franchise, Branch (keys)
- LowMarginFlag, IsLowMarginFlagged (from InMaster)
- StockOrderPrice, ListPrice, SellPrice1 (from jdis - CURRENT prices)
- OnHandQty, BulkBinQty, InventoryCost (from jdis - CURRENT inventory)

============================================================================
USAGE IN POWER BI MODEL:
============================================================================

1. Create relationship (inactive):
   Fact_InTrans[PartNumber] → dim_Parts_LowMargin[PartNumber]

2. Add calculated columns to Fact_InTrans:
   LowMarginFlag = RELATED(dim_Parts_LowMargin[LowMarginFlag])
   StockOrderPrice = RELATED(dim_Parts_LowMargin[StockOrderPrice])
   ListPriceManuf = RELATED(dim_Parts_LowMargin[ListPrice])

3. Create measures for inventory analysis (Pages 2 & 3):
   Total SOH Qty = SUM(dim_Parts_LowMargin[BulkBinQty]) + SUM(dim_Parts_LowMargin[OnHandQty])
   Inventory Cost = SUM(dim_Parts_LowMargin[InventoryCost])

Expected Refresh Time: <30 seconds (two small table loads + simple join)
Expected Row Count: ~same as jdis_Part_Information active parts
============================================================================
*/
