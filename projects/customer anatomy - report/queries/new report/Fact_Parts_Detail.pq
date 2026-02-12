/*
============================================================================
FACT_PARTS_DETAIL - PARTS COUNTER LINE ITEM FACT TABLE
============================================================================

TABLE OVERVIEW:
Purpose: Parts Counter line-item detail for Customer Anatomy report - Level 3 drill-down
Grain: One row per parts transaction line item on Parts Counter invoices (TransId is unique)
Source: Raw_InTrans_PartsCounter (pre-filtered at SQL level for optimal performance)
Filter: Parts Counter invoices only - filtering done at SQL level in raw table
Refresh Strategy: Uses pre-filtered raw table with SQL-level JOIN to Invoice

PERFORMANCE OPTIMIZATION (01/29/2026):
Version 1: Filtered InTrans by Type IN ('I', 'C') - 8.8M rows, 20+ min refresh
Version 2: Power Query join to Invoice - 2.4M rows, 18+ min refresh (PQ overhead)
Version 3 (CURRENT): Uses Raw_InTrans_PartsCounter with SQL-level JOIN - 2.4M rows, 2-4 min expected

BUSINESS USE CASES:
* Customer Anatomy - Parts Drill-Down (Level 3): "What parts did Customer X buy?"
* Parts Mix Analysis: What parts are selling to which customers
* Sundry Parts Tracking: ZP/ZS franchise items (miscellaneous parts)
* Part-level profitability by customer
* Drill-through from Fact_Parts_Invoices to see invoice line items

KEY METRICS ENABLED:
* Parts Sales (SaleValue - Revenue at line level)
* Parts Cost (CostValue)
* Parts Margin = SaleValue - CostValue (calculated)
* Parts GP% = Parts Margin / Parts Sales
* Quantity metrics (Qty)
* Sundry Part identification (Franchise ZP/ZS)

DIMENSIONAL RELATIONSHIPS:
* CustomerKey -> dim_CustomerList (via BillToAcc lookup)
* TransDateKey -> dim_DateTable (YYYYMMDD integer format)
* InvoiceNumber -> Fact_Parts_Invoices (for drill-through from Level 2)
* Branch -> dim_BranchLocation
* PartNumber -> dim_Parts

CUSTOMER ANATOMY INTEGRATION (3-Level Drill-Through):
- Level 1: Fact_CustomerPerformance (Customer X spent $5000 on parts)
- Level 2: Fact_Parts_Invoices (Customer X had 12 invoices)
- Level 3: Fact_Parts_Detail (Invoice #123 had these 5 parts...)

DATAFLOW REQUIREMENTS:
This query requires these Lakehouse table references in the dataflow:
1. Raw_InTrans_PartsCounter - Pre-filtered parts transactions (SQL-level JOIN to Invoice)
2. dim_CustomerList - For customer key lookup

============================================================================
*/

