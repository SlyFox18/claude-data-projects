/*
============================================================================
FACT_PARTSADJUSTMENTS - UNIFIED PARTS ADJUSTMENTS FACT TABLE
============================================================================

📋 PERFORMANCE OPTIMIZED:
- GlTrans deduplicated to ONE row per DocRef before join
- Clean one-to-many join (InTrans many → GlTrans one)
- Fast refresh performance

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD FILTERED SOURCE TABLES
    // ========================================================================
    
    InTrans = InTrans_Filtered,
    GlTrans = GlTrans_Filtered,  // Now deduplicated - one row per DocRef
    
    // ========================================================================
    // STEP 2: FAST JOIN ON RONumber = DocRef (NOW ONE-TO-MANY)
    // ========================================================================
    
    MergedTables = Table.NestedJoin(
        InTrans,
        {"RONumber"},
        GlTrans,
        {"DocRef"},
        "GlTrans",
        JoinKind.LeftOuter
    ),
    
    // ========================================================================
    // STEP 3: EXPAND GLTRANS COLUMNS
    // ========================================================================
    
    ExpandedGlTrans = Table.ExpandTableColumn(
        MergedTables,
        "GlTrans",
        {"SubAccount", "GLTransDate"},
        {"SubAccount", "GLTransDate"}
    ),
    
    // ========================================================================
    // STEP 4: ADD PA TYPE CLASSIFICATION
    // ========================================================================
    
    AddedPAType = Table.AddColumn(
        ExpandedGlTrans,
        "PAType",
        each if [SubAccount] = null then "Unknown"
             else if [SubAccount] = 1 then "Stock Check"
             else if [SubAccount] = 2 then "Customer BIN"
             else if [SubAccount] = 3 then "Damaged"
             else if [SubAccount] = 4 then "Lost"
             else if [SubAccount] = 5 then "Overage"
             else if [SubAccount] = 6 then "Count Off"
             else "Unknown",
        type text
    ),
    
    // ========================================================================
    // STEP 5: ADD POSITIVE/NEGATIVE SPLITS
    // ========================================================================
    
    AddedPositiveQty = Table.AddColumn(AddedPAType, "PositiveQty", each if [Qty] > 0 then [Qty] else 0, type number),
    AddedNegativeQty = Table.AddColumn(AddedPositiveQty, "NegativeQty", each if [Qty] < 0 then [Qty] else 0, type number),
    AddedPositiveCost = Table.AddColumn(AddedNegativeQty, "PositiveCost", each if [CostValue] > 0 then [CostValue] else 0, type number),
    AddedNegativeCost = Table.AddColumn(AddedPositiveCost, "NegativeCost", each if [CostValue] < 0 then [CostValue] else 0, type number),
    
    // ========================================================================
    // STEP 6: ADD FLAGS
    // ========================================================================
    
    AddedIsPositiveQty = Table.AddColumn(AddedNegativeCost, "IsPositiveQty", each [Qty] > 0, type logical),
    AddedIsNegativeQty = Table.AddColumn(AddedIsPositiveQty, "IsNegativeQty", each [Qty] < 0, type logical),
    
    // ========================================================================
    // STEP 7: ADD ABSOLUTE VALUES
    // ========================================================================
    
    AddedAbsQty = Table.AddColumn(AddedIsNegativeQty, "AbsQty", each Number.Abs([Qty]), type number),
    AddedAbsCost = Table.AddColumn(AddedAbsQty, "AbsCost", each Number.Abs([CostValue]), type number),
    
    // ========================================================================
    // STEP 8: ADD METADATA
    // ========================================================================
    
    AddedLoadedDatetime = Table.AddColumn(AddedAbsCost, "LoadedDatetime", each DateTime.LocalNow(), type datetime),
    
    // ========================================================================
    // STEP 9: FINAL TYPES
    // ========================================================================
    
    TypedColumns = Table.TransformColumnTypes(
        AddedLoadedDatetime,
        {
            {"TransId", Int64.Type},
            {"RONumber", type text},
            {"TransDatetime", type datetime},
            {"Branch", type text},
            {"PartNumber", type text},
            {"PartDescription", type text},
            {"Franchise", type text},
            {"Type", type text},
            {"Qty", type number},
            {"CostValue", type number},
            {"SellPrice1", type number},
            {"Salesman", type text},
            {"CustomerNo", type text},
            {"Comments", type text},
            {"ModifiedDate", type datetime},
            {"SubAccount", Int64.Type},
            {"GLTransDate", type datetime},
            {"PAType", type text},
            {"PositiveQty", type number},
            {"NegativeQty", type number},
            {"PositiveCost", type number},
            {"NegativeCost", type number},
            {"IsPositiveQty", type logical},
            {"IsNegativeQty", type logical},
            {"AbsQty", type number},
            {"AbsCost", type number},
            {"LoadedDatetime", type datetime}
        }
    )

in
    TypedColumns

/*
============================================================================
✅ PERFORMANCE OPTIMIZED - ONE-TO-MANY JOIN
============================================================================

🚀 KEY OPTIMIZATION:
- GlTrans deduplicated BEFORE join (206K rows → ~2K unique DocRefs)
- Clean one-to-many relationship (no cartesian product)
- Expected refresh time: 2-5 minutes for 527K InTrans rows

============================================================================
*/