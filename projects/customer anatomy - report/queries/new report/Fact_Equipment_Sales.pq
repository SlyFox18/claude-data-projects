/*
============================================================================
FACT_EQUIPMENT_SALES - EQUIPMENT/VEHICLE SALES FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Equipment sales fact table for Customer Anatomy report - Sales department
Grain: One row per sold equipment unit (StockNumber is unique)
Source: Raw_VhStock (Lakehouse table from df_VHSTOCK_Raw dataflow)
Refresh Strategy: Transforms Raw_VhStock data with dimension key lookups

🎯 BUSINESS USE CASES:
• Customer Anatomy - Sales: Equipment sales by customer with full cost breakdown
• Sales Performance: Unit counts, revenue, and margin by customer/territory/class
• Profitability Analysis: Sales value vs total cost analysis
• Trade-In Analysis: Trade allowance tracking by customer
• YTD/PYTD Comparisons: Year-over-year equipment sales analysis

📊 KEY METRICS ENABLED:
• Sales Value (Revenue)
• Total Base Cost (13 cost components from VhStock)
• After-Sales Cost (via DAX from VhTrans where AfterSalesActivity = 'Y')
• Gross Margin = Sales Value - Total Cost
• GP% = Gross Margin / Sales Value
• Unit Counts

🔗 DIMENSIONAL RELATIONSHIPS:
• CustomerKey → dim_CustomerList (via OwnerContactCode lookup)
• SaleDateKey → dim_DateTable (YYYYMMDD integer format)
• StockNumber → VhTrans (for after-sales costs via DAX)

📈 CUSTOMER ANATOMY INTEGRATION:
Replaces the old Sales_Data_YTD.pq aggregated approach with transaction-level detail:
- Old: Pre-aggregated by Account, Month, Year
- New: Transaction-level enabling drill-down to individual equipment sales

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA - RAW VHSTOCK FROM LAKEHOUSE
    // ========================================================================

    Source = Raw_VhStock,

    // ========================================================================
    // DATE KEY GENERATION - FOR DIM_DATETABLE RELATIONSHIP
    // ========================================================================

    // ========================================================================
    // DATE FILTERING - FOR CONSISTENCY WITH OTHER FACT TABLES
    // ========================================================================
    // Filter to 3-year scope (2022+) matching Invoice table for consistency

    FilterByDate = Table.SelectRows(Source, each
        [SaleDate] >= #datetime(2022, 1, 1, 0, 0, 0)),

    // Add SaleDateKey in YYYYMMDD format for date dimension relationship
    AddSaleDateKey = Table.AddColumn(FilterByDate, "SaleDateKey", each
        if [SaleDate] = null or [SaleDate] = "" then null
        else try
            Date.Year([SaleDate]) * 10000 + Date.Month([SaleDate]) * 100 + Date.Day([SaleDate])
        otherwise null,
        Int64.Type),

    // Add SaleYear and SaleMonth for easier filtering/grouping
    AddSaleYear = Table.AddColumn(AddSaleDateKey, "SaleYear", each
        if [SaleDate] = null or [SaleDate] = "" then null else try Date.Year([SaleDate]) otherwise null, Int64.Type),

    AddSaleMonth = Table.AddColumn(AddSaleYear, "SaleMonth", each
        if [SaleDate] = null or [SaleDate] = "" then null else try Date.Month([SaleDate]) otherwise null, Int64.Type),

    // ========================================================================
    // CUSTOMER KEY LOOKUP - FOR DIM_CUSTOMERLIST RELATIONSHIP
    // ========================================================================
    // Join to dim_CustomerList to get CustomerKey
    // OwnerContactCode in VhStock = ContactID in dim_CustomerList
    // NOTE: Adding explicit type conversion and trimming to ensure match
    
    // Ensure OwnerContactCode is text and trimmed
    CleanOwnerContactCode = Table.AddColumn(AddSaleMonth, "OwnerContactCode_Clean", each
        Text.Trim(Text.From([OwnerContactCode] ?? "")), type text),

    JoinCustomer = Table.NestedJoin(
        CleanOwnerContactCode, {"OwnerContactCode_Clean"},
        dim_CustomerList, {"ContactID"},
        "CustomerMatch", JoinKind.LeftOuter),

    // Extract CustomerKey from the join
    ExpandCustomerKey = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
        {"CustomerKey", "AccountNumber", "Territory", "Account_Class"},
        {"CustomerKey", "AccountNumber", "Territory", "AccountClass"}),

    // Handle unmatched customers (assign -1 for Unknown)
    HandleUnknownCustomer = Table.ReplaceValue(ExpandCustomerKey, null, -1,
        Replacer.ReplaceValue, {"CustomerKey"}),
    
    // Remove the temporary cleaning column
    RemoveCleaningColumn = Table.RemoveColumns(HandleUnknownCustomer, {"OwnerContactCode_Clean"}),

    // ========================================================================
    // COST CALCULATIONS - BASE COSTS FROM VHSTOCK
    // ========================================================================

    // Calculate Total Base Cost (13 cost components from VhStock)
    // Note: After-sales costs from VhTrans will be added via DAX
    AddTotalBaseCost = Table.AddColumn(RemoveCleaningColumn, "TotalBaseCost", each
        (if [RetailCost] = null then 0 else [RetailCost]) +
        (if [WholesaleCost] = null then 0 else [WholesaleCost]) +
        (if [PredeliveryCost] = null then 0 else [PredeliveryCost]) +
        (if [RepairCost] = null then 0 else [RepairCost]) +
        (if [AccessoryCost] = null then 0 else [AccessoryCost]) +
        (if [OtherCost] = null then 0 else [OtherCost]) +
        (if [RegistrationFees] = null then 0 else [RegistrationFees]) +
        (if [LotFees] = null then 0 else [LotFees]) +
        (if [StampDuty] = null then 0 else [StampDuty]) +
        (if [TransferFees] = null then 0 else [TransferFees]) +
        (if [OptionCost] = null then 0 else [OptionCost]) +
        (if [PaintCost] = null then 0 else [PaintCost]) +
        (if [TrimCost] = null then 0 else [TrimCost]) +
        (if [ChargeCost] = null then 0 else [ChargeCost]) +
        (if [AfterMarketCost] = null then 0 else [AfterMarketCost]),
        type number),

    // Add Trade-In Total (for cost analysis)
    AddTradeInTotal = Table.AddColumn(AddTotalBaseCost, "TotalTradeAllowance", each
        (if [TradeAllowance] = null then 0 else [TradeAllowance]) +
        (if [PreTradeAllowance] = null then 0 else [PreTradeAllowance]),
        type number),

    // ========================================================================
    // FINAL COLUMN SELECTION AND ORDERING
    // ========================================================================

    SelectColumns = Table.SelectColumns(AddTradeInTotal, {
        // Keys
        "StockNumber", "CustomerKey", "SaleDateKey",

        // Customer attributes (denormalized for performance)
        "AccountNumber", "Territory", "AccountClass",

        // Date attributes
        "SaleDate", "SaleYear", "SaleMonth",

        // Equipment attributes
        "Make", "Model", "Year", "VIN", "EngineNumber", "Status",

        // Financial - Revenue
        "SalesValue",

        // Financial - Costs (individual components for drill-down)
        "RetailCost", "WholesaleCost", "PredeliveryCost", "RepairCost",
        "AccessoryCost", "OtherCost", "RegistrationFees", "LotFees",
        "StampDuty", "TransferFees", "OptionCost", "PaintCost",
        "TrimCost", "ChargeCost", "AfterMarketCost",

        // Financial - Calculated
        "TotalBaseCost", "TotalTradeAllowance",

        // Trade-In (individual components)
        "TradeAllowance", "PreTradeAllowance",

        // Original owner reference (for troubleshooting)
        "OwnerContactCode"
    }),

    // Set final data types
    SetTypes = Table.TransformColumnTypes(SelectColumns, {
        {"StockNumber", Int64.Type},
        {"CustomerKey", Int64.Type},
        {"SaleDateKey", Int64.Type},
        {"AccountNumber", type text},
        {"Territory", type text},
        {"AccountClass", type text},
        {"SaleDate", type datetime},
        {"SaleYear", Int64.Type},
        {"SaleMonth", Int64.Type},
        {"Make", type text},
        {"Model", type text},
        {"Year", Int64.Type},
        {"VIN", type text},
        {"EngineNumber", type text},
        {"Status", type text},
        {"SalesValue", type number},
        {"RetailCost", type number},
        {"WholesaleCost", type number},
        {"PredeliveryCost", type number},
        {"RepairCost", type number},
        {"AccessoryCost", type number},
        {"OtherCost", type number},
        {"RegistrationFees", type number},
        {"LotFees", type number},
        {"StampDuty", type number},
        {"TransferFees", type number},
        {"OptionCost", type number},
        {"PaintCost", type number},
        {"TrimCost", type number},
        {"ChargeCost", type number},
        {"AfterMarketCost", type number},
        {"TotalBaseCost", type number},
        {"TotalTradeAllowance", type number},
        {"TradeAllowance", type number},
        {"PreTradeAllowance", type number},
        {"OwnerContactCode", type text}
    })

in
    SetTypes

/*
============================================================================
✅ FACT_EQUIPMENT_SALES - IMPLEMENTATION NOTES
============================================================================

🔗 REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_Equipment_Sales[CustomerKey] → dim_CustomerList[CustomerKey] (Many-to-One)
2. Fact_Equipment_Sales[SaleDateKey] → dim_DateTable[DateKey] (Many-to-One)
3. Fact_Equipment_Sales[StockNumber] → VhTrans[StockNumber] (One-to-Many, for after-sales)

📊 KEY DAX MEASURES TO CREATE:

-- Unit Count
Equipment Sales Count = COUNTROWS(Fact_Equipment_Sales)

-- Revenue
Equipment Sales Value = SUM(Fact_Equipment_Sales[SalesValue])

-- Base Cost (from VhStock)
Equipment Base Cost = SUM(Fact_Equipment_Sales[TotalBaseCost])

-- After-Sales Cost (from VhTrans)
Equipment After Sales Cost =
CALCULATE(
    SUMX(
        VhTrans,
        [WholesaleCost] + [RetailCost] + [PredeliveryCost] + [RepairCost] +
        [AccessoryCost] + [OtherCost] + [RegistrationFees] + [LotFees] +
        [TransferFees] + [OptionCost] + [PaintCost] + [TrimCost] +
        [ChargeCost] + [AfterMarketCost]
    ),
    VhTrans[AfterSalesActivity] = "Y"
)

-- Total Cost (Base + After-Sales)
Equipment Total Cost = [Equipment Base Cost] + [Equipment After Sales Cost]

-- Margin
Equipment Margin = [Equipment Sales Value] - [Equipment Total Cost]

-- GP%
Equipment GP% = DIVIDE([Equipment Margin], [Equipment Sales Value], 0)

-- Trade Allowance
Equipment Trade Allowance = SUM(Fact_Equipment_Sales[TotalTradeAllowance])

⏱️ YTD/PYTD MEASURES (using dim_DateTable):
-- Sales YTD
Equipment Sales YTD =
CALCULATE(
    [Equipment Sales Value],
    DATESYTD(dim_DateTable[Date])
)

-- Sales PYTD (Prior Year-to-Date)
Equipment Sales PYTD =
CALCULATE(
    [Equipment Sales Value],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

============================================================================
*/
