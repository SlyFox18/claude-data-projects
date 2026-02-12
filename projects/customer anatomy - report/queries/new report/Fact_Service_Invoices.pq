/*
============================================================================
FACT_SERVICE_INVOICES - SERVICE/WORKSHOP INVOICE FACT TABLE
============================================================================

TABLE OVERVIEW:
Purpose: Service/Workshop invoice fact table for Customer Anatomy report - Service department
Grain: One row per Service Counter invoice (InvoiceNumber is unique within Service module)
Source: Invoice (Lakehouse table from df_Invoice_Raw dataflow)
Filter: ModuleType = 'W' (Workshop/Service module invoices only)
Deduplication: Groups by InvoiceNumber to handle any duplicate records in source
Refresh Strategy: Transforms Invoice data with dimension key lookups

BUSINESS USE CASES:
* Customer Anatomy - Service: Service sales by customer with full cost breakdown
* Service Sales Performance: Invoice counts, revenue, and margin by customer/territory/class
* Service Profitability Analysis: Labour vs parts sales on service invoices
* YTD/PYTD Comparisons: Year-over-year service sales analysis
* Workshop Sales Tracking: Service counter transaction monitoring

KEY METRICS ENABLED:
* Labour Sales (LabourSaleValue - Revenue)
* Labour Cost (LabourCostValue)
* Labour Margin = LabourSaleValue - LabourCostValue
* Labour GP% = Labour Margin / Labour Sales
* Total Service Sales (including Parts + Labour + Sublet sold on service invoices)
* Invoice Counts
* Tax-Exempt Sales tracking

DIMENSIONAL RELATIONSHIPS:
* CustomerKey -> dim_CustomerList (via CustomerVehicleFlag logic + CustomerLookup fallback)
* InvoiceDateKey -> dim_DateTable (YYYYMMDD integer format)

CUSTOMER ANATOMY INTEGRATION:
Replaces the old Service_Data.pq aggregated approach with transaction-level detail:
- Old: Pre-aggregated by Account, Month, Year with temp tables and YTD/PYTD logic
- New: Invoice-level enabling drill-down to individual transactions

CUSTOMER ASSIGNMENT LOGIC (Updated 2026-02-09):
This table uses CustomerVehicleFlag from WKROFILE to properly categorize work:
- CustomerVehicleFlag = 'S' (Stock): Work on dealership-owned inventory (demos, PDI,
  damaged in transit, awaiting delivery). Assigned to CustomerKey = -9 (Stock Equipment).
- CustomerVehicleFlag = 'C' (Customer): Work on customer-owned equipment. Uses standard
  CustomerLookup matching via BillToAccount.
- No match found: Assigned to CustomerKey = -1 (Unknown Customer).

Join path to get CustomerVehicleFlag:
Invoice -> wkothsub (via InvoiceNumber) -> WKROFILE (via Branch + WorkOrder)

This logic reduced Unknown Customer revenue from ~$19M to ~$2.3M by properly categorizing
~$17M of stock equipment work that was previously showing as Unknown.

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA - INVOICE TABLE FROM LAKEHOUSE
    // ========================================================================

    Source = Invoice,

    // ========================================================================
    // FILTER FOR SERVICE MODULE INVOICES ONLY
    // ========================================================================
    // ModuleType = 'W' indicates Workshop/Service counter invoices
    // Filter to 3-year scope (2022+) matching Invoice table for consistency
    // This matches the old query: Invoice.module_type = 'W'

    FilterServiceModule = Table.SelectRows(Source, each
        [ModuleType] = "W" and
        [InvoiceDate] >= #datetime(2022, 1, 1, 0, 0, 0)),

    // ========================================================================
    // DEDUPLICATE BY INVOICE NUMBER
    // ========================================================================
    // The Invoice source may contain duplicate records for the same InvoiceNumber
    // (from multiple ETL loads or line-level data). This step ensures uniqueness.
    // Using Table.Group to aggregate - taking MAX of financial values to handle
    // any cases where duplicates might have different amounts (though they shouldn't).
    // Text fields use List.First (all duplicates should have same values).

    DeduplicateInvoices = Table.Group(FilterServiceModule, {"InvoiceNumber"}, {
        {"InvoiceDate", each List.Max([InvoiceDate]), type nullable datetime},
        {"ModuleType", each List.First([ModuleType]), type nullable text},
        {"Branch", each List.First([Branch]), type nullable text},
        {"BillToAccount", each List.First([BillToAccount]), type nullable text},
        {"CompanyName", each List.First([CompanyName]), type nullable text},
        {"CustomerNumber", each List.First([CustomerNumber]), type nullable text},
        {"InvoiceType", each List.First([InvoiceType]), type nullable text},
        // Financial fields - SUM in case of line-level duplicates, MAX if header duplicates
        {"LabourCostValue", each List.Sum([LabourCostValue]), type nullable number},
        {"LabourSaleValue", each List.Sum([LabourSaleValue]), type nullable number},
        {"PartsCostValue", each List.Sum([PartsCostValue]), type nullable number},
        {"PartsSaleValue", each List.Sum([PartsSaleValue]), type nullable number},
        {"SubletCostValue", each List.Sum([SubletCostValue]), type nullable number},
        {"SubletSaleValue", each List.Sum([SubletSaleValue]), type nullable number},
        {"OtherSaleValue", each List.Sum([OtherSaleValue]), type nullable number},
        {"GST", each List.Sum([GST]), type nullable number},
        {"PaidCash", each List.Sum([PaidCash]), type nullable number},
        {"PaidCreditCard", each List.Sum([PaidCreditCard]), type nullable number},
        {"PaidCheque", each List.Sum([PaidCheque]), type nullable number},
        {"PaymentMethod", each List.First([PaymentMethod]), type nullable text}
    }),

    // ========================================================================
    // DATE KEY GENERATION - FOR DIM_DATETABLE RELATIONSHIP
    // ========================================================================

    // Add InvoiceDateKey in YYYYMMDD format for date dimension relationship
    AddInvoiceDateKey = Table.AddColumn(DeduplicateInvoices, "InvoiceDateKey", each
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
    // STEP 1: GET CUSTOMERVEHICLEFLAG VIA WKOTHSUB -> WKROFILE
    // ========================================================================
    // CustomerVehicleFlag identifies whether work is on:
    // - 'S' = Stock (dealership-owned equipment: demos, PDI, damaged in transit)
    // - 'C' = Customer (customer-owned equipment)
    //
    // Join path: Invoice -> wkothsub (via InvoiceNumber) -> WKROFILE (via Branch + WorkOrder)
    //
    // IMPORTANT: wkothsub has multiple rows per InvoiceNumber (one per job), so we must
    // create a distinct lookup table first to avoid duplicating invoice rows.

    // Create distinct InvoiceNumber -> WorkOrder + Branch lookup from wkothsub
    // This ensures one row per InvoiceNumber (takes first WorkOrder if multiple exist)
    WkothsubDistinct = Table.Group(wkothsub, {"InvoiceNumber"}, {
        {"WorkOrder", each List.First([WorkOrder]), type nullable text},
        {"WkothsubBranch", each List.First([Branch]), type nullable text}
    }),

    // Join to the distinct wkothsub lookup
    JoinWkothsub = Table.NestedJoin(
        AddInvoiceMonth, {"InvoiceNumber"},
        WkothsubDistinct, {"InvoiceNumber"},
        "WkothsubMatch", JoinKind.LeftOuter),

    // Expand WorkOrder from wkothsub (now guaranteed one row per invoice)
    ExpandWorkOrder = Table.ExpandTableColumn(JoinWkothsub, "WkothsubMatch",
        {"WorkOrder", "WkothsubBranch"},
        {"WorkOrder_Lookup", "WorkOrder_Branch"}),

    // Prepare lookup keys - use invoice's Branch if WorkOrder_Branch is null
    AddWorkOrderForLookup = Table.AddColumn(ExpandWorkOrder, "WorkOrderKey", each
        Text.Trim(Text.From([WorkOrder_Lookup] ?? "")), type text),

    AddBranchForLookup = Table.AddColumn(AddWorkOrderForLookup, "BranchKey", each
        if [WorkOrder_Branch] <> null and [WorkOrder_Branch] <> ""
        then Text.Trim(Text.From([WorkOrder_Branch]))
        else Text.Trim(Text.From([Branch] ?? "")), type text),

    // Join to WKROFILE to get CustomerVehicleFlag
    JoinWKROFILE = Table.NestedJoin(
        AddBranchForLookup, {"BranchKey", "WorkOrderKey"},
        WKROFILE, {"Branch", "WorkOrder"},
        "WKROFILEMatch", JoinKind.LeftOuter),

    // Expand CustomerVehicleFlag from WKROFILE
    ExpandCustomerVehicleFlag = Table.ExpandTableColumn(JoinWKROFILE, "WKROFILEMatch",
        {"CustomerVehicleFlag"},
        {"CustomerVehicleFlag"}),

    // Remove temporary lookup columns
    RemoveWorkOrderLookupCols = Table.RemoveColumns(ExpandCustomerVehicleFlag, {
        "WorkOrder_Lookup", "WorkOrder_Branch", "WorkOrderKey", "BranchKey"
    }),

    // ========================================================================
    // STEP 2: CUSTOMER KEY LOOKUP WITH CUSTOMERVEHICLEFLAG PRIORITY
    // ========================================================================
    // Customer assignment priority:
    // 1. If CustomerVehicleFlag = 'S' -> CustomerKey = -9 (Stock Equipment)
    // 2. If CustomerVehicleFlag = 'C' or null -> Use CustomerLookup via BillToAccount
    // 3. If CustomerLookup doesn't match -> CustomerKey = -1 (Unknown Customer)

    // Prepare BillToAccount for matching (uppercase for ContactID compatibility)
    AddMatchKey = Table.AddColumn(RemoveWorkOrderLookupCols, "BillToAccount_Upper", each
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

    // Apply CustomerVehicleFlag priority logic for CustomerKey assignment
    // Priority 1: Stock Equipment (CustomerVehicleFlag = 'S') -> CustomerKey = -9
    // Priority 2: Customer Equipment -> Use CustomerLookup result
    // Priority 3: No match -> CustomerKey = -1 (Unknown)
    AddCustomerKey = Table.AddColumn(ExpandCustomer, "CustomerKey", each
        if [CustomerVehicleFlag] = "S" then -9  // Stock Equipment
        else if [CustomerKey_Lookup] <> null then [CustomerKey_Lookup]  // Matched customer
        else -1,  // Unknown Customer
        Int64.Type),

    // Add IsStockEquipment flag for filtering/reporting
    AddIsStockEquipment = Table.AddColumn(AddCustomerKey, "IsStockEquipment", each
        [CustomerVehicleFlag] = "S", type logical),

    // Remove temporary matching columns
    RemoveMatchingColumns = Table.RemoveColumns(AddIsStockEquipment, {
        "BillToAccount_Upper", "CustomerKey_Lookup"
    }),

    // ========================================================================
    // LABOUR MARGIN CALCULATION
    // ========================================================================

    // Calculate Labour Gross Margin (primary for service invoices)
    AddLabourMargin = Table.AddColumn(RemoveMatchingColumns, "LabourMargin", each
        (if [LabourSaleValue] = null then 0 else [LabourSaleValue]) -
        (if [LabourCostValue] = null then 0 else [LabourCostValue]),
        type number),

    // Calculate Total Labour Sales
    AddTotalLabourSales = Table.AddColumn(AddLabourMargin, "TotalLabourSales", each
        (if [LabourSaleValue] = null then 0 else [LabourSaleValue]),
        type number),

    // ========================================================================
    // TOTAL INVOICE CALCULATIONS (ALL CATEGORIES)
    // ========================================================================
    // Service invoices may also have Parts, Sublet, or Other charges

    AddTotalNetSales = Table.AddColumn(AddTotalLabourSales, "TotalNetSales", each
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

        // Customer classification (Stock Equipment vs Customer Equipment)
        "CustomerVehicleFlag", "IsStockEquipment",

        // Date attributes
        "InvoiceDate", "InvoiceYear", "InvoiceMonth",

        // Organization
        "Branch",

        // Classification
        "InvoiceType", "ModuleType",

        // Financial - Labour (Primary for this fact table)
        "LabourCostValue", "LabourSaleValue",
        "TotalLabourSales", "LabourMargin",

        // Financial - Other categories (secondary, may have charges on service invoices)
        "PartsCostValue", "PartsSaleValue",
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
        {"CustomerVehicleFlag", type text},
        {"IsStockEquipment", type logical},
        {"InvoiceDate", type datetime},
        {"InvoiceYear", Int64.Type},
        {"InvoiceMonth", Int64.Type},
        {"Branch", type text},
        {"InvoiceType", type text},
        {"ModuleType", type text},
        {"LabourCostValue", type number},
        {"LabourSaleValue", type number},
        {"TotalLabourSales", type number},
        {"LabourMargin", type number},
        {"PartsCostValue", type number},
        {"PartsSaleValue", type number},
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
FACT_SERVICE_INVOICES - IMPLEMENTATION NOTES
============================================================================

DATAFLOW REQUIREMENTS (Updated 2026-02-09):
This query requires these Lakehouse table references in the dataflow:

1. **Invoice** (already exists)
   - Reference to: LH_Master_Data > Invoice
   - Primary source for service invoices

2. **wkothsub** (NEW - must add to dataflow)
   - Reference to: LH_Master_Data > wkothsub
   - Job-level data - provides WorkOrder for CustomerVehicleFlag lookup

3. **WKROFILE** (NEW - must add to dataflow)
   - Reference to: LH_Master_Data > WKROFILE
   - Work order master - provides CustomerVehicleFlag

4. **CustomerLookup** (already exists)
   - Reference to: LH_Master_Data > CustomerLookup
   - Bridge table for customer matching

5. **dim_CustomerList** (already exists)
   - Reference to: LH_Master_Data > dim_CustomerList
   - Must include CustomerKey = -9 (Stock Equipment)

DATAFLOW STRUCTURE:
```
Dataflow: df_CustomerAnatomy_Facts
├── Invoice (Lakehouse reference)
├── wkothsub (Lakehouse reference) - NEW!
├── WKROFILE (Lakehouse reference) - NEW!
├── CustomerLookup (Lakehouse reference)
├── dim_CustomerList (Lakehouse reference)
└── Fact_Service_Invoices (this query)
```

============================================================================
CUSTOMER ASSIGNMENT LOGIC (Updated 2026-02-09)
============================================================================

PROBLEM SOLVED:
~$19M of service revenue was showing as "Unknown Customer" because BillToAccount = '0'
for work on dealership-owned stock equipment. These are legitimate business transactions
(PDI, demos, damaged units, etc.) but have no customer to bill.

SOLUTION - CUSTOMERVEHICLEFLAG:
WKROFILE.CustomerVehicleFlag identifies the type of equipment:
- 'S' = Stock (dealership-owned): demos, PDI, damaged in transit, awaiting delivery
- 'C' = Customer (customer-owned): regular customer work

CUSTOMER KEY ASSIGNMENT PRIORITY:
1. CustomerVehicleFlag = 'S' -> CustomerKey = -9 (Stock Equipment)
2. CustomerVehicleFlag = 'C' or null -> Use CustomerLookup via BillToAccount
3. CustomerLookup doesn't match -> CustomerKey = -1 (Unknown Customer)

EXPECTED RESULTS:
- Unknown Customer reduced from ~$19M to ~$2.3M (88% reduction)
- Stock Equipment shows ~$17M in legitimate dealership work
- Remaining Unknown ($2.3M) represents true data quality issues to investigate

NEW COLUMNS ADDED:
- CustomerVehicleFlag: 'S' = Stock, 'C' = Customer (from WKROFILE)
- IsStockEquipment: Boolean flag for filtering (true when CustomerVehicleFlag = 'S')

============================================================================

REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_Service_Invoices[CustomerKey] -> dim_CustomerList[CustomerKey] (Many-to-One)
2. Fact_Service_Invoices[InvoiceDateKey] -> dim_DateTable[DateKey] (Many-to-One)

KEY DAX MEASURES TO CREATE:

-- Invoice Count
Service Invoice Count = COUNTROWS(Fact_ServiceSales)

-- Service Labour Sales (Primary metric)
Service Labour Sales = SUM(Fact_ServiceSales[LabourSaleValue])

-- Service Labour Cost
Service Labour Cost = SUM(Fact_ServiceSales[LabourCostValue])

-- Service Labour Margin
Service Labour Margin = SUM(Fact_ServiceSales[LabourMargin])
-- OR: [Service Labour Sales] - [Service Labour Cost]

-- Service Labour GP%
Service Labour GP% = DIVIDE([Service Labour Margin], [Service Labour Sales], 0)

-- Total Service Sales (including Parts/Sublet/Other on service invoices)
Service Invoice Total Sales = SUM(Fact_ServiceSales[TotalNetSales])

-- YTD/PYTD MEASURES (using dim_DateTable):

-- Service Labour Sales YTD
Service Labour Sales YTD =
CALCULATE(
    [Service Labour Sales],
    DATESYTD(dim_DateTable[Date])
)

-- Service Labour Sales PYTD (Prior Year-to-Date)
Service Labour Sales PYTD =
CALCULATE(
    [Service Labour Sales],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

-- Service Labour Margin YTD
Service Labour Margin YTD =
CALCULATE(
    [Service Labour Margin],
    DATESYTD(dim_DateTable[Date])
)

-- Service Labour Margin PYTD
Service Labour Margin PYTD =
CALCULATE(
    [Service Labour Margin],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

-- Service Labour GP% YTD
Service Labour GP% YTD = DIVIDE([Service Labour Margin YTD], [Service Labour Sales YTD], 0)

-- Service Labour GP% PYTD
Service Labour GP% PYTD = DIVIDE([Service Labour Margin PYTD], [Service Labour Sales PYTD], 0)

SUNDRY PARTS HANDLING:
The old Service_Data.pq had complex logic for "sundry" parts from InTrans
with franchise IN ('ZP', 'ZS'). This can be handled via:
1. Fact_Parts_Detail (line-item from InTrans) for drill-down
2. DAX measures filtering InTrans by franchise if needed
3. The @IncludeMisc parameter logic can be a DAX slicer

COMPARISON TO OLD REPORT:
Old Service_Data.pq:
- Used temp tables (#ServiceSalesData, #PYTDServiceSalesData, etc.)
- Pre-aggregated by Account, Month, Year
- Calculated YTD and PYTD in SQL
- Limited drill-down capability
- Included sundry parts exclusion logic

New Fact_ServiceSales:
- Invoice-level grain (transaction detail)
- Customer dimension lookup for proper star schema
- DAX handles YTD/PYTD calculations dynamically
- Full drill-down to individual invoices
- Sundry handling via Fact_Parts_Detail if needed

============================================================================
*/
