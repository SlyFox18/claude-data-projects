/*
============================================================================
FACT_INTRANS_ALLPROMO - ALL PARTS TRANSACTIONS FOR PROMO CONTEXT
============================================================================

📋 TABLE OVERVIEW:
Purpose: Provide context for promotional analysis - all parts transactions (not just promos)
Grain: One row per transaction (Branch+REF_NO+PART_NO+Trans_Datetime)
Refresh Strategy: Full refresh from Lakehouse (source is already incremental)
Performance: Target <3 min refresh (larger dataset than Fact_PartsPromo)
Source Dependencies: InTrans_Incremental (Lakehouse table)

⚠️ DEDUPLICATION:
The InTrans_Incremental table may contain duplicate rows due to watermark
strategy issues (introduced ~December 2024). This query includes a GROUP BY
step to deduplicate by (Branch, REF_NO, PART_NO, TransDatetime) before
loading. This prevents duplicates from inflating SaleValue and CostValue totals.

🎯 BUSINESS USE CASES:
• Total Sales Context: Show total parts sales to compare against promotional sales
• REF_NO Linkage: Connect promo discounts to their parent repair orders
• % of Total Calculations: Promo sales as percentage of total sales
• Branch Comparison: Total sales vs promo sales by branch

📊 DATA STRUCTURE:

**Business Keys:**
• Branch → BranchKey
• REF_NO
• PART_NO
• TransDatetime

**Dimension Keys:**
• BranchKey: Links to dim_BranchLocation
• DateKey: Links to dim_DateTable

**Transaction Details:**
• CustomerNo
• Franchise
• Type
• Description
• (Qty excluded - contains non-numeric text values like "4B")

**Financial Metrics:**
• SaleValue
• CostValue

🔧 DESIGN APPROACH:

**Relationship to Fact_PartsPromo:**
• Many-to-Many on REF_NO (both tables have multiple rows per REF_NO)
• This allows comparing promo transactions to total order context

**Filter Strategy:**
• Date range: 2023-01-01 onwards (matches old InTrans_All_Promo)
• No franchise filter (include all for total context)
• No part number filter (include all parts)

🔄 REFRESH CHARACTERISTICS:
Estimated Row Count: ~1-2M rows (subset of 10M InTrans by date)
Target Refresh Time: <3 minutes
Refresh Schedule: Daily (after InTrans_Incremental refreshes)
Last Modified: [Current Date]
Created: 01/16/2026

🔗 RELATIONSHIPS:
• BranchKey → dim_BranchLocation[BranchID]
• DateKey → dim_DateTable[DateKey]
• REF_NO ↔ Fact_PartsPromo[REF_NO] (Many-to-Many)

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION
    // ========================================================================
    StartDate = #datetime(2023, 1, 1, 0, 0, 0),  // Matches old InTrans_All_Promo start date (datetime for comparison)

    // ========================================================================
    // SOURCE: Lakehouse InTrans_Incremental
    // ========================================================================

    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 1: FILTER BY DATE RANGE
    // ========================================================================
    /*
    PURPOSE: Get transactions from 2023 onwards
    NOTE: No franchise or part number filter - we want ALL transactions for context
    */

    FilterByDate = Table.SelectRows(InTrans, each
        [TransDatetime] >= StartDate
    ),

    // ========================================================================
    // STEP 2: SELECT AND RENAME COLUMNS
    // ========================================================================

    // NOTE: Qty column EXCLUDED - it contains non-numeric values like "4B" that cause
    // Lakehouse write failures. If Qty is needed, it must be cleaned at source or
    // handled via a separate query that converts text to number.
    SelectColumns = Table.SelectColumns(FilterByDate, {
        "Branch",
        "Franchise",
        "CustomerNo",
        "PartNumber",
        "TransDatetime",
        "Type",
        "RONumber",
        "SaleValue",
        "CostValue",
        "Description"
    }),

    RenameColumns = Table.RenameColumns(SelectColumns, {
        {"Branch", "BranchKey"},
        {"PartNumber", "PART_NO"},
        {"RONumber", "REF_NO"}
    }),

    // ========================================================================
    // STEP 3: ADD DIMENSION KEYS
    // ========================================================================

    AddDateKey = Table.AddColumn(RenameColumns, "DateKey", each
        Date.From([TransDatetime]),
        type date
    ),

    // ========================================================================
    // STEP 4: DEDUPLICATE (GROUP BY BUSINESS KEYS)
    // ========================================================================
    /*
    CRITICAL: The InTrans_Incremental table may contain duplicates due to
    watermark strategy issues (especially from December 2024).

    Deduplicate by the business keys: BranchKey, REF_NO, PART_NO, TransDatetime
    Use List.First for all values because duplicate rows are exact copies.
    This prevents duplicates from inflating SaleValue, CostValue totals.
    */
    Deduplicate = Table.Group(
        AddDateKey,
        {"BranchKey", "REF_NO", "PART_NO", "TransDatetime"},
        {
            {"DateKey", each List.First([DateKey]), type date},
            {"CustomerNo", each List.First([CustomerNo]), type text},
            {"Franchise", each List.First([Franchise]), type text},
            {"Type", each List.First([Type]), type text},
            {"Description", each List.First([Description]), type text},
            {"SaleValue", each List.First([SaleValue]), type number},
            {"CostValue", each List.First([CostValue]), type number}
        }
    ),

    // ========================================================================
    // STEP 5: REORDER COLUMNS
    // ========================================================================

    ReorderColumns = Table.ReorderColumns(Deduplicate, {
        "BranchKey",
        "DateKey",
        "REF_NO",
        "PART_NO",
        "TransDatetime",
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "SaleValue",
        "CostValue"
    }),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(ReorderColumns, {
        {"BranchKey", Int64.Type},
        {"Franchise", type text},
        {"CustomerNo", type text},
        {"PART_NO", type text},
        {"TransDatetime", type datetime},
        {"Type", type text},
        {"REF_NO", type text},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"Description", type text},
        {"DateKey", type date}
    })

in
    SetTypes

/*
============================================================================
✅ FACT_INTRANS_ALLPROMO - MIGRATION NOTES
============================================================================

🔄 MIGRATION FROM OLD REPORT:

**Old Query (InTrans_All_Promo.pq):**
- Direct ODBC query to InTrans
- Simple SELECT with date filter >= 2023-01-01

**New Query:**
- Sources from Lakehouse InTrans_Incremental
- Same columns and logic
- Added DateKey for dim_DateTable relationship

**Purpose in Report:**
- Provides Total SALE_VAL for "Percent to Sale Val" calculation
- Context for understanding promo impact on total sales
- Linked to Fact_PartsPromo via REF_NO

🧮 DAX MEASURES USING THIS TABLE:

```dax
Total SALE_VAL = SUM(Fact_InTrans_AllPromo[SaleValue])

Percent to Sale Val = DIVIDE([Net Sales Value], [Total SALE_VAL], 0)
```

⚠️ RELATIONSHIP NOTE:

The old report has a Many-to-Many relationship:
'Parts_Promo'[REF_NO] *[<->]* 'InTrans_All_Promo'[REF_NO]

This is needed because:
- One REF_NO can have multiple promo lines
- One REF_NO can have multiple regular parts lines

Consider using a bridge table or TREATAS for cleaner model design.

============================================================================
*/
