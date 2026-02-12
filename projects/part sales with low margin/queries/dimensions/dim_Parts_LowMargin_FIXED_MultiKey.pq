/*
============================================================================
DIM_PARTS_LOWMARGIN - FIXED: Join on PartNumber + Branch + Franchise
============================================================================
CRITICAL FIX: Join InMaster on PartNumber + Branch + Franchise (not just PartNumber)

ISSUE: Old report joined on Part No + Branch
       New report was joining only on PartNumber
       This caused wrong StockOrderPrice and LowMarginFlag values per branch

SOLUTION: Match the old report's join logic exactly
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
    // STEP 3: MERGE JDIS + INMASTER ON PARTNUMBER + BRANCH + FRANCHISE
    // ========================================================================
    /*
    CRITICAL FIX: Join on PartNumber + Branch + Franchise
    This matches the old report's SQL:
      ON jdis."Part No" = InMaster.PART_NO
      AND jdis.Branch = InMaster.Branch

    Why: StockOrderPrice and LowMarginFlag are branch-specific!
    */

    MergeInMaster = Table.NestedJoin(
        jdis_Fields,
        {"PartNumber", "Branch", "Franchise"},  // ← Multi-column join key
        InMaster_Fields,
        {"PartNumber", "Branch", "Franchise"},  // ← Multi-column join key
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

    // CRITICAL: Deduplicate by PartNumber + Branch + Franchise (not just PartNumber!)
    // Each part can have different StockOrderPrice/LowMarginFlag per branch
    RemoveDuplicates = Table.Distinct(RemoveBlankParts, {"PartNumber", "Branch", "Franchise"}),

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
CRITICAL CHANGE SUMMARY
============================================================================

OLD (WRONG):
- Join on: {"PartNumber"}
- Deduplicate on: {"PartNumber"}
- Result: One row per PartNumber across all branches
- Problem: StockOrderPrice/LowMarginFlag from arbitrary branch

NEW (CORRECT):
- Join on: {"PartNumber", "Branch", "Franchise"}
- Deduplicate on: {"PartNumber", "Branch", "Franchise"}
- Result: One row per PartNumber per Branch per Franchise
- Matches: Old report SQL logic exactly

============================================================================
IMPACT
============================================================================

This fix will:
1. Increase row count in dim_Parts_LowMargin (same part in multiple branches)
2. Give correct branch-specific StockOrderPrice
3. Give correct branch-specific LowMarginFlag
4. Match old report's data structure

Expected result for Branch 1 filter:
- More parts flagged as "LOW" (~70+ instead of 11)
- Different MDP Values (branch-specific StockOrderPrice)
- Totals matching old report ($1.43M / $10.48K / $1.42M)

============================================================================
VALIDATION AFTER FIX
============================================================================

Check specific part in both reports:
- AH226238 in Branch 1:
  - StockOrderPrice should be $505.68 (from old report screenshot)
  - Verify it matches in new report after fix

Total row count in dim_Parts_LowMargin:
- Before: ~X rows (one per unique PartNumber)
- After: ~Y rows (one per PartNumber + Branch + Franchise combination)
- Should match old report's table structure

============================================================================
*/
