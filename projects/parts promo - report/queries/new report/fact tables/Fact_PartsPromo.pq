/*
============================================================================
FACT_PARTSPROMO - PROMOTIONAL PARTS TRANSACTIONS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Track promotional parts sales (part numbers starting with asterisk *)
Grain: One row per promo transaction (Branch+REF_NO+PART_NO+Trans_Datetime)
Refresh Strategy: Full refresh from Lakehouse (source is already incremental)
Performance: Target <2 min refresh (filtered subset of InTrans_Incremental)
Source Dependencies: InTrans_Incremental (Lakehouse table - 10.2M rows, 3x daily refresh)

🎯 BUSINESS USE CASES:
• Promotional Analysis: Track discount patterns and promotional effectiveness
• Margin Analysis: Compare original vs discounted sales values and margins
• Rolling Comparisons: 12-month rolling metrics with YoY comparison
• Branch Performance: Evaluate promotional activity by location
• Customer Insights: Understand which customers use promotions most

📊 DATA STRUCTURE:

**Business Keys (Grain):**
• Branch: Branch location identifier
• REF_NO: Repair order / reference number
• PART_NO: Part number (always starts with * for promos)
• TransDatetime: Transaction date and time

**Dimension Keys:**
• BranchKey: Links to dim_BranchLocation
• DateKey: Links to dim_DateTable (extract date from TransDatetime)

**Customer & Job Context:**
• CustomerNo: Customer identifier
• Franchise: Equipment manufacturer
• Type: Transaction type
• Description: Part description

**Quantity Metrics:**
• Qty: Transaction quantity

**Financial Metrics - Promo Transaction Level:**
• SaleValue: The DISCOUNTED sale value (negative for promos)
• CostValue: Cost value of the transaction

**Aggregated Metrics from Related Parts:**
• PartSales: Total original sales for related parts on same REF_NO
• PartCost: Total cost for related parts on same REF_NO
• PartsCount: Count of related parts on same REF_NO

**Calculated Columns:**
• NetSalesValue: PartSales + SaleValue (Original - Discount = Net)
• OriginalMargin: PartSales - PartCost
• NetMargin: NetSalesValue - PartCost
• DiscountAmount: ABS(SaleValue) - the discount applied
• DiscountPercent: DiscountAmount / PartSales

🔧 DESIGN APPROACH:

**Migration from Old Report:**
• Original query used self-join on InTrans table
• New approach: Use Lakehouse InTrans_Incremental (already optimized)
• Replicate aggregation logic in Power Query

**Key Business Rules:**
• Promo Parts: PART_NO starts with '*' (asterisk)
• Exclude: ZP franchise
• Date Range: 2022-01-01 onwards (configurable)

**Performance Optimization:**
• Source from Lakehouse (not direct ODBC) - leverage incremental refresh
• Pre-calculate metrics in Power Query (not DAX)
• Strategic column selection

🔄 REFRESH CHARACTERISTICS:
Estimated Row Count: ~50,000-100,000 rows (subset of 10M InTrans)
Target Refresh Time: <2 minutes
Refresh Schedule: Daily (after InTrans_Incremental refreshes)
Last Modified: [Current Date]
Created: 01/16/2026

🔗 RELATIONSHIPS:
• Branch → dim_BranchLocation[BranchID]
• DateKey → dim_DateTable[DateKey]
• REF_NO → Fact_InTrans_AllPromo[REF_NO] (Many-to-Many for context)

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION - Adjustable parameters
    // ========================================================================
    StartDate = #datetime(2022, 1, 1, 0, 0, 0),  // Historical start date for promos (datetime for comparison)

    // ========================================================================
    // SOURCE: Lakehouse InTrans_Incremental
    // ========================================================================
    /*
    PURPOSE: Reference the already-optimized incremental InTrans table
    BENEFIT: 3x daily refresh, watermark-based, no ODBC overhead
    */

    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO DATE RANGE
    // ========================================================================
    FilteredByDate = Table.SelectRows(InTrans, each
        [TransDatetime] >= StartDate
    ),

    // ========================================================================
    // STEP 2: PROMO PARTS - Main fact rows
    // ========================================================================
    /*
    PURPOSE: Filter to promotional parts only (PART_NO starts with *)
    BUSINESS RULE: Promo parts always have asterisk prefix, exclude ZP franchise
    */

    FilterToPromos = Table.SelectRows(FilteredByDate, each
        Text.StartsWith([PartNumber], "*")
        and [Franchise] <> "ZP"
    ),

    // ========================================================================
    // STEP 3: NON-PROMO PARTS AGGREGATION
    // ========================================================================
    /*
    PURPOSE: Get total sales/cost/count for all NON-promo parts on same REF_NO
    BUSINESS LOGIC: This shows what the original order value was before discount

    APPROACH: Filter to non-promo parts first, then aggregate
    This is more efficient than conditional aggregation over all rows
    */

    // Filter to non-promo, non-ZP parts only
    NonPromoNonZP = Table.SelectRows(FilteredByDate, each
        not Text.StartsWith([PartNumber], "*")
        and [Franchise] <> "ZP"
    ),

    // Aggregate non-promo parts by RONumber
    NonPromoAggregates = Table.Group(
        NonPromoNonZP,
        {"RONumber"},
        {
            {"PartSales", each List.Sum([SaleValue]), type number},
            {"PartCost", each List.Sum([CostValue]), type number},
            {"PartsCount", each Table.RowCount(_), Int64.Type}
        }
    ),

    // ========================================================================
    // STEP 4: JOIN PROMO TRANSACTIONS WITH AGGREGATES
    // ========================================================================
    /*
    PURPOSE: Add aggregated metrics to each promo transaction
    LOGIC: LEFT OUTER JOIN - promo parts may exist without non-promo parts on same order
    (Different from old query which used INNER JOIN, but LEFT is more inclusive)
    */

    JoinWithAggregates = Table.NestedJoin(
        FilterToPromos, {"RONumber"},
        NonPromoAggregates, {"RONumber"},
        "Aggregates", JoinKind.LeftOuter
    ),

    ExpandAggregates = Table.ExpandTableColumn(
        JoinWithAggregates, "Aggregates",
        {"PartSales", "PartCost", "PartsCount"},
        {"PartSales", "PartCost", "PartsCount"}
    ),

    // ========================================================================
    // STEP 4: CALCULATE DERIVED METRICS
    // ========================================================================
    /*
    PURPOSE: Pre-calculate metrics for better DAX performance
    */

    // Replace nulls with 0 for aggregates
    ReplaceNulls = Table.ReplaceValue(
        Table.ReplaceValue(
            Table.ReplaceValue(ExpandAggregates, null, 0, Replacer.ReplaceValue, {"PartSales"}),
            null, 0, Replacer.ReplaceValue, {"PartCost"}
        ),
        null, 0, Replacer.ReplaceValue, {"PartsCount"}
    ),

    // Add calculated columns
    AddNetSalesValue = Table.AddColumn(ReplaceNulls, "NetSalesValue", each
        [PartSales] + [SaleValue],  // Original sales + discount (negative) = Net
        type number
    ),

    AddDiscountAmount = Table.AddColumn(AddNetSalesValue, "DiscountAmount", each
        Number.Abs([SaleValue]),  // The discount is stored as negative, so abs it
        type number
    ),

    AddDiscountPercent = Table.AddColumn(AddDiscountAmount, "DiscountPercent", each
        if [PartSales] = 0 or [PartSales] = null then 0
        else [DiscountAmount] / [PartSales],
        type number
    ),

    AddOriginalMargin = Table.AddColumn(AddDiscountPercent, "OriginalMargin", each
        [PartSales] - [PartCost],
        type number
    ),

    AddNetMargin = Table.AddColumn(AddOriginalMargin, "NetMargin", each
        [NetSalesValue] - [PartCost],
        type number
    ),

    // ========================================================================
    // STEP 5: ADD DIMENSION KEYS
    // ========================================================================
    /*
    PURPOSE: Add keys for relationship to dimensions
    */

    AddDateKey = Table.AddColumn(AddNetMargin, "DateKey", each
        Date.From([TransDatetime]),
        type date
    ),

    // Rename Branch to BranchKey for clarity
    RenameColumns = Table.RenameColumns(AddDateKey, {
        {"Branch", "BranchKey"},
        {"RONumber", "REF_NO"},
        {"CustomerNo", "CustomerNo"},
        {"PartNumber", "PART_NO"}
    }),

    // ========================================================================
    // STEP 6: SELECT FINAL COLUMNS
    // ========================================================================
    /*
    PURPOSE: Select only needed columns, proper order
    */

    FinalColumns = Table.SelectColumns(RenameColumns, {
        // Keys
        "BranchKey",
        "DateKey",
        "REF_NO",
        "PART_NO",
        "TransDatetime",
        // Context
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "Qty",
        // Financial - Transaction Level
        "SaleValue",
        "CostValue",
        // Financial - Aggregated from Related Parts
        "PartSales",
        "PartCost",
        "PartsCount",
        // Calculated Metrics
        "NetSalesValue",
        "DiscountAmount",
        "DiscountPercent",
        "OriginalMargin",
        "NetMargin"
    }),

    // ========================================================================
    // STEP 7: SET DATA TYPES
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(FinalColumns, {
        {"BranchKey", Int64.Type},
        {"DateKey", type date},
        {"REF_NO", type text},
        {"PART_NO", type text},
        {"TransDatetime", type datetime},
        {"CustomerNo", type text},
        {"Franchise", type text},
        {"Type", type text},
        {"Description", type text},
        {"Qty", type number},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"PartSales", type number},
        {"PartCost", type number},
        {"PartsCount", Int64.Type},
        {"NetSalesValue", type number},
        {"DiscountAmount", type number},
        {"DiscountPercent", type number},
        {"OriginalMargin", type number},
        {"NetMargin", type number}
    })

