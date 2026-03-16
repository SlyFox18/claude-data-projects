let
    /*
    ================================================================================================
    FACT TABLE: Fact_Invoice_UniqueCustomers
    ================================================================================================
    
    PURPOSE:
    Transaction-level fact table for unique customers sourced from Invoice system.
    Captures sales, costs, margins, and transaction details for Invoice-based unique customers.
    
    BUSINESS CONTEXT:
    - Complements Fact_InTrans_UniqueCustomers (different source, different customers)
    - Supports customers identified by CustomerOrderNumber patterns (Manuel, Jim, David, Danny G, Oscar)
    - Links to InTrans for Sales Type classification (Work Order vs Over the Counter)
    - Enables YTD, PYTD, and R12M performance analysis
    
    CUSTOMER IDENTIFICATION LOGIC:
    Uses CustomerOrderNumber field with case-insensitive text pattern matching:
    - Text.Upper() converts to uppercase for consistent matching
    - Text.Contains() checks if pattern exists anywhere in the field
    - Branch restrictions add location-specific filtering where needed
    
    Currently Supported Customers (CustomerKey → Name):
    - Key 4: Manuel/MR Tractor (contains "MANUEL" or "MR TRACTOR")
    - Key 5: Jim Justice (contains "JIM" and Branch = "94")
    - Key 6: David Arizmendi (contains "DAVID" and Branch = "92")
    - Key 10: Danny G (contains "*DANNY G")
    - Key 11: Oscar (contains "*OSCAR")
    
    DATA QUALITY CONTROLS:
    - Filters to only rows with valid CustomerKey (non-null)
    - Deduplicates InTrans Description to prevent Cartesian product
    - Handles null CustomerOrderNumber values with ?? "" operator
    
    DIMENSIONAL RELATIONSHIPS:
    - CustomerKey → dim_UniqueCustomers (Many:1)
    - BranchKey → dim_BranchLocation (Many:1)
    - DateKey → dim_DateTable (Many:1)
    
    PERFORMANCE OPTIMIZATIONS:
    - Early filtering (FilteredRows) reduces dataset before expensive joins
    - DateKey as integer improves time intelligence performance
    - TransactionKey enables incremental refresh capability
    - Pre-calculated margin fields reduce report-time calculations
    
    ADDING NEW CUSTOMERS TO THIS FACT TABLE:
    
    Step 1: Add customer to dim_UniqueCustomers first
    --------
    - Assign next sequential CustomerKey (currently 12+)
    - Set DataSource = "Invoice"
    - Define IdentificationMethod and Rule
    
    Step 2: Update AddCustomerKey logic below
    --------
    Add new condition in the AddCustomerKey step (see example patterns below)
    
    Pattern A - Simple text contains:
    else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "KEYWORD") then XX  // CustomerName
    
    Pattern B - Text contains with branch restriction:
    else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "KEYWORD") and [Branch] = "YY" then XX  // CustomerName
    
    Pattern C - Multiple text patterns (OR logic):
    else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "KEYWORD1") or 
            Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "KEYWORD2") then XX  // CustomerName
    
    Step 3: Test and validate
    --------
    - Refresh dataflow
    - Check transaction counts: Create table with CustomerKey, COUNT of rows
    - Verify sales totals: Sum PartsSaleValue by CustomerKey
    - Confirm no duplicates: Check TransactionKey for uniqueness
    
    MAINTENANCE NOTES:
    - Keep CustomerKey assignments in sequential order for readability
    - Add inline comments for each new customer condition
    - Test text patterns with sample data before deploying
    - Document any special business rules or exceptions
    - Coordinate changes with dim_UniqueCustomers updates
    
    ================================================================================================
    */
    
    // STEP 1: Load source data
    // ========================
    // Connects to the Invoice reference query
    // This query should point to the raw Invoice table from your data source
    Source = ref_Invoice,
    
    // STEP 1b: Pre-filter to rows with CustomerOrderNumber populated
    // =============================================================
    // CustomerOrderNumber is only present on a small subset of invoices.
    // This filter folds to SQL (WHERE CustomerOrderNumber IS NOT NULL AND CustomerOrderNumber <> '')
    // which means the Lakehouse returns only candidate rows before any Power Query processing.
    // Eliminates the bulk of Invoice rows before the expensive Text.Contains scan in Step 2.
    PreFilter = Table.SelectRows(Source, each [CustomerOrderNumber] <> null and [CustomerOrderNumber] <> ""),

    // STEP 2: Add CustomerKey identification logic
    // =============================================
    // This is the CORE LOGIC that identifies which customers belong in this fact table
    // Each condition checks CustomerOrderNumber for specific patterns
    // Text.Upper() ensures case-insensitive matching
    // ?? "" handles null values to prevent errors

    AddCustomerKey = Table.AddColumn(PreFilter, "CustomerKey", each
        // Pattern 1: Multiple keywords with OR logic (Manuel/MR Tractor)
        if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "MANUEL") or 
           Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "MR TRACTOR") then 4  // Combined Manuel/MR Tractor
        // Matches: "MANUEL-123", "manuel order", "MR TRACTOR PARTS", "mr tractor sale"
        
        // Pattern 2: Keyword with branch restriction (Jim Justice)
        else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "JIM") and [Branch] = "94" then 5  // Jim Justice (Branch 94 only)
        // Matches: "JIM-001" ONLY if Branch = "94"
        // Does NOT match: "JIM-001" in Branch 92 or any other branch
        
        // Pattern 3: Keyword with different branch restriction (David Arizmendi)
        else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "DAVID") and [Branch] = "92" then 6  // David Arizmendi (Branch 92 only)
        // Matches: "DAVID ORDER" ONLY if Branch = "92"
        // Similar to Jim but different branch requirement
        
        // Pattern 4: Keyword starting with special character (Danny G)
        else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "*DANNY G") then 10  // Danny G (starts with *)
        // Matches: "*DANNY G-123", "*danny g order", "*Danny G PARTS"
        // The asterisk (*) is treated as a literal character, NOT a wildcard
        // Case-insensitive: Works for any case variation
        
        // Pattern 5: Another special character prefix (Oscar)
        else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "*OSCAR") then 11  // Oscar (starts with *)
        // Matches: "*OSCAR-456", "*oscar sale", "*Oscar ORDER"
        // Like Danny G, asterisk is literal character
        
        // Default: No match returns null (these rows will be filtered out next)
        else null, 
        
        Int64.Type  // Specify data type for new column
    ),
    // ADDING NEW CUSTOMERS: Insert new "else if" conditions above the "else null" line
    // Next CustomerKey to use: 12
    // Example: else if Text.Contains(Text.Upper([CustomerOrderNumber] ?? ""), "NEWCUST") then 12  // New Customer Name
    
    // STEP 3: Filter to only valid unique customers
    // ==============================================
    // Removes all rows where CustomerKey is null (not a unique customer)
    // This early filtering improves performance by reducing dataset size
    FilteredRows = Table.SelectRows(AddCustomerKey, each [CustomerKey] <> null),
    
    // STEP 4: Create deduplicated InTrans lookup
    // ===========================================
    // Purpose: Get Description field from InTrans to determine Sales Type
    // Problem: One Invoice can match multiple InTrans records (creates duplicates)
    // Solution: Deduplicate by RONumber to ensure 1:1 relationship
    
    InTransDedup = Table.Distinct(
        Table.SelectColumns(ref_InTrans, {"RONumber", "Description"}),  // Select only needed columns
        {"RONumber"}  // Deduplicate on RONumber (keep first occurrence)
    ),
    // Why deduplicate? Without this, one invoice matching 3 InTrans records would create 3 fact rows
    // With deduplication, we get exactly 1 fact row per invoice
    
    // STEP 5: Join to InTrans for Sales Type classification
    // ======================================================
    // Left Outer Join: Keep ALL invoices, even if no InTrans match
    // Matches: Invoice.InvoiceNumber = InTrans.RONumber
    JoinInTrans = Table.NestedJoin(
        FilteredRows,           // Left table (Invoice)
        {"InvoiceNumber"},      // Left join key
        InTransDedup,           // Right table (deduplicated InTrans)
        {"RONumber"},           // Right join key
        "InTransInfo",          // Name of nested table column
        JoinKind.LeftOuter      // Keep all left rows, match right where possible
    ),
    
    // STEP 6: Expand InTrans Description column
    // ==========================================
    // Extracts Description from nested InTransInfo table
    // Will be null if no InTrans match exists
    ExpandInTrans = Table.ExpandTableColumn(
        JoinInTrans, 
        "InTransInfo",              // Nested table to expand
        {"Description"},            // Columns to extract
        {"InTrans_Description"}     // New column names
    ),
    
    // STEP 7: Classify Sales Type (Work Order vs Over the Counter)
    // =============================================================
    // Business Rule: If Description contains "Inv No." → Work Order
    // Fallback: If WorkOrderNumber exists → Work Order
    // Default: Over the Counter
    AddSalesType = Table.AddColumn(ExpandInTrans, "SalesType", each
        if [InTrans_Description] <> null and Text.Contains([InTrans_Description], "Inv No.") then "Work Order"
        else if [WorkOrderNumber] <> null then "Work Order"  // Fallback logic when InTrans_Description is null
        else "Over the Counter",  // Default classification
        type text
    ),
    
    // STEP 8: Join to Branch dimension for BranchKey
    // ===============================================
    // Left Outer Join: Get BranchKey for dimensional relationships
    // Matches: Invoice.Branch = dim_BranchLocation.BranchID
    JoinBranch = Table.NestedJoin(
        AddSalesType, 
        {"Branch"}, 
        ref_dim_BranchLocation, 
        {"BranchID"}, 
        "BranchInfo", 
        JoinKind.LeftOuter
    ),
    
    // STEP 9: Expand BranchKey from dimension
    // ========================================
    ExpandBranch = Table.ExpandTableColumn(
        JoinBranch, 
        "BranchInfo", 
        {"BranchKey"}, 
        {"BranchKey"}
    ),
    
    // STEP 10: Create DateKey for time intelligence
    // ==============================================
    // Format: YYYYMMDD as integer (e.g., 20250115 for Jan 15, 2025)
    // Integer format improves join performance vs. date type
    // Enables efficient filtering and relationships with dim_DateTable
    AddDateKey = Table.AddColumn(ExpandBranch, "DateKey", each 
        Date.Year(DateTime.Date([InvoiceDate])) * 10000 +   // Year portion (2025 * 10000 = 20250000)
        Date.Month(DateTime.Date([InvoiceDate])) * 100 +     // Month portion (1 * 100 = 100)
        Date.Day(DateTime.Date([InvoiceDate])),              // Day portion (15 = 15)
        Int64.Type                                           // Result: 20250115
    ),
    
    // STEP 11-14: Add time intelligence helper columns
    // =================================================
    // These columns support time-based filtering and grouping in reports
    
    // Invoice Year (e.g., 2025)
    AddYear = Table.AddColumn(AddDateKey, "InvoiceYear", each 
        Date.Year([InvoiceDate]), 
        Int64.Type
    ),
    
    // Invoice Month (1-12)
    AddMonth = Table.AddColumn(AddYear, "InvoiceMonth", each 
        Date.Month([InvoiceDate]), 
        Int64.Type
    ),
    
    // Invoice Quarter (1-4)
    AddQuarter = Table.AddColumn(AddMonth, "InvoiceQuarter", each 
        Date.QuarterOfYear([InvoiceDate]), 
        Int64.Type
    ),
    
    // Invoice Year-Month (e.g., 202501 for Jan 2025)
    // Useful for sorting and filtering by month across years
    AddYearMonth = Table.AddColumn(AddQuarter, "InvoiceYearMonth", each 
        Date.Year([InvoiceDate]) * 100 + Date.Month([InvoiceDate]), 
        Int64.Type
    ),
    
    // STEP 15-16: Calculate business metrics
    // =======================================
    // Pre-calculate margins to improve report performance
    
    // Margin Amount (dollars)
    AddMarginAmount = Table.AddColumn(AddYearMonth, "MarginAmount", each 
        [PartsSaleValue] - [PartsCostValue], 
        type number
    ),
    
    // Margin Percent (0-1 scale, e.g., 0.35 = 35%)
    // Division by zero protection: returns 0 if no sales
    AddMarginPercent = Table.AddColumn(AddMarginAmount, "MarginPercent", each 
        if [PartsSaleValue] <> 0 then 
            ([PartsSaleValue] - [PartsCostValue]) / [PartsSaleValue] 
        else 0, 
        type number
    ),
    
    // STEP 17: Create unique transaction key
    // =======================================
    // Purpose: Enables incremental refresh and ensures row uniqueness
    // Format: INV_Branch_DateKey_InvoiceNumber_CustomerNumber
    // Example: INV_94_20250115_12345_67890
    AddTransactionKey = Table.AddColumn(AddMarginPercent, "TransactionKey", each 
        Text.Combine({
            "INV",                              // Prefix identifies Invoice source
            Text.From([Branch]),                // Branch code
            Text.From([DateKey]),               // Date in YYYYMMDD format
            [InvoiceNumber] ?? "",              // Invoice number (handle nulls)
            Text.From([CustomerNumber])         // Customer number
        }, "_"),                                // Underscore separator
        type text
    ),
    
    // STEP 18: Select final columns for fact table
    // =============================================
    // Only include columns needed for reporting and relationships
    // Reduces model size and improves performance
    SelectedColumns = Table.SelectColumns(AddTransactionKey, {
        // Keys and Identifiers
        "TransactionKey",          // Unique row identifier
        "DateKey",                 // Date dimension key (integer YYYYMMDD)
        "CustomerKey",             // Customer dimension key
        "BranchKey",               // Branch dimension key
        
        // Date/Time fields
        "InvoiceDate",             // Original date field
        "InvoiceYear",             // Year number (2025)
        "InvoiceMonth",            // Month number (1-12)
        "InvoiceQuarter",          // Quarter number (1-4)
        "InvoiceYearMonth",        // Year-Month combo (202501)
        
        // Descriptive fields
        "Branch",                  // Branch code
        "CustomerNumber",          // Customer identifier
        "CompanyName",             // Company name
        "InvoiceNumber",           // Invoice number
        "WorkOrderNumber",         // Work order number
        "CustomerOrderNumber",     // Customer order reference
        
        // Measure fields (additive facts)
        "PartsSaleValue",          // Sales amount
        "PartsCostValue",          // Cost amount
        "MarginAmount",            // Calculated margin ($)
        "MarginPercent",           // Calculated margin (%)
        
        // Classification fields
        "SalesType",               // Work Order or Over the Counter
        "InvoiceType"              // Invoice type code
    })
    
    // STEP 19: Return final fact table
    // =================================
    // This becomes Fact_Invoice_UniqueCustomers in the data model
in
    SelectedColumns