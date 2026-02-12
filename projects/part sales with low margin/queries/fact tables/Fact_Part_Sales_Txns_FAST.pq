/*
============================================================================
FACT_PART_SALES_TXNS - FAST VERSION (NO INMASTER JOIN)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Transaction-level fact table for low margin parts analysis
Grain: One row per part transaction (invoices only, TYPE = 'I')
Refresh Strategy: Incremental refresh (2-year rolling window)
Target Performance: 3-5 minutes (NO expensive InMaster join)
Source Dependencies: InTrans_Incremental ONLY

🚨 CRITICAL PERFORMANCE DECISION:
**NO InMaster JOIN in this dataflow** - Join was causing 1-hour refresh!

INSTEAD:
- This fact table has ONLY transaction data (fast)
- Low margin fields added via Power BI relationships or calculated columns
- Separates expensive join from refresh-critical path

🎯 PERFORMANCE COMPARISON:
Old approach (with InMaster JOIN): ~60 minutes ❌
New approach (no JOIN): ~3-5 minutes ✅

============================================================================
*/

let
    // ========================================================================
    // STEP 1: LOAD INCREMENTAL TRANSACTIONS
    // ========================================================================

    InTransSource = InTrans_Incremental,

    // ========================================================================
    // STEP 2: FILTER TO INVOICES (TYPE = 'I')
    // ========================================================================
    /*
    PERFORMANCE: Filter early to reduce row count by ~50%
    */

    FilterToInvoices = Table.SelectRows(InTransSource, each
        [Type] = "I"
    ),

    // ========================================================================
    // STEP 3: SELECT ESSENTIAL COLUMNS ONLY
    // ========================================================================
    /*
    F4 OPTIMIZATION: Minimal column selection = fast processing
    */

    SelectColumns = Table.SelectColumns(FilterToInvoices, {
        // Transaction keys
        "TransId",
        "RONumber",
        "TransDatetime",

        // Foreign keys for dimensions
        "Branch",
        "PartNumber",
        "Franchise",
        "CustomerNo",
        "Salesman",

        // Transaction measures
        "Type",
        "Qty",
        "SaleValue",
        "CostValue",

        // Additional context
        "Description",
        "TradeType"
    }),

    // ========================================================================
    // STEP 4: PRE-CALCULATE ACTUAL MARGIN (SIMPLE CALCULATION)
    // ========================================================================
    /*
    F4 OPTIMIZATION: Calculate Actual Margin during refresh
    This is FAST - no join required, just simple math
    */

    AddActualMargin = Table.AddColumn(
        SelectColumns,
        "ActualMarginDollars",
        each ([SaleValue] ?? 0) - ([CostValue] ?? 0),
        type number
    ),

    // ========================================================================
    // STEP 5: REMOVE DUPLICATES
    // ========================================================================

    RemoveDuplicates = Table.Distinct(AddActualMargin, {"TransId"}),

    // ========================================================================
    // STEP 6: FINAL DATA TYPES
    // ========================================================================

    FinalDataTypes = Table.TransformColumnTypes(RemoveDuplicates, {
        {"TransId", Int64.Type},
        {"RONumber", type text},
        {"TransDatetime", type datetime},
        {"Branch", type text},
        {"PartNumber", type text},
        {"Franchise", type text},
        {"CustomerNo", type text},
        {"Salesman", type text},
        {"Type", type text},
        {"Qty", type number},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"Description", type text},
        {"TradeType", type text},
        {"ActualMarginDollars", type number}
    })

in
    FinalDataTypes