let
    // ========================================================================
    // SOURCE DATA - RAW_INTRANS_PARTSCOUNTER FROM LAKEHOUSE
    // ========================================================================
    // This raw table is pre-filtered at the SQL level with:
    // - INNER JOIN to Invoice on ref_no = document_no AND type = invo_type
    // - WHERE Invoice.module_type = 'I' (Parts Counter only)
    // - WHERE intrans.type IN ('I', 'C')
    // - WHERE trans_datetime >= 2022-01-01
    //
    // This eliminates the need for Power Query joins - data is already filtered!
    // Expected: ~2.4M rows, 2-4 min refresh (vs 18+ min with PQ join approach)

    Source = Raw_InTrans_PartsCounter,

    // ========================================================================
    // DATE KEY GENERATION - FOR DIM_DATETABLE RELATIONSHIP
    // ========================================================================

    // Add TransDateKey in YYYYMMDD format for date dimension relationship
    AddTransDateKey = Table.AddColumn(Source, "TransDateKey", each
        if [TransDatetime] = null or [TransDatetime] = "" then null
        else try
            Date.Year([TransDatetime]) * 10000 + Date.Month([TransDatetime]) * 100 + Date.Day([TransDatetime])
        otherwise null,
        Int64.Type),

    // Add TransYear and TransMonth for easier filtering/grouping
    AddTransYear = Table.AddColumn(AddTransDateKey, "TransYear", each
        if [TransDatetime] = null or [TransDatetime] = "" then null else try Date.Year([TransDatetime]) otherwise null, Int64.Type),

    AddTransMonth = Table.AddColumn(AddTransYear, "TransMonth", each
        if [TransDatetime] = null or [TransDatetime] = "" then null else try Date.Month([TransDatetime]) otherwise null, Int64.Type),

    // ========================================================================
    // CUSTOMER KEY LOOKUP - FOR DIM_CUSTOMERLIST RELATIONSHIP
    // ========================================================================
    // BillToAcc in InTrans = AccountNumber in dim_CustomerList
    // NOTE: Adding explicit type conversion and trimming to ensure match
    
    // Ensure BillToAcc is text and trimmed
    CleanBillToAcc = Table.AddColumn(AddTransMonth, "BillToAcc_Clean", each
        Text.Trim(Text.From([BillToAcc] ?? "")), type text),

    JoinCustomer = Table.NestedJoin(
        CleanBillToAcc, {"BillToAcc_Clean"},
        dim_CustomerList, {"AccountNumber"},
        "CustomerMatch", JoinKind.LeftOuter),

    // Extract CustomerKey and customer attributes from the join
    ExpandCustomerKey = Table.ExpandTableColumn(JoinCustomer, "CustomerMatch",
        {"CustomerKey", "ContactID", "Territory", "Account_Class", "DisplayName"},
        {"CustomerKey", "ContactID", "Territory", "AccountClass", "CustomerDisplayName"}),

    // Handle unmatched customers (assign -1 for Unknown)
    HandleUnknownCustomer = Table.ReplaceValue(ExpandCustomerKey, null, -1,
        Replacer.ReplaceValue, {"CustomerKey"}),
    
    // Remove the temporary cleaning column
    RemoveCleaningColumn = Table.RemoveColumns(HandleUnknownCustomer, {"BillToAcc_Clean"}),

    // ========================================================================
    // MARGIN CALCULATION
    // ========================================================================

    // Calculate Line Margin
    AddLineMargin = Table.AddColumn(RemoveCleaningColumn, "LineMargin", each
        (if [SaleValue] = null then 0 else [SaleValue]) -
        (if [CostValue] = null then 0 else [CostValue]),
        type number),

    // ========================================================================
    // SUNDRY INDICATOR - FOR CUSTOMER ANATOMY SUNDRY CALCULATIONS
    // ========================================================================
    // Old query used franchise IN ('ZP', 'ZS') for sundry parts

    AddIsSundry = Table.AddColumn(AddLineMargin, "IsSundryPart", each
        if [Franchise] = "ZP" or [Franchise] = "ZS" then true else false,
        type logical),

    // ========================================================================
    // FINAL COLUMN SELECTION AND ORDERING
    // ========================================================================
    // NOTE: Using minimal column set from Raw_InTrans_PartsCounter
    // Additional columns can be added once InTrans schema is verified

    SelectColumns = Table.SelectColumns(AddIsSundry, {
        // Keys
        "TransId", "CustomerKey", "TransDateKey",

        // Customer attributes (from dim_CustomerList join)
        "BillToAcc", "ContactID", "Territory", "AccountClass", "CustomerDisplayName",

        // Date attributes (calculated)
        "TransDatetime", "TransYear", "TransMonth",

        // Organization (from raw table)
        "Branch", "Franchise",

        // Part Information (from raw table)
        "PartNumber", "Description",

        // Classification (from raw table)
        "Type",

        // Reference Numbers (from raw table)
        "RONumber",
        "InvoiceNumber",

        // Quantity Metrics (from raw table)
        "Qty",

        // Financial - Line Level (from raw table + calculated)
        "SaleValue", "CostValue", "LineMargin",

        // Sundry Indicator (calculated)
        "IsSundryPart"
    }),

    // Set final data types
    SetTypes = Table.TransformColumnTypes(SelectColumns, {
        {"TransId", Int64.Type},
        {"CustomerKey", Int64.Type},
        {"TransDateKey", Int64.Type},
        {"BillToAcc", type text},
        {"ContactID", type text},
        {"Territory", type text},
        {"AccountClass", type text},
        {"CustomerDisplayName", type text},
        {"TransDatetime", type datetime},
        {"TransYear", Int64.Type},
        {"TransMonth", Int64.Type},
        {"Branch", type text},
        {"Franchise", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"Type", type text},
        {"RONumber", type text},
        {"InvoiceNumber", type text},
        {"Qty", type number},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"LineMargin", type number},
        {"IsSundryPart", type logical}
    })

in
    SetTypes

