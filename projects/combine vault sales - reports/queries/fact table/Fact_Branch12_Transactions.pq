/*
============================================================================
FACT_BRANCH12_TRANSACTIONS - BRANCH 12 PARTS SALES & INVENTORY TRANSACTIONS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Transaction history for Branch 12 (R12 - Mobile Parts Trailer) with specialized business logic for transfer-based sales
Grain: One row per part transaction (transfer out = sale, transfer in = inventory addition)
Refresh Strategy: Incremental refresh (recommended) or controlled historical load
Target Performance: <1 minute for 3-year history (optimized column set)
Source Dependencies: InTrans (transaction source), dim_Branch12_Parts (part lookup), dim_DateTable (date lookup)

🎯 CRITICAL BRANCH 12 BUSINESS LOGIC:
• NEGATIVE Qty = SALE (parts transferred OUT to physical stores)
• POSITIVE Qty = INVENTORY ADDITION (parts transferred IN for restocking)
• Sales calculations use ABSOLUTE VALUE of negative quantities
• Cost values are stored as NEGATIVE for sales, must convert to positive
• This is unique to Branch 12 as a mobile inventory distribution point

🔧 CALCULATION LOGIC:
• SalesQty = ABS(Qty) when Qty < 0, else 0
• SaleValue = SellPrice1 × SalesQty
• CostValue = ABS(COST_VAL) when COST_VAL < 0
• MarginDollars = SaleValue - CostValue
• IsSale flag = Qty < 0 (critical for filtering)

📊 KEY FEATURES:
• Branch 12-specific business logic correctly implemented
• Pre-calculated sales metrics accounting for negative quantity logic
• Proper cost value conversion (negative to positive)
• IsSale flag for easy sales vs inventory addition filtering
• Streamlined column set for optimal performance and CU efficiency
• Proper surrogate key relationships to dimensions

🔗 DIMENSIONAL RELATIONSHIPS:
• fact_Branch12_Transactions[DateKey] → dim_DateTable[DateKey] (Many-to-One)
• fact_Branch12_Transactions[PartNumberKey] → dim_Branch12_Parts[PartNumberKey] (Many-to-One)

📈 DASHBOARD APPLICATIONS:
• KPI Cards: Rolling 12-month sales, costs, inventory value (sales only)
• Monthly Trend Charts: Sales by month with previous year comparison
• Parts Analysis Table: Part-level sales detail with proper metrics
• Transaction Analysis: Sales vs inventory additions tracking
• Margin Analysis: Cost recovery and pricing effectiveness (sales only)
• Inventory Planning: Transfer patterns and stocking optimization

============================================================================
*/

