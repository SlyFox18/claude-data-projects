/*
============================================================================
DIM_PARTS_LOWMARGIN - FINAL: With Cost Field from jdis_Part_Information
============================================================================
CRITICAL FIX: Add Cost field (pi_Cost) from jdis_Part_Information

This matches the old report SQL which uses BOTH fields:
- Cost (pi_Cost from jdis_Part_Information) - Used for MDP calculations
- StockOrderPrice (STK_ORDER_PRICE from InMaster) - Kept for reference

Old report measures:
  Cost Value = [Cost] * [Total SOH Qty]
  Desired Margin $ = [Sell Value] - [Cost Value]

CHANGES FROM PREVIOUS VERSION:
1. Added "Cost" to jdis_Fields selection (Step 2, Line 36)
2. Added "Cost" to AggregateJdis grouping (Step 3, Line 52)
3. Added "Cost" to FinalDataTypes (Step 9, Line 143)
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
            {"Cost", each List.Max([Cost]), type number},  // ← CRITICAL: Aggregate Cost field
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
        {"Cost", type number},  // ← CRITICAL: Cost field data type
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
CRITICAL CHANGES FROM PREVIOUS VERSION
============================================================================

ADDED: Cost field in THREE places:

1. STEP 2 (Line 36): Added "Cost" to jdis_Fields column selection
   jdis_Fields = Table.SelectColumns(dbo_jdis, {
       ...
       "Cost",  // ← NEW
       ...
   })

2. STEP 3 (Line 52): Added "Cost" to aggregation grouping
   AggregateJdis = Table.Group(
       jdis_Fields,
       {"PartNumber", "Branch", "Franchise"},
       {
           ...
           {"Cost", each List.Max([Cost]), type number},  // ← NEW
           ...
       }
   )

3. STEP 9 (Line 143): Added "Cost" to data types
   FinalDataTypes = Table.TransformColumnTypes(AddCompositeKey, {
       ...
       {"Cost", type number},  // ← NEW
       ...
   })

============================================================================
FIELD MAPPING TO OLD REPORT
============================================================================

| Old Report Field | Old SQL Source | New Field | New Source |
|------------------|----------------|-----------|------------|
| Cost | jdis.pi_Cost | Cost | dim_Parts_LowMargin[Cost] |
| Cost Value | Cost * SOH Qty | [Cost Value] | [Cost] * [Total SOH Qty] |
| List Price | pi_List_Price_Master_File | ListPrice | dim_Parts_LowMargin[ListPrice] |
| Sell Price | pi_Sell_Price_1_Master_File | SellPrice1 | dim_Parts_LowMargin[SellPrice1] |
| Inventory Cost | pi_Inventory_Cost | InventoryCost | dim_Parts_LowMargin[InventoryCost] |
| MDP (STK_ORDER_PRICE) | InMaster.STK_ORDER_PRICE | StockOrderPrice | dim_Parts_LowMargin[StockOrderPrice] |

============================================================================
MEASURES TO CREATE/UPDATE AFTER LOADING THIS QUERY
============================================================================

CREATE NEW MEASURES:
```dax
Cost = SUM(dim_Parts_LowMargin[Cost])

Cost Value = [Cost] * [Total SOH Qty]

List Price = SUM(dim_Parts_LowMargin[ListPrice])

New Sell Price =
    DIVIDE(
        ABS([Margin $ Discrepancy]),
        [Total SOH Qty],
        0
    ) + [List Price]
```

UPDATE EXISTING MEASURES:
```dax
// Option 1: Update MDP Value to reference Cost Value
MDP Value = [Cost Value]

// Option 2: Replace all [MDP Value] references with [Cost Value] and delete MDP Value

Desired Margin $ = [Sell Value] - [Cost Value]

Desired Margin % = DIVIDE([Desired Margin $], [Sell Value], 0)

Part Description =
    VAR CurrentPartNumber = SELECTEDVALUE(dim_Parts_LowMargin[PartNumber])
    VAR FromDimParts =
        LOOKUPVALUE(
            dim_Parts[Description],
            dim_Parts[PartNumber], CurrentPartNumber
        )
    RETURN
    IF(FromDimParts <> BLANK(), FromDimParts, "")
```

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
VALIDATION AFTER LOADING
============================================================================

After loading this query and updating measures:

1. **Check Cost field exists**: Verify Cost column appears in Fields pane

2. **Check specific part** (AH226238 in Branch 1):
   - Cost: Should have a value (not blank)
   - Cost Value: Should match old report "Cost Value" calculation
   - Desired Margin $: Should be $388.97 (from old report)
   - Actual Margin $ (INV): Should be $275.13
   - Margin $ Discrepancy: Should be -$113.84

3. **Check KPI Cards** (Branch 1, Franchise <> 'S'):
   - Positive Margin $ Discrepancy: Should be ~$1.43M
   - Negative Margin $ Discrepancy: Should be ~($10.48K)
   - Net Margin $ Discrepancy: Should be ~$1.42M

4. **Check table row count**:
   - Filter to Branch = "1", Franchise <> "S"
   - Should show ~70+ parts with LowMarginFlag = "LOW"

5. **Verify Part Description** works with LOOKUPVALUE measure

If all validations pass, the new report matches the old report exactly!

============================================================================
*/
