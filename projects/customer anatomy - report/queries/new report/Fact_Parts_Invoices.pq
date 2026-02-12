/*
============================================================================
FACT_PARTS_INVOICES - PARTS COUNTER INVOICE FACT TABLE
============================================================================

TABLE OVERVIEW:
Purpose: Parts invoice fact table for Customer Anatomy report - Parts department
Grain: One row per Parts Counter invoice (InvoiceNumber is unique within Parts module)
Source: Invoice (Lakehouse table from df_Invoice_Raw dataflow)
Filter: ModuleType = 'I' (Parts/Inventory module invoices only)
Refresh Strategy: Transforms Invoice data with dimension key lookups

BUSINESS USE CASES:
* Customer Anatomy - Parts: Parts sales by customer with full cost breakdown
* Parts Sales Performance: Invoice counts, revenue, and margin by customer/territory/class
* Parts Profitability Analysis: Sales vs cost analysis for parts department
* YTD/PYTD Comparisons: Year-over-year parts sales analysis
* Counter Sales Tracking: Parts counter transaction monitoring

KEY METRICS ENABLED:
* Parts Sales (PartsNetSales - Revenue)
* Parts Cost (PartsCost)
* Parts Margin = PartsNetSales - PartsCost
* Parts GP% = Parts Margin / Parts Sales
* Invoice Counts
* Tax-Exempt Sales tracking

DIMENSIONAL RELATIONSHIPS:
* CustomerKey -> dim_CustomerList (via ARAccountNumber lookup)
* InvoiceDateKey -> dim_DateTable (YYYYMMDD integer format)

CUSTOMER ANATOMY INTEGRATION:
Replaces the old Parts_Data.pq aggregated approach with transaction-level detail:
- Old: Pre-aggregated by Account, Month, Year with temp tables
- New: Invoice-level enabling drill-down to individual transactions

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA - INVOICE TABLE FROM LAKEHOUSE
    // ========================================================================

    Source = Invoice,

    // ========================================================================
    // FILTER FOR PARTS MODULE INVOICES ONLY
    // ========================================================================
    // ModuleType = 'I' indicates Parts/Inventory counter invoices
    // This matches the old query: Invoice.module_type = 'I'

    FilterPartsModule = Table.SelectRows(Source, each [ModuleType] = "I"),

    // ========================================================================
    // DATE KEY GENERATION - FOR DIM_DATETABLE RELATIONSHIP
    // ========================================================================

    // Add InvoiceDateKey in YYYYMMDD format for date dimension relationship
    AddInvoiceDateKey = Table.AddColumn(FilterPartsModule, "InvoiceDateKey", each
        if [InvoiceDate] = null or [InvoiceDate] = "" then null
        else try
            Date.Year([InvoiceDate]) * 10000 + Date.Month([InvoiceDate]) * 100 + Date.Day([InvoiceDate])
        otherwise null,
        Int64.Type),

    // Add InvoiceYear and InvoiceMonth for easier filtering/grouping
    AddInvoiceYear = Table.AddColumn(AddInvoiceDateKey, "InvoiceYear", each
        if [InvoiceDate] = null then null else Date.Year([InvoiceDate]), Int64.Type),

    AddInvoiceMonth = Table.AddColumn(AddInvoiceYear, "InvoiceMonth", each
        if [InvoiceDate] = null then null else Date.Month([InvoiceDate]), Int64.Type),

    // ========================================================================
    // CUSTOMER KEY LOOKUP - SINGLE JOIN VIA CUSTOMERLOOKUP BRIDGE TABLE
    // ========================================================================
    // CustomerLookup contains both AccountNumber and ContactID as MatchKey
    // This replaces the dual-join pattern with a single efficient lookup
    // BillToAccount is uppercased to match ContactID format (AccountNumbers unaffected)

    // Prepare BillToAccount for matching (uppercase for ContactID compatibility)
    AddMatchKey = Table.AddColumn(AddInvoiceMonth, "BillToAccount_Upper", each
        Text.Upper(Text.Trim(Text.From([BillToAccount] ?? ""))), type text),

    // Single join to CustomerLookup bridge table
    JoinCustomer = Table.NestedJoin(
        AddMatchKey, {"BillToAccount_Upper"},
        CustomerLookup, {"MatchKey"},
        "CustomerMatch", JoinKind.LeftOuter),

    // Expand customer attributes (single expand, not nested)
    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName"},
        {"CustomerKey_Lookup", "ContactID", "Territory", "AccountClass", "CustomerDisplayName"}),

    // Handle unmatched customers (CustomerKey = -1 for Unknown Customer dimension row)
    AddCustomerKey = Table.AddColumn(ExpandCustomer, "CustomerKey", each
        if [CustomerKey_Lookup] = null then -1 else [CustomerKey_Lookup], Int64.Type),

    // Remove temporary matching columns
    RemoveMatchingColumns = Table.RemoveColumns(AddCustomerKey, {
        "BillToAccount_Upper", "CustomerKey_Lookup"
    }),

    // ========================================================================
    // PARTS MARGIN CALCULATION
    // ========================================================================

    // Calculate Parts Gross Margin
    AddPartsMargin = Table.AddColumn(RemoveMatchingColumns, "PartsMargin", each
        (if [PartsSaleValue] = null then 0 else [PartsSaleValue]) -
        (if [PartsCostValue] = null then 0 else [PartsCostValue]),
        type number),

    // Calculate Total Parts Sales
    AddTotalPartsSales = Table.AddColumn(AddPartsMargin, "TotalPartsSales", each
        (if [PartsSaleValue] = null then 0 else [PartsSaleValue]),
        type number),

    // ========================================================================
    // TOTAL INVOICE CALCULATIONS (ALL CATEGORIES)
    // ========================================================================
    // Parts invoices may also have small Labour, Sublet, or Other charges

    AddTotalNetSales = Table.AddColumn(AddTotalPartsSales, "TotalNetSales", each
        (if [PartsSaleValue] = null then 0 else [PartsSaleValue]) +
        (if [LabourSaleValue] = null then 0 else [LabourSaleValue]) +
        (if [SubletSaleValue] = null then 0 else [SubletSaleValue]) +
        (if [OtherSaleValue] = null then 0 else [OtherSaleValue]),
        type number),

    AddTotalCost = Table.AddColumn(AddTotalNetSales, "TotalCost", each
        (if [PartsCostValue] = null then 0 else [PartsCostValue]) +
        (if [LabourCostValue] = null then 0 else [LabourCostValue]) +
        (if [SubletCostValue] = null then 0 else [SubletCostValue]),
        type number),

    AddTotalMargin = Table.AddColumn(AddTotalCost, "TotalMargin", each
        [TotalNetSales] - [TotalCost],
        type number),

    // ========================================================================
    // FINAL COLUMN SELECTION AND ORDERING
    // ========================================================================

    SelectColumns = Table.SelectColumns(AddTotalMargin, {
        // Keys
        "InvoiceNumber", "CustomerKey", "InvoiceDateKey",

        // Customer attributes (denormalized for performance)
        "BillToAccount", "ContactID", "Territory", "AccountClass", "CustomerDisplayName",
        "CompanyName", "CustomerNumber",

        // Date attributes
        "InvoiceDate", "InvoiceYear", "InvoiceMonth",

        // Organization
        "Branch",

        // Classification
        "InvoiceType", "ModuleType",

        // Financial - Parts (Primary for this fact table)
        "PartsCostValue", "PartsSaleValue",
        "TotalPartsSales", "PartsMargin",

        // Financial - Other categories (secondary, may have small amounts)
        "LabourCostValue", "LabourSaleValue",
        "SubletCostValue", "SubletSaleValue",
        "OtherSaleValue",
        "GST",

        // Financial - Totals
        "TotalNetSales", "TotalCost", "TotalMargin",

        // Payment Methods
        "PaidCash", "PaidCreditCard", "PaidCheque", "PaymentMethod"
    }),

    // Set final data types
    SetTypes = Table.TransformColumnTypes(SelectColumns, {
        {"InvoiceNumber", type text},
        {"CustomerKey", Int64.Type},
        {"InvoiceDateKey", Int64.Type},
        {"BillToAccount", type text},
        {"ContactID", type text},
        {"Territory", type text},
        {"AccountClass", type text},
        {"CustomerDisplayName", type text},
        {"CompanyName", type text},
        {"CustomerNumber", type text},
        {"InvoiceDate", type datetime},
        {"InvoiceYear", Int64.Type},
        {"InvoiceMonth", Int64.Type},
        {"Branch", type text},
        {"InvoiceType", type text},
        {"ModuleType", type text},
        {"PartsCostValue", type number},
        {"PartsSaleValue", type number},
        {"TotalPartsSales", type number},
        {"PartsMargin", type number},
        {"LabourCostValue", type number},
        {"LabourSaleValue", type number},
        {"SubletCostValue", type number},
        {"SubletSaleValue", type number},
        {"OtherSaleValue", type number},
        {"GST", type number},
        {"TotalNetSales", type number},
        {"TotalCost", type number},
        {"TotalMargin", type number},
        {"PaidCash", type number},
        {"PaidCreditCard", type number},
        {"PaidCheque", type number},
        {"PaymentMethod", type text}
    })

in
    SetTypes

/*
============================================================================
FACT_PARTS_INVOICES - IMPLEMENTATION NOTES
============================================================================

REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_Parts_Invoices[CustomerKey] -> dim_CustomerList[CustomerKey] (Many-to-One)
2. Fact_Parts_Invoices[InvoiceDateKey] -> dim_DateTable[DateKey] (Many-to-One)

KEY DAX MEASURES TO CREATE:

-- Invoice Count
Parts Invoice Count = COUNTROWS(Fact_Parts_Invoices)

-- Parts Sales (Primary metric)
Parts Sales = SUM(Fact_Parts_Invoices[PartsNetSales])

-- Parts Cost
Parts Cost = SUM(Fact_Parts_Invoices[PartsCost])

-- Parts Margin
Parts Margin = SUM(Fact_Parts_Invoices[PartsMargin])
-- OR: [Parts Sales] - [Parts Cost]

-- Parts GP%
Parts GP% = DIVIDE([Parts Margin], [Parts Sales], 0)

-- Total Sales (including any Labour/Sublet/Other on Parts invoices)
Parts Invoice Total Sales = SUM(Fact_Parts_Invoices[TotalNetSales])

-- YTD/PYTD MEASURES (using dim_DateTable):

-- Parts Sales YTD
Parts Sales YTD =
CALCULATE(
    [Parts Sales],
    DATESYTD(dim_DateTable[Date])
)

-- Parts Sales PYTD (Prior Year-to-Date)
Parts Sales PYTD =
CALCULATE(
    [Parts Sales],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

-- Parts Margin YTD
Parts Margin YTD =
CALCULATE(
    [Parts Margin],
    DATESYTD(dim_DateTable[Date])
)

-- Parts Margin PYTD
Parts Margin PYTD =
CALCULATE(
    [Parts Margin],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

-- Parts GP% YTD
Parts GP% YTD = DIVIDE([Parts Margin YTD], [Parts Sales YTD], 0)

-- Parts GP% PYTD
Parts GP% PYTD = DIVIDE([Parts Margin PYTD], [Parts Sales PYTD], 0)

SUNDRY PARTS HANDLING:
The old Parts_Data.pq had complex logic for "sundry" parts from InTrans
with franchise IN ('ZP', 'ZS'). This can be handled via:
1. Fact_Parts_Detail (line-item from InTrans) for drill-down
2. DAX measures filtering InTrans by franchise if needed
3. The @IncludeMisc parameter logic can be a DAX slicer

COMPARISON TO OLD REPORT:
Old Parts_Data.pq:
- Used temp tables (#PartsSalesData, #PartsSundryData, etc.)
- Pre-aggregated by Account, Month, Year
- Calculated YTD and PYTD in SQL
- Limited drill-down capability

New Fact_Parts_Invoices:
- Invoice-level grain (transaction detail)
- Customer dimension lookup for proper star schema
- DAX handles YTD/PYTD calculations dynamically
- Full drill-down to individual invoices
- Sundry handling via Fact_Parts_Detail if needed

============================================================================
*/