in
    SetTypes

/*
============================================================================
✅ FACT_PARTSPROMO - MIGRATION NOTES
============================================================================

🔄 MIGRATION FROM OLD REPORT:

**Old Query (Parts_Promo.pq):**
- Used complex self-join SQL on ODBC InTrans
- Aggregated PartSales, PartCost, PartsCount per REF_NO
- Filtered PART_NO LIKE '*%' and Franchise != 'ZP'

**New Query:**
- Sources from Lakehouse InTrans_Incremental (already incremental!)
- Same business logic, cleaner implementation
- Pre-calculated metrics for DAX performance

**Columns Preserved:**
- BRANCH, FRANCHISE, customer_no, REF_NO, PART_NO, Trans_Datetime
- TYPE, QTY, SALE_VAL, COST_VAL, DESCRIPTION
- Part_Sales, Part_Cost, Parts_Count (aggregated)

**New Calculated Columns:**
- NetSalesValue (was DAX measure before)
- DiscountAmount, DiscountPercent
- OriginalMargin, NetMargin
- DateKey for dim_DateTable relationship

🧮 DAX MEASURES TO UPDATE:

These measures can now be simpler since calculations are pre-computed:

**Simplified:**
```dax
Discount = SUM(Fact_PartsPromo[DiscountAmount])
Net Sales Value = SUM(Fact_PartsPromo[NetSalesValue])
Original Sale Value = SUM(Fact_PartsPromo[PartSales])
Cost Value = SUM(Fact_PartsPromo[PartCost])
Original Margin $ = SUM(Fact_PartsPromo[OriginalMargin])
Net Margin $ = SUM(Fact_PartsPromo[NetMargin])
```

**Still Needed (Rolling calculations):**
- Rolling12MonthCount, Rolling12MonthNetSalesValue
- PreviousYearRolling calculations
- % Change calculations

🚀 NEXT STEPS:

1. Update Lakehouse workspace/lakehouse IDs in query
2. Create dataflow df_Fact_PartsPromo
3. Test refresh and validate row counts
4. Update relationships in semantic model
5. Update DAX measures to reference new columns

============================================================================
*/
