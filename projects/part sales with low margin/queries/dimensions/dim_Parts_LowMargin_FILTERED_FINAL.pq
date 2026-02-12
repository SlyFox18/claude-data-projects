/*
============================================================================
DIM_PARTS_LOWMARGIN - FILTERED: Remove Empty Franchise Combinations
============================================================================
CRITICAL FIX: Filter out rows where OnHandQty = 0 AND LowMarginFlag <> "LOW"

ISSUE DISCOVERED: The aggregated query creates rows for ALL PartNumber + Branch
+ Franchise combinations, including many where the franchise has no inventory.

This caused:
- Old Report: 155K rows total, 4,931 rows for Branch 3
- New Report: 1.08M rows total, 33,816 rows for Branch 3 (7x more!)

The extra rows have $0 margin discrepancies, so KPI totals are similar but
row counts are inflated.

SOLUTION: After aggregation, filter to only include rows where:
- OnHandQty > 0 (has inventory), OR
- LowMarginFlag = "LOW" (flagged for review even if no inventory)

This matches the old report's behavior of only showing meaningful data.
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
        "ListPrice",            // Manufacturer list price (pi_List_Price_Master_File)
        "SellPrice1",           // Current selling price (pi_Sell_Price_1_Master_File)
        "Cost",                 // ← CRITICAL: pi_Cost - Used for MDP Value calculations
        "QuantityOnHand",       // Current on-hand quantity
        "BulkBinQty",           // Bulk bin quantity
        "InventoryCost"         // Inventory cost (pi_Inventory_Cost)
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
            {"Cost", each List.Max([Cost]), type number},
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
    // STEP 8: FILTER TO MEANINGFUL ROWS ONLY
    // ========================================================================
    /*
    CRITICAL NEW STEP: Remove rows where OnHandQty = 0 AND not flagged LOW

    This eliminates franchise combinations that have no inventory and aren't
    flagged for review, matching the old report's behavior.

    Keep rows where:
    - OnHandQty > 0 (has inventory to analyze), OR
    - LowMarginFlag = "LOW" (flagged even if no current inventory)
    */

    FilterMeaningfulRows = Table.SelectRows(AddOnHandQty, each
        [OnHandQty] > 0 or [LowMarginFlag] = "LOW"
    ),

    // ========================================================================
    // STEP 9: ADD COMPOSITE KEY FOR RELATIONSHIPS
    // ========================================================================
    /*
    Create a text key combining PartNumber + Branch + Franchise
    This allows proper filtering while maintaining relationships
    */

    AddCompositeKey = Table.AddColumn(
        FilterMeaningfulRows,
        "PartBranchKey",
        each [PartNumber] & "|" & [Branch] & "|" & [Franchise],
        type text
    ),

    // ========================================================================
    // STEP 10: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(AddCompositeKey, {
        {"PartNumber", type text},
        {"Franchise", type text},
        {"Branch", type text},
        {"LowMarginFlag", type text},
        {"IsLowMarginFlagged", type logical},
        {"ListPrice", type number},
        {"SellPrice1", type number},
        {"Cost", type number},
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
CRITICAL CHANGE FROM PREVIOUS VERSION
============================================================================

ADDED STEP 8: FilterMeaningfulRows

This filters out rows where:
- OnHandQty = 0 (no inventory)
- AND LowMarginFlag <> "LOW" (not flagged for review)

This eliminates the inflated row counts caused by franchise combinations
that have no meaningful data to analyze.

IMPACT:
- Old behavior: 1.08M rows total, 33,816 for Branch 3
- New behavior: ~155K rows total, ~4,931 for Branch 3 (matches old report)

============================================================================
ROW COUNT COMPARISON
============================================================================

WITHOUT FILTER (Previous Version):
- Total Rows: 1,081,386
- Branch 3: 33,816 rows
- Problem: Most rows have OnHandQty = 0 and contribute nothing to analysis

WITH FILTER (This Version):
- Total Rows: ~155,000 (expected)
- Branch 3: ~4,931 rows (expected)
- Solution: Only rows with inventory or LOW flag are included

============================================================================
WHY THIS HAPPENS
============================================================================

The jdis_Part_Information table has entries for parts in different franchises
even when QuantityOnHand = 0. When we aggregate by PartNumber + Branch +
Franchise, we create rows for all these combinations.

The old report's SQL implicitly filtered these out through WHERE clauses or
JOIN conditions that excluded zero-inventory, non-flagged rows.

Our new dimension needs explicit filtering to match this behavior.

============================================================================
VALIDATION AFTER LOADING
============================================================================

After loading this query:

1. **Check Total Row Count** (no filters):
   - Should be ~155K rows (not 1.08M)
   - Close to old report's total

2. **Check Branch 3 Row Count**:
   - Filter to Branch = "3"
   - Should show ~4,931 rows
   - Should match old report exactly

3. **Check KPI Cards** (Branch 3):
   - Should still show ~$39K positive, ~($3K) negative
   - Row count should now match old report

4. **Check All Branches** (no filter):
   - Positive: Should be closer to $5.31M (old report)
   - Negative: Should be closer to ($138K) (old report)
   - Net: Should be closer to $5.17M (old report)

If row counts now match and KPI totals are still similar, then we know:
- New report structure is correct
- The filtering is working properly
- Any remaining differences are due to Cost vs StockOrderPrice field

============================================================================
NEXT STEP: ADD COST FIELD
============================================================================

This query already includes the Cost field. After loading and validating
row counts match, proceed with updating measures as documented in:
- FIXES-Page2-Measure-Corrections.md
- IMPLEMENTATION-GUIDE-Cost-Field-Fix.md

Expected final result:
- Row counts match old report
- KPI totals match old report
- Individual row values match old report

============================================================================
*/
