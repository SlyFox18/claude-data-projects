/*
============================================================================
FACT_PARTSPROMO_V2 - PROMOTIONAL PARTS TRANSACTIONS (SIMPLIFIED)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Track promotional parts transactions (part numbers starting with *)
Grain: One row per unique promo event (Branch+REF_NO+PART_NO+TransDatetime)
Refresh Strategy: Full refresh from Lakehouse
Performance: Target <1 min refresh (simple filter + deduplication)
Source Dependencies: InTrans_Incremental (Lakehouse table)

⚠️ DEDUPLICATION:
The InTrans_Incremental table may contain duplicate rows due to watermark
strategy issues (introduced ~December 2024). This query includes a GROUP BY
step to deduplicate by the business keys (Branch, REF_NO, PART_NO, TransDatetime),
summing SaleValue/CostValue/Qty for any duplicate rows. This matches the
behavior of the old SQL query's GROUP BY clause.

🎯 DESIGN PHILOSOPHY:
This is the SIMPLIFIED version that works with dim_RepairOrder.
- NO self-join aggregation (dim_RepairOrder handles that)
- NO calculated columns for PartSales/PartCost (get from dimension)
- SIMPLE filter and select - fast and reliable

📊 DATA STRUCTURE:

**Business Keys (Grain):**
• REF_NO: Repair order / reference number
• PART_NO: Promo part number (always starts with *)
• TransDatetime: Transaction date and time

**Dimension Keys:**
• Branch: Links to dim_BranchLocation[BranchID] (text)
• DateKey: Links to dim_DateTable
• REF_NO: Links to dim_RepairOrder (for order context)
• PART_NO: Links to dim_PromoType (for promo categorization)

**Transaction Attributes:**
• CustomerNo: Customer identifier
• Franchise: Equipment manufacturer
• Type: Transaction type
• Description: Promo description

**Metrics:**
• Qty: Transaction quantity
• SaleValue: The discount amount (typically negative)
• CostValue: Cost value (usually 0 for promos)

🔗 RELATIONSHIPS:
• Branch → dim_BranchLocation[BranchID] (text to text)
• DateKey → dim_DateTable[Date]
• REF_NO → dim_RepairOrder[REF_NO] (Many-to-One) ⭐ KEY RELATIONSHIP
• PART_NO → dim_PromoType[PromoPartNo]

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION
    // ========================================================================
    StartDate = #datetime(2022, 1, 1, 0, 0, 0),

    // ========================================================================
    // SOURCE: Lakehouse InTrans_Incremental
    // ========================================================================
    Source = Lakehouse.Contents([HierarchicalNavigation = null]),
    Workspace = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],
    Lakehouse = Workspace{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],
    InTrans = Lakehouse{[Id = "InTrans_Incremental", ItemKind = "Table"]}[Data],

    // ========================================================================
    // STEP 1: FILTER TO PROMO PARTS
    // ========================================================================
    /*
    SIMPLE FILTER: Just get promo transactions
    - Part number starts with *
    - Date range from 2022 onwards

    NOTE: Do NOT filter out ZP franchise here!
    Promo parts (like *FOS, *10PROMO) typically HAVE Franchise = 'ZP'
    The ZP exclusion in the old query was only for the aggregation of non-promo parts.
    */
    FilterToPromos = Table.SelectRows(InTrans, each
        Text.StartsWith([PartNumber], "*")
        and [TransDatetime] >= StartDate
    ),

    // ========================================================================
    // STEP 2: SELECT COLUMNS
    // ========================================================================
    SelectColumns = Table.SelectColumns(FilterToPromos, {
        "Branch",
        "RONumber",
        "PartNumber",
        "TransDatetime",
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "Qty",
        "SaleValue",
        "CostValue"
    }),

    // ========================================================================
    // STEP 3: ADD DIMENSION KEYS
    // ========================================================================
    AddDateKey = Table.AddColumn(SelectColumns, "DateKey", each
        Date.From([TransDatetime]),
        type date
    ),

    // ========================================================================
    // STEP 4: RENAME COLUMNS FOR CONSISTENCY
    // ========================================================================
    // NOTE: Keep Branch as text (not BranchKey as Int64) to match Fact_InTrans_AllPromo
    // Both fact tables will use Branch → dim_BranchLocation[BranchID] relationship
    RenameColumns = Table.RenameColumns(AddDateKey, {
        {"RONumber", "REF_NO"},
        {"PartNumber", "PART_NO"}
    }),

    // ========================================================================
    // STEP 5: REORDER COLUMNS
    // ========================================================================
    ReorderColumns = Table.ReorderColumns(RenameColumns, {
        "Branch",
        "DateKey",
        "REF_NO",
        "PART_NO",
        "TransDatetime",
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "Qty",
        "SaleValue",
        "CostValue"
    }),

    // ========================================================================
    // STEP 6: DEDUPLICATE (GROUP BY BUSINESS KEYS)
    // ========================================================================
    /*
    CRITICAL: The InTrans_Incremental table may contain duplicates due to
    watermark strategy issues (especially from December 2024).

    This step mirrors the old SQL query's GROUP BY clause which includes QTY
    in the GROUP BY (not summed). We use List.First for all values because
    duplicate rows are exact copies - we just need to keep one.

    - Group by: Branch, REF_NO, PART_NO, TransDatetime
    - Take first (not sum!): All other columns including Qty, SaleValue, CostValue

    This ensures we count unique events, not inflated values from duplicates.
    */
    Deduplicate = Table.Group(
        ReorderColumns,
        {"Branch", "REF_NO", "PART_NO", "TransDatetime"},
        {
            {"DateKey", each List.First([DateKey]), type date},
            {"CustomerNo", each List.First([CustomerNo]), type text},
            {"Franchise", each List.First([Franchise]), type text},
            {"Type", each List.First([Type]), type text},
            {"Description", each List.First([Description]), type text},
            {"Qty", each List.First([Qty]), type number},
            {"SaleValue", each List.First([SaleValue]), type number},
            {"CostValue", each List.First([CostValue]), type number}
        }
    ),

    // Reorder columns after grouping
    FinalReorder = Table.ReorderColumns(Deduplicate, {
        "Branch",
        "DateKey",
        "REF_NO",
        "PART_NO",
        "TransDatetime",
        "CustomerNo",
        "Franchise",
        "Type",
        "Description",
        "Qty",
        "SaleValue",
        "CostValue"
    }),

    // ========================================================================
    // STEP 7: SET DATA TYPES
    // ========================================================================
    SetTypes = Table.TransformColumnTypes(FinalReorder, {
        {"Branch", type text},
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
        {"CostValue", type number}
    })

