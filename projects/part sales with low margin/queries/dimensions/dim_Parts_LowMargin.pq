/*
============================================================================
DIM_PARTS_LOWMARGIN - LOW MARGIN SUPPLEMENTAL DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Lightweight supplemental dimension for low margin analysis
Grain: One row per unique part number (from InMaster)
Refresh Strategy: Full refresh (fast - only InMaster fields)
Target Performance: <30 seconds
Source Dependencies: InMaster (Raw lakehouse table - 1M rows)

🎯 BUSINESS STRATEGY:
Instead of adding InMaster fields to dim_Parts (which slows it down),
create a SEPARATE dimension that reports can join to when needed.

Benefits:
✅ Keeps dim_Parts fast (1:21 preview, ~6 min refresh)
✅ This dimension is VERY fast (minimal transformations)
✅ Reports can LEFT JOIN when they need low margin fields
✅ Other reports that don't need low margin data aren't impacted

🔗 USAGE IN REPORTS:
Power BI will join:
- dim_Parts.PartNumber → Fact.PartNumber (main relationship)
- dim_Parts_LowMargin.PartNumber → Fact.PartNumber (inactive, for low margin)

Or use LOOKUPVALUE in DAX measures:
LowMarginFlag = LOOKUPVALUE(dim_Parts_LowMargin[LowMarginFlag],
                            dim_Parts_LowMargin[PartNumber], [PartNumber])

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD INMASTER SOURCE
    // ========================================================================

    Source = InMaster,

    // ========================================================================
    // STEP 2: SELECT ONLY LOW MARGIN CRITICAL FIELDS
    // ========================================================================
    /*
    PERFORMANCE: Minimal column selection = fast processing
    Only fields needed for low margin analysis
    */

    SelectColumns = Table.SelectColumns(Source, {
        "Branch",               // Part of composite key
        "PartNumber",           // Primary key
        "Franchise",            // Part of composite key
        "LowMarginFlag",        // ⭐ THE critical field
        "StockOrderPrice",      // ⭐ For original margin calculations
        "ListPrice",            // For margin analysis
        "SellPrice1"            // For margin analysis
    }),

    // ========================================================================
    // STEP 3: MINIMAL DATA CLEANING
    // ========================================================================
    /*
    PERFORMANCE: Only clean what's necessary
    No fancy Text.Proper or complex transformations
    */

    CleanFields = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"LowMarginFlag", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // ========================================================================
    // STEP 4: REMOVE BLANKS AND DEDUPLICATE
    // ========================================================================

    RemoveBlankParts = Table.SelectRows(CleanFields, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Deduplicate by PartNumber ONLY (for simpler join to fact table)
    // Note: If same PartNumber has different prices by Franchise, this will keep first occurrence
    RemoveDuplicates = Table.Distinct(RemoveBlankParts, {"PartNumber"}),

    // ========================================================================
    // STEP 5: ADD BUSINESS LOGIC COLUMNS
    // ========================================================================
    /*
    Simple boolean flag for easy filtering in reports
    */

    AddIsLowMarginFlagged = Table.AddColumn(
        RemoveDuplicates,
        "IsLowMarginFlagged",
        each [LowMarginFlag] = "LOW",
        type logical
    ),

    // ========================================================================
    // STEP 6: SORT AND ADD SURROGATE KEY
    // ========================================================================

    SortByPart = Table.Sort(AddIsLowMarginFlagged, {{"PartNumber", Order.Ascending}}),

    AddKey = Table.AddIndexColumn(SortByPart, "PartLowMarginKey", 1, 1, Int64.Type),

    // ========================================================================
    // STEP 7: REORDER COLUMNS
    // ========================================================================

    ReorderColumns = Table.ReorderColumns(AddKey, {
        "PartLowMarginKey",     // Surrogate key
        "PartNumber",           // Business key (for joins)
        "Franchise",            // Business key component
        "Branch",               // Context
        "LowMarginFlag",        // Raw field from InMaster
        "IsLowMarginFlagged",   // Boolean flag
        "StockOrderPrice",      // For original margin calc
        "ListPrice",            // For margin analysis
        "SellPrice1"            // For margin analysis
    }),

    // ========================================================================
    // STEP 8: SPECIAL "UNKNOWN" RECORD
    // ========================================================================

    UnknownRecord = #table(
        type table [
            PartLowMarginKey = Int64.Type,
            PartNumber = text,
            Franchise = text,
            Branch = text,
            LowMarginFlag = text,
            IsLowMarginFlagged = logical,
            StockOrderPrice = number,
            ListPrice = number,
            SellPrice1 = number
        ],
        {
            {-1, "UNKNOWN", "UNKNOWN", "UNKNOWN", "", false, 0, 0, 0}
        }
    ),

    // ========================================================================
    // STEP 9: COMBINE AND FINAL SORT
    // ========================================================================

    Combined = Table.Combine({UnknownRecord, ReorderColumns}),

    FinalSort = Table.Sort(Combined, {{"PartLowMarginKey", Order.Ascending}})

