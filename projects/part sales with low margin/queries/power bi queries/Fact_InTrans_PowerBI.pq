/*
============================================================================
FACT_INTRANS - FOR POWER BI DIRECT IMPORT
============================================================================
Purpose: Parts sales transactions for low margin analysis
Source: InTrans_Incremental table from Lakehouse
Grain: One row per invoice transaction (TYPE = 'I')
Expected Rows: 3-6M (2 years of invoices)
Expected Refresh: 5-8 minutes
============================================================================
*/

let
    // ========================================================================
    // STEP 1: CONNECT TO INTRANS_INCREMENTAL FROM LAKEHOUSE
    // ========================================================================

    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="InTrans_Incremental"]}[Data],

    // ========================================================================
    // STEP 2: FILTER TO INVOICE TRANSACTIONS (TYPE = 'I')
    // ========================================================================
    /*
    PERFORMANCE: Filter early to reduce row count by ~50%
    BUSINESS LOGIC: Low margin analysis focuses on invoiced sales
    */

    FilterToInvoices = Table.SelectRows(dbo_InTrans_Incremental, each
        [Type] = "I"
    ),

    // ========================================================================
    // STEP 3: FILTER TO LAST 2 YEARS
    // ========================================================================
    /*
    PERFORMANCE: Critical filter to reduce 6+ years to 2 years
    Reduces row count from ~15M to 3-6M
    Matches old report data scope
    */

    FilterDateRange = Table.SelectRows(FilterToInvoices, each
        [TransDatetime] >= DateTime.From(Date.AddYears(DateTime.Date(DateTime.LocalNow()), -2))
    ),

    // ========================================================================
    // STEP 4: SELECT ESSENTIAL COLUMNS
    // ========================================================================
    /*
    PERFORMANCE: Only include columns needed for analysis
    Reduces memory footprint and refresh time
    */

    SelectColumns = Table.SelectColumns(FilterDateRange, {
        // Transaction keys
        "TransId",
        "RONumber",
        "TransDatetime",

        // Foreign keys for dimension joins
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
    // STEP 5: PRE-CALCULATE ACTUAL MARGIN
    // ========================================================================
    /*
    F4 OPTIMIZATION: Calculate once during refresh, not in DAX measures
    Actual Margin = Sale $ - Cost $
    */

    AddActualMargin = Table.AddColumn(
        SelectColumns,
        "ActualMarginDollars",
        each ([SaleValue] ?? 0) - ([CostValue] ?? 0),
        type number
    ),

    // ========================================================================
    // STEP 6: REMOVE DUPLICATES
    // ========================================================================
    /*
    DATA QUALITY: Ensure unique transactions
    */

    RemoveDuplicates = Table.Distinct(AddActualMargin, {"TransId"}),

    // ========================================================================
    // STEP 7: FINAL DATA TYPES
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
NEXT STEPS IN POWER BI:

1. LOAD THIS QUERY TO MODEL

2. CREATE RELATIONSHIPS:
   - Fact_InTrans[TransDatetime] → dim_DateTable[Date] (ACTIVE)
   - Fact_InTrans[Branch] → dim_BranchLocation[Branch] (ACTIVE)
   - Fact_InTrans[PartNumber] → dim_Parts[PartNumber] (ACTIVE)
   - Fact_InTrans[CustomerNo] → dim_CustomerList[CustomerNo] (ACTIVE)
   - Fact_InTrans[PartNumber] → dim_Parts_LowMargin[PartNumber] (INACTIVE)

3. ADD CALCULATED COLUMNS (in Fact_InTrans table):

   LowMarginFlag =
       RELATED(dim_Parts_LowMargin[LowMarginFlag])

   StockOrderPrice =
       RELATED(dim_Parts_LowMargin[StockOrderPrice])

   ListPriceManuf =
       RELATED(dim_Parts_LowMargin[ListPrice])

   OriginalMarginDollars =
       ([ListPriceManuf] - [StockOrderPrice]) * [Qty]

   MarginDiscrepancyDollars =
       [ActualMarginDollars] - [OriginalMarginDollars]

   IsLowMarginFlagged =
       [LowMarginFlag] = "LOW"

4. CREATE BASE MEASURES:

   Sale $ = SUM(Fact_InTrans[SaleValue])
   Cost $ = SUM(Fact_InTrans[CostValue])
   Qty = SUM(Fact_InTrans[Qty])

   Actual Margin $ = SUM(Fact_InTrans[ActualMarginDollars])
   Original Margin $ = SUM(Fact_InTrans[OriginalMarginDollars])
   Margin Discrepancy $ = SUM(Fact_InTrans[MarginDiscrepancyDollars])

   Actual Margin % = DIVIDE([Actual Margin $], [Sale $], 0)
   Original Margin % = DIVIDE([Original Margin $], [Sale $], 0)

5. VALIDATE:
   - Check row count (should be 3-6M)
   - Verify all Type = 'I'
   - Spot check margin calculations
   - Compare totals to old report

Expected Refresh Time: 5-8 minutes (similar to old report)
Expected Model Size: 500MB-1GB compressed
============================================================================
*/