/*
============================================================================
FACT_PARTS_DETAIL - IMPLEMENTATION NOTES
============================================================================

🔧 DATAFLOW SETUP REQUIREMENTS:

**STEP 1: Create the Raw Table (One-time setup)**
1. Create new dataflow: df_InTrans_PartsCounter_Raw
2. Paste the Raw_InTrans_PartsCounter.pq query
3. Output destination: LH_Master_Data > Raw_InTrans_PartsCounter
4. Refresh schedule: Same as other Customer Anatomy raw tables

**STEP 2: Reference in Fact Table Dataflow**
This query requires these Lakehouse table references:

1. **Raw_InTrans_PartsCounter** (new - from Step 1)
   - Reference to: LH_Master_Data > Raw_InTrans_PartsCounter
   - Query name in dataflow: Raw_InTrans_PartsCounter
   - Pre-filtered at SQL level - no Invoice join needed!

2. **dim_CustomerList** (already exists)
   - Reference to: LH_Master_Data > dim_CustomerList
   - Query name in dataflow: dim_CustomerList

DATAFLOW STRUCTURE:
```
Dataflow: df_CustomerAnatomy_Facts (or similar)
├── Raw_InTrans_PartsCounter (Lakehouse reference) <-- NEW PRE-FILTERED TABLE
├── dim_CustomerList (Lakehouse reference)
└── Fact_Parts_Detail (this query)
```

EXPECTED PERFORMANCE:
- Raw table (Raw_InTrans_PartsCounter): ~2.4M rows, 2-4 min refresh
- Fact table (Fact_Parts_Detail): ~2.4M rows, 2-4 min refresh
- Total: 4-8 min (vs 20+ min with old approach)

============================================================================

REQUIRED RELATIONSHIPS IN SEMANTIC MODEL:
1. Fact_Parts_Detail[CustomerKey] -> dim_CustomerList[CustomerKey] (Many-to-One)
2. Fact_Parts_Detail[TransDateKey] -> dim_DateTable[DateKey] (Many-to-One)
3. Fact_Parts_Detail[Branch] -> dim_BranchLocation[BranchID] (Many-to-One)
4. Fact_Parts_Detail[PartNumber] -> dim_Parts[PartNumber] (Many-to-One)
5. Fact_Parts_Detail[InvoiceNumber] -> Fact_Parts_Invoices[InvoiceNumber] (Many-to-One) <-- For drill-through

KEY DAX MEASURES TO CREATE:

-- Line Count
Parts Detail Lines = COUNTROWS(Fact_Parts_Detail)

-- Parts Detail Sales
Parts Detail Sales = SUM(Fact_Parts_Detail[SaleValue])

-- Parts Detail Cost
Parts Detail Cost = SUM(Fact_Parts_Detail[CostValue])

-- Parts Detail Margin
Parts Detail Margin = SUM(Fact_Parts_Detail[LineMargin])

-- Parts Detail GP%
Parts Detail GP% = DIVIDE([Parts Detail Margin], [Parts Detail Sales], 0)

-- Quantity Sold
Parts Qty Sold = SUM(Fact_Parts_Detail[Qty])

-- SUNDRY PARTS MEASURES (for Customer Anatomy @IncludeMisc logic):

-- Sundry Sales (franchise IN ('ZP', 'ZS'))
Parts Sundry Sales =
CALCULATE(
    [Parts Detail Sales],
    Fact_Parts_Detail[IsSundryPart] = TRUE
)

-- Sundry Cost
Parts Sundry Cost =
CALCULATE(
    [Parts Detail Cost],
    Fact_Parts_Detail[IsSundryPart] = TRUE
)

-- Parts Sales Excluding Sundry
Parts Sales Ex Sundry = [Parts Detail Sales] - [Parts Sundry Sales]

-- Parts Cost Excluding Sundry
Parts Cost Ex Sundry = [Parts Detail Cost] - [Parts Sundry Cost]

-- YTD/PYTD MEASURES:

-- Parts Detail Sales YTD
Parts Detail Sales YTD =
CALCULATE(
    [Parts Detail Sales],
    DATESYTD(dim_DateTable[Date])
)

-- Parts Detail Sales PYTD
Parts Detail Sales PYTD =
CALCULATE(
    [Parts Detail Sales],
    SAMEPERIODLASTYEAR(DATESYTD(dim_DateTable[Date]))
)

DRILL-DOWN INTEGRATION (3-Level Architecture):

Level 1: Fact_CustomerPerformance
  "Customer X spent $5000 on parts last quarter"
       ↓ Click on customer
Level 2: Fact_Parts_Invoices
  "Customer X had 12 invoices: Invoice #123 ($450), Invoice #124 ($380)..."
       ↓ Click on invoice
Level 3: Fact_Parts_Detail (THIS TABLE)
  "Invoice #123 had 5 line items: Oil Filter ($50), Air Filter ($35)..."

Link Field: InvoiceNumber (in Fact_Parts_Detail) = InvoiceNumber (in Fact_Parts_Invoices)

COMPARISON TO OLD REPORT:

Old Parts_Data.pq approach:
- Aggregated data only (no line-item detail)
- Used Invoice.parts_sale_val totals
- InTrans only used for sundry subtraction
- No drill-down capability

New Fact_Parts_Detail approach:
- Full line-item detail for drill-through
- Inner join to Invoice (ModuleType = 'I') ensures only Parts Counter items
- IsSundryPart flag for include/exclude via DAX
- Enables "what parts did this customer buy?" analysis
- Part-level profitability by customer

OPTIMIZATION HISTORY (01/29/2026):

Version 1 (broken):
- Filter: Type IN ('I', 'C') only
- Result: 8.8M rows, 20+ min refresh
- Problem: Included Service work order parts, transfers, etc.

Version 2 (correct but slow):
- Power Query join to Invoice WHERE ModuleType = 'I'
- Result: 2.4M rows (correct!), 18+ min refresh
- Problem: PQ still loads all 10M+ InTrans rows before filtering

Version 3 (CURRENT - optimal):
- Uses Raw_InTrans_PartsCounter with SQL-level JOIN
- Result: 2.4M rows, 2-4 min expected refresh
- SQL does the filtering BEFORE data reaches Power Query!

============================================================================
*/
