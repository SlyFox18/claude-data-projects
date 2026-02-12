/*
============================================================================
DIM_PARTS_LOWMARGIN - AGGREGATED: Handle Duplicates + Keep Branch Specificity
============================================================================
SOLUTION: Aggregate by PartNumber + Branch + Franchise, then keep all rows
         This preserves branch-specific data while handling any duplicates

IMPORTANT: This table will have multiple rows for same PartNumber
          (one per branch/franchise combination)
          Use Branch/Franchise filters in visuals to get correct data
============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD INMASTER FOR LOW MARGIN FLAG + STOCK ORDER PRICE
    // ========================================================================

    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="InMaster"]}[Data],

    InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
        "PartNumber", "Franchise", "Branch", "LowMarginFlag", "StockOrderPrice"
    }),

    // ========================================================================
    // STEP 2: LOAD JDIS_PART_INFORMATION FOR PRICING & INVENTORY COST
    // ========================================================================

    Source_jdis = Source_InMaster,
    dbo_jdis = Source_jdis{[Schema="dbo",Item="jdis_Part_Information"]}[Data],

    jdis_Fields = Table.SelectColumns(dbo_jdis, {
        "PartNumber", "Franchise", "Branch",
        "ListPrice", "SellPrice1", "QuantityOnHand", "BulkBinQty", "InventoryCost"
    }),

    // ========================================================================
    // STEP 3: AGGREGATE JDIS DATA BY PARTNUMBER + BRANCH + FRANCHISE
    // ========================================================================
    /*
    CRITICAL: If same PartNumber + Branch + Franchise appears multiple times,
    aggregate the numeric values to get single row per combination
    */

    AggregateJdis = Table.Group(
        jdis_Fields,
        {"PartNumber", "Branch", "Franchise"},
        {
            {"ListPrice", each List.Max([ListPrice]), type number},
            {"SellPrice1", each List.Max([SellPrice1]), type number},
            {"QuantityOnHand", each List.Sum([QuantityOnHand]), type number},
            {"BulkBinQty", each List.Sum([BulkBinQty]), type number},
            {"InventoryCost", each List.Sum([InventoryCost]), type number}
        }
    ),

    // ========================================================================
    // STEP 4: MERGE WITH INMASTER ON PARTNUMBER + BRANCH + FRANCHISE
    // ========================================================================

    MergeInMaster = Table.NestedJoin(
        AggregateJdis,
        {"PartNumber", "Branch", "Franchise"},
        InMaster_Fields,
        {"PartNumber", "Branch", "Franchise"},
        "InMasterData",
        JoinKind.LeftOuter
    ),

    ExpandInMaster = Table.ExpandTableColumn(
        MergeInMaster,
        "InMasterData",
        {"LowMarginFlag", "StockOrderPrice"},
        {"LowMarginFlag", "StockOrderPrice"}
    ),

    // ========================================================================
    // STEP 5: CLEAN AND TRANSFORM
    // ========================================================================

    CleanFields = Table.TransformColumns(ExpandInMaster, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Branch", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"LowMarginFlag", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ========================================================================
    // STEP 6: REMOVE BLANKS (NO DEDUPLICATION NEEDED - ALREADY AGGREGATED)
    // ========================================================================

    RemoveBlankParts = Table.SelectRows(CleanFields, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // ========================================================================
    // STEP 7: ADD CALCULATED COLUMNS
    // ========================================================================

    AddIsLowMarginFlagged = Table.AddColumn(
        RemoveBlankParts,
        "IsLowMarginFlagged",
        each [LowMarginFlag] = "LOW",
        type logical
    ),

    AddOnHandQty = Table.AddColumn(
        AddIsLowMarginFlagged,
        "OnHandQty",
        each ([QuantityOnHand] ?? 0) + ([BulkBinQty] ?? 0),
        type number
    ),

    // ========================================================================
    // STEP 8: ADD COMPOSITE KEY FOR RELATIONSHIPS
    // ========================================================================
    /*
    Create a text key combining PartNumber + Branch + Franchise
    This allows proper filtering while maintaining relationships
    */

    AddCompositeKey = Table.AddColumn(
        AddOnHandQty,
        "PartBranchKey",
        each [PartNumber] & "|" & [Branch] & "|" & [Franchise],
        type text
    ),

    // ========================================================================
    // STEP 9: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(AddCompositeKey, {
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
        {"OnHandQty", type number},
        {"PartBranchKey", type text}
    })

in
    FinalDataTypes

/*
============================================================================
CRITICAL CHANGES
============================================================================

1. AGGREGATION (New Step 3):
   - Groups by PartNumber + Branch + Franchise
   - Sums quantities (QuantityOnHand, BulkBinQty, InventoryCost)
   - Takes Max of prices (ListPrice, SellPrice1)
   - Handles any duplicates in source data

2. NO FINAL DEDUPLICATION:
   - Already aggregated, so PartNumber + Branch + Franchise is unique
   - Multiple rows for same PartNumber (different branches) is CORRECT

3. COMPOSITE KEY (New Step 8):
   - PartBranchKey = PartNumber|Branch|Franchise
   - Can be used for unique relationships if needed
   - Not required for this use case (no relationships to this table)

============================================================================
USAGE IN POWER BI
============================================================================

**DO NOT** create relationship from Fact_InTrans to this table!

This table is used STANDALONE for Page 2 (Inventory Cost Discrepancy):
- Table visual uses dim_Parts_LowMargin directly (no relationship needed)
- Filters applied: Branch, Franchise, Margin % range
- Measures reference dim_Parts_LowMargin directly

**Why no relationship:**
- This table has PartNumber repeated across branches
- Fact_InTrans already has relationship to dim_Parts (main parts dimension)
- Page 2 doesn't need transaction data - just current inventory snapshot

============================================================================
VALIDATION
============================================================================

After loading:
1. Check row count - should be ~X rows (one per PartNumber + Branch + Franchise)
2. Filter to Branch = "1"
3. Count rows where LowMarginFlag = "LOW" - should be ~70+
4. Check specific part (AN260236) - should have ONE row per branch
5. Verify KPI totals match old report when Branch "1" selected

============================================================================
*/