in
    SetTypes

/*
============================================================================
✅ FACT_PARTSPROMO_V2 - WHY THIS IS BETTER
============================================================================

🎯 COMPARISON TO OLD APPROACH:

**OLD Fact_PartsPromo:**
- Complex self-join to get PartSales/PartCost
- Pre-calculated columns (NetSalesValue, DiscountPercent, etc.)
- Slow refresh due to aggregation
- Duplicated logic between query and DAX

**NEW Fact_PartsPromo_v2:**
- Simple filter and select
- No joins, no aggregation
- Fast refresh (<1 min expected)
- Order context comes from dim_RepairOrder relationship

**The magic happens in the MODEL, not the query!**

🧮 DAX MEASURES FOR THE NEW MODEL:

**Basic Aggregations:**
```dax
// From Fact_PartsPromo_v2 (transaction level)
Promo Count = COUNTROWS(Fact_PartsPromo)
Total Promo Discount = SUM(Fact_PartsPromo[SaleValue])  // Negative values
Discount Amount = -SUM(Fact_PartsPromo[SaleValue])  // Make positive

// From dim_RepairOrder (order level, via relationship)
Original Sales = SUM(dim_RepairOrder[TotalPartsSales])
Net Sales = SUM(dim_RepairOrder[NetOrderValue])
Original Margin = SUM(dim_RepairOrder[OriginalMargin])
Net Margin = SUM(dim_RepairOrder[NetMargin])
```

**Calculated Metrics:**
```dax
Discount % =
DIVIDE(
    -SUM(Fact_PartsPromo[SaleValue]),
    SUM(dim_RepairOrder[TotalPartsSales]),
    0
)

Avg Discount per Order =
DIVIDE(
    -SUM(Fact_PartsPromo[SaleValue]),
    DISTINCTCOUNT(Fact_PartsPromo[REF_NO]),
    0
)

Orders with Promos = DISTINCTCOUNT(Fact_PartsPromo[REF_NO])
```

**Rolling Calculations:**
```dax
Rolling 12M Discount =
CALCULATE(
    -SUM(Fact_PartsPromo[SaleValue]),
    DATESINPERIOD(dim_DateTable[Date], TODAY(), -12, MONTH)
)

Rolling 12M Net Sales =
CALCULATE(
    SUM(dim_RepairOrder[NetOrderValue]),
    DATESINPERIOD(dim_DateTable[Date], TODAY(), -12, MONTH)
)
```

📊 DATA MODEL RELATIONSHIPS:

```
dim_DateTable
    │
    │ (DateKey)
    ▼
dim_BranchLocation ──► Fact_PartsPromo_v2 ◄── dim_PromoType
    │                        │
    │ (Branch→BranchID)      │ (REF_NO)
    │                        ▼
    └──────────────► dim_RepairOrder
```

Key relationship: Fact_PartsPromo[REF_NO] → dim_RepairOrder[REF_NO]
- Many-to-One (multiple promo lines per order)
- Single direction filter (dim → fact)
- This gives fact table access to order-level metrics

============================================================================
*/