/*
============================================================================
✅ PERFORMANCE OPTIMIZATIONS
============================================================================

🎯 KEY DECISION: NO InMaster JOIN

**Why this is fast**:
- Single source table (InTrans_Incremental)
- No expensive joins (InMaster join was causing 1-hour refresh)
- Minimal transformations (just filter + simple calculation)
- Leverages existing incremental refresh from InTrans_Incremental

**Expected Performance**:
- Initial load: 3-5 minutes (vs 60 minutes with join)
- Incremental refresh: 1-2 minutes
- Row count: 3-6M rows (2 years of invoices)

============================================================================
📊 HOW TO ADD LOW MARGIN FIELDS
============================================================================

**Option 1: Power BI Calculated Columns (RECOMMENDED FOR SIMPLICITY)**

In Power BI, add calculated columns to the fact table:

```dax
// Add in Fact_Part_Sales_Txns table

LowMarginFlag =
    RELATED(dim_Parts_LowMargin[LowMarginFlag])

StockOrderPrice =
    RELATED(dim_Parts_LowMargin[StockOrderPrice])

ListPriceManuf =
    RELATED(dim_Parts_LowMargin[ListPriceManuf])

OriginalMarginDollars =
    ([ListPriceManuf] - [StockOrderPrice]) * [Qty]

MarginDiscrepancyDollars =
    [ActualMarginDollars] - [OriginalMarginDollars]

IsLowMarginFlagged =
    [LowMarginFlag] = "LOW"
```

**Setup Required**:
1. Load dim_Parts_LowMargin.pq (lightweight dimension from InMaster)
2. Create relationship: Fact[PartNumber] → dim_Parts_LowMargin[PartNumber]
3. Add calculated columns above to Fact table in Power BI

**Why this works**:
- RELATED function is FAST in Power BI (optimized engine)
- Calculation happens once when model refreshes
- Much faster than Power Query join on millions of rows

---

**Option 2: Separate Lightweight Dataflow for Low Margin Enrichment**

If you want everything in dataflows, create a SECOND dataflow that:
1. Reads Fact_Part_Sales_Txns from Lakehouse (after Step 1 finishes)
2. Joins to dim_Parts_LowMargin (both are Lakehouse tables = FAST)
3. Writes back enriched version

This way the InTrans → Fact refresh is fast (3-5 min)
And the enrichment step is separate (can be optimized independently)

---

**Option 3: SQL View for Enrichment (FASTEST)**

Create a SQL view in Lakehouse that joins:

```sql
CREATE VIEW vw_Fact_Part_Sales_Txns_Enriched AS
SELECT
    f.*,
    p.LowMarginFlag,
    p.StockOrderPrice,
    p.ListPrice AS ListPriceManuf,
    (p.ListPrice - p.StockOrderPrice) * f.Qty AS OriginalMarginDollars,
    f.ActualMarginDollars - ((p.ListPrice - p.StockOrderPrice) * f.Qty) AS MarginDiscrepancyDollars,
    CASE WHEN p.LowMarginFlag = 'LOW' THEN 1 ELSE 0 END AS IsLowMarginFlagged
FROM Fact_Part_Sales_Txns f
LEFT JOIN dim_Parts_LowMargin p
    ON f.PartNumber = p.PartNumber
    AND f.Franchise = p.Franchise
```

Power BI reads from this view (SQL join is MUCH faster than Power Query join)

============================================================================
🎯 RECOMMENDED APPROACH
============================================================================

For your F4 capacity and time constraints, I recommend:

**Phase 1: Get Fast Refresh Working** (TODAY)
1. Use this FAST fact table (no InMaster join)
2. Load dim_Parts_LowMargin.pq (separate dimension)
3. Refresh time: 3-5 minutes ✅

**Phase 2: Add Low Margin Fields** (NEXT)
Choose ONE of these:
- **Easiest**: Power BI calculated columns with RELATED
- **Most Efficient**: SQL view for enrichment
- **Middle Ground**: Separate enrichment dataflow

All three options will be MUCH faster than Power Query join.

============================================================================
📋 VALIDATION QUERIES
============================================================================

After loading this fast version:

```sql
-- Verify row counts and date range
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT TransId) AS unique_transactions,
    COUNT(DISTINCT PartNumber) AS unique_parts,
    MIN(TransDatetime) AS earliest_trans,
    MAX(TransDatetime) AS latest_trans,
    SUM(SaleValue) AS total_sales,
    SUM(ActualMarginDollars) AS total_actual_margin
FROM Fact_Part_Sales_Txns

-- Check Type filter (all should be 'I')
SELECT DISTINCT Type FROM Fact_Part_Sales_Txns

-- Spot check actual margin calculation
SELECT TOP 10
    TransId,
    SaleValue,
    CostValue,
    ActualMarginDollars,
    (SaleValue - CostValue) AS calculated_margin
FROM Fact_Part_Sales_Txns
```

Expected:
- 3-6M rows
- All Type = 'I'
- ActualMarginDollars = SaleValue - CostValue

============================================================================
*/
