/*
============================================================================
DIM_REPAIRORDER - REPAIR ORDER CONTEXT FOR PROMO ANALYSIS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Pre-aggregated repair order metrics for promo context
Grain: One row per unique REF_NO (repair order/reference number)
Refresh Strategy: Full refresh from Lakehouse
Performance: Target <3 min refresh
Source Dependencies: InTrans_Incremental (Lakehouse table)

⚠️ DEDUPLICATION:
The InTrans_Incremental table may contain duplicate rows due to watermark
strategy issues (introduced ~December 2024). This query includes a GROUP BY
step to deduplicate by (Branch, RONumber, PartNumber, TransDatetime) before
aggregating to the REF_NO level. This prevents duplicates from inflating
TotalPartsSales, TotalPartsCost, and other aggregated metrics.

🎯 BUSINESS USE CASES:
• Order Context: Understand the full order that received a promo discount
• Discount Effectiveness: Compare discount amount to total order value
• Margin Impact: Calculate true margin with and without discounts
• Customer Behavior: Analyze which orders receive promos

📊 DATA STRUCTURE:

**Primary Key:**
• REF_NO: Repair order / reference number

**Order Attributes:**
• BranchKey: Branch where order was placed
• CustomerNo: Customer who placed the order
• OrderDate: Date of first transaction on this order
• LastActivityDate: Most recent transaction on this order

**Non-Promo Parts Aggregates (Original Order Value):**
• TotalPartsSales: Sum of SaleValue for non-promo, non-ZP parts
• TotalPartsCost: Sum of CostValue for non-promo, non-ZP parts
• PartsCount: Count of non-promo, non-ZP parts

**Promo Aggregates:**
• TotalPromoDiscount: Sum of SaleValue for promo parts (negative = discount)
• PromoCount: Count of promo transactions on this order

**Calculated Metrics:**
• NetOrderValue: TotalPartsSales + TotalPromoDiscount
• OriginalMargin: TotalPartsSales - TotalPartsCost
• NetMargin: NetOrderValue - TotalPartsCost
• DiscountPercent: ABS(TotalPromoDiscount) / TotalPartsSales

🔧 DESIGN RATIONALE:
This dimension REPLACES the complex self-join in the old query.
By pre-aggregating at the REF_NO level, we:
1. Eliminate runtime aggregation in Fact_PartsPromo
2. Create a clean one-to-many relationship
3. Enable efficient DAX calculations
4. Provide order-level summary for dashboards

🔗 RELATIONSHIPS:
• REF_NO ← Fact_PartsPromo[REF_NO] (One-to-Many)
• BranchKey → dim_BranchLocation[BranchID]

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION
    // ========================================================================
    StartDate = #datetime(2022, 1, 1, 0, 0, 0),  // Match Fact_PartsPromo date range

    // ========================================================================
    // SOURCE: Lakehouse InTrans_Incremental
    // ========================================================================
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
    // STEP 2: IDENTIFY ORDERS WITH PROMO ACTIVITY
    // ========================================================================
    /*
    PURPOSE: Only include REF_NOs that have at least one promo transaction
    This keeps the dimension focused on orders relevant to promo analysis
    */

    // Get unique REF_NOs that have promo parts
    // NOTE: Do NOT filter out ZP franchise - promo parts typically HAVE Franchise = 'ZP'
    PromoOrders = Table.Distinct(
        Table.SelectColumns(
            Table.SelectRows(FilteredByDate, each
                Text.StartsWith([PartNumber], "*")
            ),
            {"RONumber"}
        )
    ),

    // Filter main dataset to only orders with promos
    OrdersWithPromos = Table.NestedJoin(
        FilteredByDate, {"RONumber"},
        PromoOrders, {"RONumber"},
        "HasPromo", JoinKind.Inner
    ),

    // Remove the join column (we just needed it for filtering)
    FilteredOrders = Table.RemoveColumns(OrdersWithPromos, {"HasPromo"}),

    // ========================================================================
    // STEP 2.5: DEDUPLICATE SOURCE DATA
    // ========================================================================
    /*
    CRITICAL: The InTrans_Incremental table may contain duplicates due to
    watermark strategy issues (introduced ~December 2024).

    Deduplicate by the same keys as the old SQL query's grain:
    Branch, RONumber, PartNumber, TransDatetime

    Use List.First (not Sum!) because duplicate rows are exact copies.
    This prevents duplicates from inflating TotalPartsSales, TotalPartsCost, etc.
    */
    DeduplicatedOrders = Table.Group(
        FilteredOrders,
        {"Branch", "RONumber", "PartNumber", "TransDatetime"},
        {
            {"CustomerNo", each List.First([CustomerNo]), type text},
            {"Franchise", each List.First([Franchise]), type text},
            {"Type", each List.First([Type]), type text},
            {"Description", each List.First([Description]), type text},
            {"Qty", each List.First([Qty]), type number},
            {"SaleValue", each List.First([SaleValue]), type number},
            {"CostValue", each List.First([CostValue]), type number}
        }
    ),

    // ========================================================================
    // STEP 3: AGGREGATE BY REF_NO
    // ========================================================================
    /*
    PURPOSE: Create one row per REF_NO with all relevant metrics
    LOGIC: Separate aggregation for promo vs non-promo parts
    */

    AggregatedOrders = Table.Group(
        DeduplicatedOrders,
        {"RONumber"},
        {
            // Order attributes (take first/last values)
            {"BranchKey", each List.First([Branch]), Int64.Type},
            {"CustomerNo", each List.First([CustomerNo]), type text},
            {"OrderDate", each List.Min([TransDatetime]), type datetime},
            {"LastActivityDate", each List.Max([TransDatetime]), type datetime},

            // Non-promo parts aggregates (the "original" order value)
            {"TotalPartsSales", each List.Sum(
                List.Transform(
                    Table.ToRecords(
                        Table.SelectRows(_, (r) =>
                            not Text.StartsWith(r[PartNumber], "*") and r[Franchise] <> "ZP"
                        )
                    ),
                    (r) => if r[SaleValue] = null then 0 else r[SaleValue]
                )
            ), type number},

            {"TotalPartsCost", each List.Sum(
                List.Transform(
                    Table.ToRecords(
                        Table.SelectRows(_, (r) =>
                            not Text.StartsWith(r[PartNumber], "*") and r[Franchise] <> "ZP"
                        )
                    ),
                    (r) => if r[CostValue] = null then 0 else r[CostValue]
                )
            ), type number},

            {"PartsCount", each Table.RowCount(
                Table.SelectRows(_, (r) =>
                    not Text.StartsWith(r[PartNumber], "*") and r[Franchise] <> "ZP"
                )
            ), Int64.Type},

            // Promo aggregates (NO ZP filter - promo parts typically ARE ZP franchise)
            {"TotalPromoDiscount", each List.Sum(
                List.Transform(
                    Table.ToRecords(
                        Table.SelectRows(_, (r) =>
                            Text.StartsWith(r[PartNumber], "*")
                        )
                    ),
                    (r) => if r[SaleValue] = null then 0 else r[SaleValue]
                )
            ), type number},

            {"PromoCount", each Table.RowCount(
                Table.SelectRows(_, (r) =>
                    Text.StartsWith(r[PartNumber], "*")
                )
            ), Int64.Type}
        }
    ),

    // ========================================================================
    // STEP 4: CALCULATE DERIVED METRICS
    // ========================================================================

    // Replace nulls with 0
    ReplaceNulls = Table.ReplaceValue(
        Table.ReplaceValue(
            Table.ReplaceValue(
                Table.ReplaceValue(
                    Table.ReplaceValue(AggregatedOrders, null, 0, Replacer.ReplaceValue, {"TotalPartsSales"}),
                    null, 0, Replacer.ReplaceValue, {"TotalPartsCost"}
                ),
                null, 0, Replacer.ReplaceValue, {"PartsCount"}
            ),
            null, 0, Replacer.ReplaceValue, {"TotalPromoDiscount"}
        ),
        null, 0, Replacer.ReplaceValue, {"PromoCount"}
    ),

    // Add calculated columns
    AddNetOrderValue = Table.AddColumn(ReplaceNulls, "NetOrderValue", each
        [TotalPartsSales] + [TotalPromoDiscount],  // Discount is negative
        type number
    ),

    AddOriginalMargin = Table.AddColumn(AddNetOrderValue, "OriginalMargin", each
        [TotalPartsSales] - [TotalPartsCost],
        type number
    ),

    AddNetMargin = Table.AddColumn(AddOriginalMargin, "NetMargin", each
        [NetOrderValue] - [TotalPartsCost],
        type number
    ),

    AddDiscountAmount = Table.AddColumn(AddNetMargin, "DiscountAmount", each
        Number.Abs([TotalPromoDiscount]),
        type number
    ),

    AddDiscountPercent = Table.AddColumn(AddDiscountAmount, "DiscountPercent", each
        if [TotalPartsSales] = 0 or [TotalPartsSales] = null then 0
        else [DiscountAmount] / [TotalPartsSales],
        type number
    ),

    // ========================================================================
    // STEP 5: RENAME AND FINALIZE
    // ========================================================================
    RenameColumns = Table.RenameColumns(AddDiscountPercent, {
        {"RONumber", "REF_NO"}
    }),

    FinalColumns = Table.SelectColumns(RenameColumns, {
        // Keys
        "REF_NO",
        "BranchKey",
        "CustomerNo",
        // Dates
        "OrderDate",
        "LastActivityDate",
        // Non-Promo Aggregates
        "TotalPartsSales",
        "TotalPartsCost",
        "PartsCount",
        // Promo Aggregates
        "TotalPromoDiscount",
        "PromoCount",
        // Calculated
        "NetOrderValue",
        "OriginalMargin",
        "NetMargin",
        "DiscountAmount",
        "DiscountPercent"
    }),

    // ========================================================================
    // STEP 6: SET DATA TYPES
    // ========================================================================
    SetTypes = Table.TransformColumnTypes(FinalColumns, {
        {"REF_NO", type text},
        {"BranchKey", Int64.Type},
        {"CustomerNo", type text},
        {"OrderDate", type datetime},
        {"LastActivityDate", type datetime},
        {"TotalPartsSales", type number},
        {"TotalPartsCost", type number},
        {"PartsCount", Int64.Type},
        {"TotalPromoDiscount", type number},
        {"PromoCount", Int64.Type},
        {"NetOrderValue", type number},
        {"OriginalMargin", type number},
        {"NetMargin", type number},
        {"DiscountAmount", type number},
        {"DiscountPercent", type number}
    })