let
    // ========================================================================
    // STEP 1: REFERENCE DIMENSION TABLES FOR SURROGATE KEY LOOKUPS
    // ========================================================================
    /*
    PURPOSE: Load dimension tables to enable proper surrogate key lookups
    BUSINESS BENEFIT: Ensures referential integrity and optimal query performance
    */
    
    // Load dimensions for key lookups
    dim_Parts = dim_Branch12_Parts,
    dim_Date = dim_DateTable,
    
    // ========================================================================
    // STEP 2: LOAD AND FILTER TRANSACTION SOURCE DATA
    // ========================================================================
    /*
    PURPOSE: Load Branch 12 transaction history from InTrans
    FILTER STRATEGY: Branch 12 only with sufficient historical coverage
    BUSINESS LOGIC: 3-year history supports rolling 36-month analysis
    */
    
    // Load raw transaction data
    Source = InTrans_Incremental,
    
    // CRITICAL: Filter to Branch 12 transactions only
    FilterBranch12 = Table.SelectRows(Source, each ([Branch] = "12")),
    
    // Optional: Filter to last 3 years for initial load
    FilterDateRange = Table.SelectRows(FilterBranch12, each 
        [TransDatetime] >= DateTime.From(Date.AddYears(Date.From(DateTime.LocalNow()), -3))
    ),
    
    // ========================================================================
    // STEP 3: SELECT ESSENTIAL TRANSACTION COLUMNS
    // ========================================================================
    /*
    PURPOSE: Select only essential columns for Branch 12 analysis
    STRATEGY: Minimal column set for optimal performance and CU usage
    */
    
    SelectColumns = Table.SelectColumns(FilterDateRange, {
        // === TRANSACTION IDENTIFICATION ===
        "TransDatetime",        // Transaction timestamp
        "ModifiedDate",         // For incremental refresh
        "RONumber",             // Reference number
        "Type",                 // Transaction type
        
        // === PART IDENTIFICATION ===
        "PartNumber",           // Part number (for lookup)
        "Description",          // Part description
        "Franchise",            // Manufacturer/brand
        
        // === TRANSACTION METRICS (RAW FROM SOURCE) ===
        "Qty",                  // Quantity (NEGATIVE = sale, POSITIVE = addition)
        "CostValue",            // Cost value (NEGATIVE for sales - need to convert)
        "SellPrice1",           // Unit selling price (always positive)
        "ListPrice",             // Manufacturer list price (always positive)

        // === TRANSFER DESTINATION === (NEW)
        "TransferBranch"        // Branch being transfered to
    }),
    
    // ========================================================================
    // STEP 4: DATA TYPE STANDARDIZATION & CLEANING
    // ========================================================================
    /*
    PURPOSE: Clean and standardize data types
    APPROACH: Handle nulls, standardize text fields, validate numbers
    */
    
    // Clean part number for dimension lookup
    CleanPartNumber = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),
    
    // Clean text fields
    CleanTextFields = Table.TransformColumns(CleanPartNumber, {
        {"Description", each Text.Proper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Type", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"RONumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    // Clean TransferBranch - handle nulls and standardize
    CleanTransferBranch = Table.TransformColumns(CleanTextFields, {
        {"TransferBranch", each if _ = null then null else Text.Upper(Text.Trim(Text.From(_))), type text}
    }),
    
    // Ensure numeric fields have proper types with null handling
    CleanNumericFields = Table.TransformColumns(CleanTextFields, {
        {"Qty", each if _ = null then 0 else _, type number},
        {"CostValue", each if _ = null then 0 else _, type number},
        {"SellPrice1", each if _ = null then 0 else _, type number},
        {"ListPrice", each if _ = null then 0 else _, type number}
    }),
    
    // ========================================================================
    // STEP 5: BRANCH 12 BUSINESS LOGIC - SALES IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Identify sales transactions and calculate proper sales quantity
    CRITICAL BUSINESS LOGIC:
    • Negative Qty = SALE (transfer OUT to physical stores)
    • Positive Qty = INVENTORY ADDITION (transfer IN for restocking)
    • Sales calculations must use ABSOLUTE VALUE of negative quantities
    */
    
    // Sales flag - CRITICAL for Branch 12 logic
    AddIsSale = Table.AddColumn(CleanNumericFields, "IsSale", each
        [Qty] < 0,  // Negative quantity = Sale
        type logical),
    
    // Raw quantity preserved for audit trail
    AddRawQty = Table.AddColumn(AddIsSale, "RawQty", each
        [Qty],  // Keep original: negative = sale, positive = addition
        type number),
    
    // Sales Quantity - absolute value of negative quantities, zero for positive
    AddSalesQty = Table.AddColumn(AddRawQty, "SalesQty", each
        if [Qty] < 0 then Number.Abs([Qty]) else 0,
        type number),
    
    // Inventory Addition Quantity - positive quantities only
    AddInventoryAddQty = Table.AddColumn(AddSalesQty, "InventoryAddQty", each
        if [Qty] > 0 then [Qty] else 0,
        type number),
    
    // ========================================================================
    // STEP 6: BRANCH 12 BUSINESS LOGIC - COST VALUE CORRECTION
    // ========================================================================
    /*
    PURPOSE: Convert negative cost values to positive for proper calculations
    BUSINESS LOGIC: CostValue from source is stored as NEGATIVE for sales transactions
    CALCULATION: Use absolute value to get true positive cost for sales
    */
    
    // Rename incoming CostValue to RawCostValue (preserve original)
    RenameRawCost = Table.RenameColumns(AddInventoryAddQty, {{"CostValue", "RawCostValue"}}),
    
    // Create corrected CostValue - absolute value for sales, as-is for additions
    AddCostValue = Table.AddColumn(RenameRawCost, "CostValue", each
        if [IsSale] then Number.Abs([RawCostValue]) else [RawCostValue],
        type number),
    
    // ========================================================================
    // STEP 7: BRANCH 12 BUSINESS LOGIC - SALES VALUE CALCULATION
    // ========================================================================
    /*
    PURPOSE: Calculate proper sales value using corrected quantities
    BUSINESS LOGIC: SaleValue = SellPrice1 × SalesQty (absolute value of negative qty)
    IMPORTANT: This replaces any SaleValue from source - we calculate it correctly
    */
    
    // Calculate Sales Value - only for sales transactions (negative qty)
    AddSaleValue = Table.AddColumn(AddCostValue, "SaleValue", each
        if [IsSale] then [SellPrice1] * [SalesQty] else 0,
        type number),
    
    // ========================================================================
    // STEP 8: BRANCH 12 BUSINESS LOGIC - MARGIN CALCULATIONS
    // ========================================================================
    /*
    PURPOSE: Calculate margin dollars and percentages for sales transactions
    BUSINESS LOGIC: Only meaningful for sales (negative qty) transactions
    CALCULATION: Uses corrected SaleValue and CostValue
    */
    
    // Margin Dollars - SaleValue minus CostValue (both now positive for sales)
    AddMarginDollars = Table.AddColumn(AddSaleValue, "MarginDollars", each
        if [IsSale] then [SaleValue] - [CostValue] else 0,
        type number),
    
    // Margin Percentage - Margin / SaleValue
    AddMarginPercent = Table.AddColumn(AddMarginDollars, "MarginPercent", each
        if [IsSale] and [SaleValue] > 0 then [MarginDollars] / [SaleValue] else 0,
        type number),
    
    // ========================================================================
    // STEP 9: CREATE DATE KEY FOR DIMENSION RELATIONSHIP
    // ========================================================================
    /*
    PURPOSE: Generate DateKey for efficient relationship to dim_DateTable
    BUSINESS LOGIC: Convert TransDatetime to YYYYMMDD integer format
    */
    
    // Extract date and create DateKey
    AddDateKey = Table.AddColumn(AddMarginPercent, "DateKey", each
        let
            transDate = DateTime.Date([TransDatetime]),
            dateKey = Date.Year(transDate) * 10000 + Date.Month(transDate) * 100 + Date.Day(transDate)
        in
            dateKey,
        Int64.Type),
    
    // Add Date column for convenience
    AddDate = Table.AddColumn(AddDateKey, "Date", each
        DateTime.Date([TransDatetime]), type date),
    
    // ========================================================================
    // STEP 10: TRANSACTION TYPE INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Add business-friendly descriptions for Branch 12 transactions
    BUSINESS LOGIC: Most Branch 12 transactions are transfers (in or out)
    */
    
    AddTransactionTypeDescription = Table.AddColumn(AddDate, "TransactionTypeDescription", each
        let
            typeCode = [Type] ?? ""
        in
            if [IsSale] then "Sale (Transfer Out)"           // Negative qty
            else if typeCode = "T" then "Inventory Addition (Transfer In)"  // Positive qty
            else if typeCode = "A" then "Adjustment"
            else if typeCode = "R" then "Return"
            else typeCode,
        type text),
    
    // Transfer flag (most Branch 12 transactions are transfers)
    AddIsTransfer = Table.AddColumn(AddTransactionTypeDescription, "IsTransfer", each
        ([Type] ?? "") = "T", type logical),
    
    // ========================================================================
    // STEP 11: LOOKUP PARTNUMBERKEY FROM DIM_BRANCH12_PARTS
    // ========================================================================
    /*
    PURPOSE: Add PartNumberKey for proper fact-to-dimension relationship
    APPROACH: Left join to dimension, handle unmatched parts gracefully
    */
    
    // Merge with parts dimension
    MergePartsKey = Table.NestedJoin(
        AddIsTransfer,
        {"PartNumber"},
        dim_Parts,
        {"PartNumber"},
        "PartsLookup",
        JoinKind.LeftOuter
    ),
    
    // Expand PartNumberKey
    ExpandPartsKey = Table.ExpandTableColumn(
        MergePartsKey,
        "PartsLookup",
        {"PartNumberKey"},
        {"PartNumberKey"}
    ),
    
    // Handle unmatched parts (assign to Unknown = -1)
    CleanPartsKey = Table.TransformColumns(ExpandPartsKey, {
        {"PartNumberKey", each if _ = null then -1 else _, Int64.Type}
    }),
    
    // ========================================================================
    // STEP 12: TIME INTELLIGENCE HELPERS
    // ========================================================================
    /*
    PURPOSE: Add time-based intelligence for temporal analysis
    */
    
    // Extract year, month, quarter
    AddYear = Table.AddColumn(CleanPartsKey, "Year", each
        Date.Year([Date]), Int64.Type),
    
    AddMonth = Table.AddColumn(AddYear, "Month", each
        Date.Month([Date]), Int64.Type),
    
    AddMonthName = Table.AddColumn(AddMonth, "MonthName", each
        Date.MonthName([Date]), type text),
    
    AddQuarter = Table.AddColumn(AddMonthName, "Quarter", each
        Date.QuarterOfYear([Date]), Int64.Type),
    
    // ========================================================================
    // STEP 13: FINAL COLUMN ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Organize columns for optimal reporting
    STRUCTURE: Keys, flags, corrected metrics, raw metrics, context, time, audit
    */
    
    ReorderColumns = Table.ReorderColumns(AddQuarter, {
        // ===== DIMENSIONAL KEYS =====
        "DateKey",                      // → dim_DateTable
        "PartNumberKey",                // → dim_Branch12_Parts
        
        // ===== BUSINESS KEYS =====
        "Date",                         // Date for convenience
        "PartNumber",                   // Part business key
        
        // ===== TRANSACTION IDENTIFICATION =====
        "TransDatetime",                // Transaction timestamp
        "RONumber",                     // Reference number
        "Type",                         // Transaction type code
        "TransactionTypeDescription",   // Friendly description
        "IsSale",                       // CRITICAL: Negative qty flag
        "IsTransfer",                   // Transfer flag

        // ===== TRANSFER DESTINATION ===== (NEW SECTION)
        "TransferBranch",               // New Column
        
        // ===== CORRECTED METRICS (USE THESE FOR REPORTING) =====
        "SalesQty",                     // ABS(Qty) for sales, 0 for additions
        "InventoryAddQty",              // Positive qty for additions, 0 for sales
        "SaleValue",                    // Calculated: SellPrice1 × SalesQty
        "CostValue",                    // Corrected: ABS(COST_VAL) for sales
        "MarginDollars",                // Calculated: SaleValue - CostValue
        "MarginPercent",                // Calculated: MarginDollars / SaleValue
        
        // ===== RAW METRICS (AUDIT TRAIL) =====
        "RawQty",                       // Original: negative = sale, positive = addition
        "RawCostValue",                 // Original: negative for sales
        
        // ===== PRICING CONTEXT =====
        "SellPrice1",                   // Unit selling price
        "ListPrice",                    // Manufacturer list price
        
        // ===== PART CONTEXT =====
        "Description",                  // Part description
        "Franchise",                    // Manufacturer/brand
        
        // ===== TIME INTELLIGENCE =====
        "Year",                         // Year
        "Month",                        // Month number
        "MonthName",                    // Month name
        "Quarter",                      // Quarter number
        
        // ===== AUDIT FIELDS =====
        "ModifiedDate"                  // Last modified
    }),
    
    // ========================================================================
    // STEP 14: FINAL DATA TYPES
    // ========================================================================
    /*
    PURPOSE: Set optimal data types for performance
    */
    
    FinalDataTypes = Table.TransformColumnTypes(ReorderColumns, {
        // Keys
        {"DateKey", Int64.Type}, {"PartNumberKey", Int64.Type},
        {"Date", type date}, {"PartNumber", type text},
        
        // Transaction identification
        {"TransDatetime", type datetime}, {"RONumber", type text},
        {"Type", type text}, {"TransactionTypeDescription", type text},
        {"IsSale", type logical}, {"IsTransfer", type logical},

        // Transfer destination (NEW)
        {"TransferBranch", type text},  // New Column
        
        // Corrected metrics
        {"SalesQty", type number}, {"InventoryAddQty", type number},
        {"SaleValue", type number}, {"CostValue", type number},
        {"MarginDollars", type number}, {"MarginPercent", type number},
        
        // Raw metrics
        {"RawQty", type number}, {"RawCostValue", type number},
        
        // Pricing
        {"SellPrice1", type number}, {"ListPrice", type number},
        
        // Part context
        {"Description", type text}, {"Franchise", type text},
        
        // Time intelligence
        {"Year", Int64.Type}, {"Month", Int64.Type}, {"MonthName", type text},
        {"Quarter", Int64.Type},
        
        // Audit
        {"ModifiedDate", type datetime}
    }),
    
    // ========================================================================
    // STEP 15: FINAL SORT
    // ========================================================================
    
    FinalSort = Table.Sort(FinalDataTypes, {
        {"TransDatetime", Order.Ascending},
        {"PartNumber", Order.Ascending}
    })

in
    FinalSort

/*
============================================================================
✅ FACT_BRANCH12_TRANSACTIONS - BRANCH 12 BUSINESS LOGIC IMPLEMENTED
============================================================================

🎯 CRITICAL BRANCH 12 LOGIC CORRECTLY IMPLEMENTED:

1. SALES IDENTIFICATION (IsSale flag):
   • IsSale = TRUE when Qty < 0 (negative = sale)
   • IsSale = FALSE when Qty > 0 (positive = inventory addition)

2. SALES QUANTITY CALCULATION:
   • SalesQty = ABS(Qty) when Qty < 0, else 0
   • Example: Qty = -500 → SalesQty = 500

3. COST VALUE CORRECTION:
   • CostValue = ABS(COST_VAL) when IsSale = TRUE
   • Converts negative costs to positive for proper margin calculation

4. SALE VALUE CALCULATION:
   • SaleValue = SellPrice1 × SalesQty
   • Example: SellPrice1 = $469.31 × SalesQty = 500 → $234,655

5. MARGIN CALCULATION:
   • MarginDollars = SaleValue - CostValue (both positive now)
   • MarginPercent = MarginDollars / SaleValue

📊 USAGE IN DAX MEASURES:

// Sales R12 (matches your old logic)
Sales R12 = 
CALCULATE(
    SUM(fact_Branch12_Transactions[SaleValue]),  // Already calculated correctly
    fact_Branch12_Transactions[IsSale] = TRUE,    // Only sales transactions
    dim_DateTable[IsRolling365Days] = TRUE
)

// Cost R12 (matches your old "Cost (-$)" measure)
Total COS R12 = 
CALCULATE(
    SUM(fact_Branch12_Transactions[CostValue]),   // Already converted to positive
    fact_Branch12_Transactions[IsSale] = TRUE,    // Only sales transactions
    dim_DateTable[IsRolling365Days] = TRUE
)

// Margin $ (matches your old logic)
Margin $ = 
CALCULATE(
    SUM(fact_Branch12_Transactions[MarginDollars]),  // Pre-calculated
    fact_Branch12_Transactions[IsSale] = TRUE
)

// Sales Qty (matches your old logic)
Sales Qty = 
CALCULATE(
    SUM(fact_Branch12_Transactions[SalesQty]),    // Already ABS(Qty) for sales
    fact_Branch12_Transactions[IsSale] = TRUE
)

🔍 VALIDATION AFTER DEPLOYMENT:

Check these to ensure Branch 12 logic is working correctly:

// 1. Sales should only come from negative quantities
Sales Check = 
CALCULATE(
    SUM(fact_Branch12_Transactions[SaleValue]),
    fact_Branch12_Transactions[IsSale] = TRUE
)
// Should match your current report: ~$148.74K for R12

// 2. Verify SalesQty is positive
Min Sales Qty = 
CALCULATE(
    MIN(fact_Branch12_Transactions[SalesQty]),
    fact_Branch12_Transactions[IsSale] = TRUE
)
// Should be >= 0 (no negatives)

// 3. Verify CostValue is positive for sales
Min Cost Value = 
CALCULATE(
    MIN(fact_Branch12_Transactions[CostValue]),
    fact_Branch12_Transactions[IsSale] = TRUE
)
// Should be >= 0 (no negatives)

// 4. Compare to old report totals
// Your old report shows $148.74K sales - this should match exactly now

📋 IMPORTANT NOTES:

• Raw metrics preserved: RawQty and RawCostValue kept for audit trail
• IsSale flag is CRITICAL: Always filter by this for sales metrics
• SaleValue, CostValue, and MarginDollars are pre-calculated correctly
• All Branch 12 unique logic is handled in Power Query, not DAX
• DAX measures become simple SUM() operations - very fast!

============================================================================
*/