in
    FinalSort

/*
============================================================================
✅ PERFORMANCE CHARACTERISTICS
============================================================================

Expected Refresh Time: <1 minute (likely 30-45 seconds)
Expected Row Count: ~1M rows (same as InMaster)
Expected CU Usage: Very low (minimal transformations)

Why this is fast:
- No complex joins (single source table)
- Minimal text transformations (only 3 fields)
- No Text.Proper (expensive operation)
- Simple deduplication
- Lightweight calculated columns (just 1 boolean)

============================================================================
📊 HOW TO USE IN REPORTS
============================================================================

**Option 1: Inactive Relationship (Recommended)**

In Power BI model:
1. Keep active relationship: dim_Parts → Fact
2. Add inactive relationship: dim_Parts_LowMargin → Fact (on PartNumber)
3. Use USERELATIONSHIP in measures when you need low margin fields

Example DAX:
```dax
LowMarginParts Count =
CALCULATE(
    COUNTROWS(Fact),
    USERELATIONSHIP(Fact[PartNumber], dim_Parts_LowMargin[PartNumber]),
    dim_Parts_LowMargin[IsLowMarginFlagged] = TRUE
)
```

**Option 2: LOOKUPVALUE (Simple approach)**

No relationship needed, just lookup values in measures:

```dax
StockOrderPrice =
LOOKUPVALUE(
    dim_Parts_LowMargin[StockOrderPrice],
    dim_Parts_LowMargin[PartNumber], [PartNumber]
)

IsLowMargin =
VAR LowMarginFlag =
    LOOKUPVALUE(
        dim_Parts_LowMargin[LowMarginFlag],
        dim_Parts_LowMargin[PartNumber], [PartNumber]
    )
RETURN
    LowMarginFlag = "LOW"
```

**Option 3: Merge in Fact Table (Most efficient for low margin report)**

Since the low margin report will ALWAYS need these fields,
consider enriching the fact table during its build:

In Fact_Part_Sales_Txns.pq:
```powerquery
// JOIN to dim_Parts_LowMargin during fact table build
EnrichWithLowMargin = Table.NestedJoin(
    FactSource,
    {"PartNumber"},
    dim_Parts_LowMargin,
    {"PartNumber"},
    "LowMarginData",
    JoinKind.LeftOuter
),

ExpandLowMargin = Table.ExpandTableColumn(
    EnrichWithLowMargin,
    "LowMarginData",
    {"LowMarginFlag", "StockOrderPrice"},
    {"LowMarginFlag", "StockOrderPrice"}
)
```

This way the fact table has the low margin fields directly,
and you don't need any special relationships or lookups.

============================================================================
🎯 RECOMMENDED APPROACH
============================================================================

For the Low Margin Report specifically, I recommend **Option 3**:
- Add LowMarginFlag and StockOrderPrice directly to Fact_Part_Sales_Txns
- No extra dimension needed in the report
- Fastest query performance
- Simplest DAX measures

For other reports that occasionally need low margin data:
- Keep dim_Parts clean (no InMaster fields)
- Use this dim_Parts_LowMargin dimension with LOOKUPVALUE
- Only pay the join cost when you actually need the data

============================================================================
*/