in
    SetTypes

/*
============================================================================
✅ DIM_REPAIRORDER - DESIGN NOTES
============================================================================

🎯 WHY THIS DIMENSION EXISTS:

The old report used a complex self-join to get PartSales/PartCost:
- Main query: Promo transactions
- Subquery: Aggregate non-promo parts by REF_NO
- Join: Match promo transactions to their order totals

PROBLEMS with old approach:
1. Self-join on 10M+ row table = slow
2. Many-to-many relationship in model = complex DAX
3. Aggregation at query time = repeated work

THIS DIMENSION solves all three:
1. Pre-aggregate once, reuse everywhere
2. Clean one-to-many relationship
3. Calculations done at refresh time, not query time

🧮 HOW TO USE IN DAX:

**Order-Level Metrics (from this dimension):**
```dax
Total Original Sales = SUM(dim_RepairOrder[TotalPartsSales])
Total Discount = SUM(dim_RepairOrder[DiscountAmount])
Total Net Sales = SUM(dim_RepairOrder[NetOrderValue])
Avg Discount % = AVERAGE(dim_RepairOrder[DiscountPercent])
```

**Transaction-Level Metrics (from Fact_PartsPromo):**
```dax
Promo Transaction Count = COUNTROWS(Fact_PartsPromo)
Unique Orders with Promos = DISTINCTCOUNT(Fact_PartsPromo[REF_NO])
```

**Combined Analysis:**
```dax
Avg Discount per Order =
DIVIDE(
    SUM(dim_RepairOrder[DiscountAmount]),
    DISTINCTCOUNT(dim_RepairOrder[REF_NO])
)
```

============================================================================
*/
