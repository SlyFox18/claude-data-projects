let
    /*
    ================================================================================================
    DIMENSION: dim_UniqueCustomers
    ================================================================================================
    
    PURPOSE: 
    Master reference table defining unique customers for parts sales reporting. This dimension 
    supports a dual-fact-table architecture where customer transactions come from two different 
    source systems (InTrans and Invoice) with varying identification methods.
    
    BUSINESS CONTEXT:
    - Tracks sales, margins, and performance for specific high-value customers
    - Enables YTD vs PYTD comparisons across different customer identification patterns
    - Supports both location-based customers (Pearsall, Dell City, Tornillo) and individual 
      customers (Manuel, Jim, David, Danny G, Oscar, etc.)
    
    IDENTIFICATION METHODS:
    1. TradeType: Uses ArMaster_Customer.TradeType to identify location-based customers
       - Example: TradeType = "D" identifies all Pearsall customers
       
    2. TradeType + Branch: Splits customers by both trade type and branch location
       - Example: TradeType = "T" + Branch = "2" identifies Tornillo
       
    3. CustomerOrderNumber: Text search in Invoice.CustomerOrderNumber field
       - Example: Contains "MANUEL" or "MR TRACTOR"
       - Case-insensitive matching using Text.Upper() in fact table logic
       
    4. CustomerOrderNumber + Branch: Text search with specific branch restriction
       - Example: Contains "JIM" AND Branch = "94"
       
    5. CustomerNo: Direct match on InTrans.CustomerNo for individual customers
       - Example: CustomerNo = "36192" for Dallyn Clements
    
    FACT TABLE RELATIONSHIPS:
    - Fact_InTrans_UniqueCustomers: Links via CustomerKey 
      Used for: Customers 1-3 (Pearsall, Dell City, Tornillo), 7-9 (individual InTrans customers)
      
    - Fact_Invoice_UniqueCustomers: Links via CustomerKey
      Used for: Customers 4-6, 10-11 (Invoice-based identification)
    
    COLUMN DEFINITIONS:
    - CustomerKey: Unique integer identifier (surrogate key) - used for fact table relationships
    - CustomerName: Display name shown in reports
    - DataSource: Which source system contains the transactions (InTrans or Invoice)
    - IdentificationMethod: How the customer is identified in source data
    - IdentificationRule: Business rule description for identification
    - IsActive: Boolean flag for soft deletes (set to false to hide without breaking history)
    - CreatedDate: When the customer was added to the dimension (for audit trail)
    
    ADDING NEW CUSTOMERS - STEP BY STEP:
    
    Step 1: Determine identification method
    --------
    Ask: How is this customer identified in the source system?
    - If by TradeType → Add to InTrans section
    - If by CustomerOrderNumber → Add to Invoice section
    - If by specific CustomerNo → Add to InTrans individual section
    
    Step 2: Assign next CustomerKey
    --------
    - Current highest key is 11
    - New customers should use 12, 13, 14, etc. (sequential)
    - NEVER reuse deleted customer keys (breaks historical data)
    
    Step 3: Add row to CustomersTable
    --------
    Format: {Key, "Name", "Source", "Method", "Rule", true, #date(YYYY, M, D)}
    Example: {12, "New Customer", "Invoice", "CustomerOrderNumber", "Contains NEWCUST", true, #date(2025, 12, 19)}
    
    Step 4: Update corresponding fact table
    --------
    - If DataSource = "InTrans" → Update Fact_InTrans_UniqueCustomers query
    - If DataSource = "Invoice" → Update Fact_Invoice_UniqueCustomers query
    - Add matching logic to AddCustomerKey step (see fact table documentation)
    
    Step 5: Refresh and validate
    --------
    - Refresh this dimension table
    - Refresh the corresponding fact table
    - Check transaction counts and sales totals match expectations
    - Verify relationships in model view
    
    MAINTENANCE NOTES:
    - When adding customers, increment CustomerKey sequentially (never skip numbers)
    - Update corresponding fact table logic for customer identification
    - Use today's date for CreatedDate when adding new customers
    - Set IsActive to false to hide customers (don't delete rows - breaks history)
    - Keep IdentificationRule descriptions clear and detailed
    - Document any special business rules or exceptions in comments
    
    COMMON SCENARIOS:
    
    Scenario: Add customer identified by CustomerOrderNumber containing specific text
    Solution: Add to Invoice section, use Text.Contains() in fact table
    Example: {12, "John Doe", "Invoice", "CustomerOrderNumber", "Contains JOHN", true, #date(2025, 12, 19)}
    
    Scenario: Add customer only in specific branch
    Solution: Add with "CustomerOrderNumber + Branch" method, include branch in rule
    Example: {12, "Jane Doe", "Invoice", "CustomerOrderNumber + Branch", "Contains JANE and Branch = 95", true, #date(2025, 12, 19)}
    
    Scenario: Add customer by specific CustomerNo from InTrans
    Solution: Add to InTrans individual section, use exact CustomerNo
    Example: {12, "Company ABC", "InTrans", "CustomerNo", "12345", true, #date(2025, 12, 19)}
    
    Scenario: Temporarily hide a customer from reporting
    Solution: Change IsActive from true to false (preserves historical relationships)
    
    ================================================================================================
    */
    
    // STEP 1: Define customer table structure and data
    // ================================================
    // Creates an in-memory table with all unique customers
    // Each row represents one customer with their identification rules
    CustomersTable = #table(
        // Column definitions - these define the structure
        {
            "CustomerKey",              // Surrogate key - used in fact table joins
            "CustomerName",             // Display name for reports
            "DataSource",               // Which system has the transactions (InTrans or Invoice)
            "IdentificationMethod",     // How we identify this customer
            "IdentificationRule",       // Business rule description
            "IsActive",                 // Boolean - false hides customer without breaking history
            "CreatedDate"               // Audit trail - when customer was added
        },
        
        // Data rows - each customer entry
        {
            // ============================================================================
            // LOCATION-BASED CUSTOMERS (InTrans TradeType identification)
            // ============================================================================
            // These customers are identified by their TradeType in ArMaster_Customer
            // Fact table: Fact_InTrans_UniqueCustomers uses ArMaster lookup method
            
            {1, "Pearsall", "InTrans", "TradeType", "D", true, #date(2025, 7, 31)},
            // TradeType "D" in ArMaster identifies all Pearsall customer transactions
            // Fact table filters InTrans for ANY customer with TradeType = "D"
            
            {2, "Dell City", "InTrans", "TradeType + Branch", "T and Branch <> 2", true, #date(2025, 8, 4)},
            // TradeType "T" + Branch NOT "2" identifies Dell City transactions
            // Splits the "T" trade type between Dell City and Tornillo by location
            
            {3, "Tornillo", "InTrans", "TradeType + Branch", "T and Branch = 2", true, #date(2025, 8, 4)},
            // TradeType "T" + Branch = "2" identifies Tornillo transactions
            // Branch code "2" is the specific Tornillo location identifier
            
            // ============================================================================
            // INVOICE-BASED CUSTOMERS (CustomerOrderNumber text matching)
            // ============================================================================
            // These customers are identified by text patterns in Invoice.CustomerOrderNumber
            // Fact table: Fact_Invoice_UniqueCustomers uses Text.Contains() with Text.Upper()
            
            {4, "Manuel/MR Tractor", "Invoice", "CustomerOrderNumber", "Contains MANUEL or MR TRACTOR", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "MANUEL" OR "MR TRACTOR" (case-insensitive)
            // Combined into single customer per business requirement
            // Examples: "MANUEL-123", "manuel/order", "MR TRACTOR PARTS" all match
            
            {5, "Jim Justice", "Invoice", "CustomerOrderNumber + Branch", "Contains JIM and Branch = 94", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "JIM" AND Branch = "94" (both conditions required)
            // Branch restriction prevents matching Jim orders from other locations
            // Examples: "JIM-001" in Branch 94 matches, but "JIM-001" in Branch 92 does NOT match
            
            {6, "David Arizmendi", "Invoice", "CustomerOrderNumber + Branch", "Contains DAVID and Branch = 92", true, #date(2025, 7, 31)},
            // Matches if CustomerOrderNumber contains "DAVID" AND Branch = "92"
            // Similar to Jim Justice but for Branch 92
            
            {10, "Danny G", "Invoice", "CustomerOrderNumber", "Starts with *DANNY G", true, #date(2025, 12, 19)},
            // Matches if CustomerOrderNumber contains "*DANNY G" (asterisk is literal, not wildcard)
            // Case-insensitive: "*DANNY G", "*danny g", "*Danny G" all match
            // Examples: "*DANNY G-001", "*danny g order" match
            
            {11, "Oscar", "Invoice", "CustomerOrderNumber", "Starts with *OSCAR", true, #date(2025, 12, 19)},
            // Matches if CustomerOrderNumber contains "*OSCAR" (asterisk is literal character)
            // Case-insensitive matching via Text.Upper() in fact table
            // Examples: "*OSCAR-123", "*oscar parts" match
            
            // ============================================================================
            // INDIVIDUAL CUSTOMERS (InTrans CustomerNo direct matching)
            // ============================================================================
            // These customers are identified by exact CustomerNo match in InTrans
            // Fact table: Fact_InTrans_UniqueCustomers uses List.Contains() for matching
            
            {7, "Dallyn Clements", "InTrans", "CustomerNo", "36192", true, #date(2025, 9, 22)},
            // Exact match: InTrans.CustomerNo = "36192"
            // Captures ALL transactions for this specific customer number
            
            {8, "Benny Gray", "InTrans", "CustomerNo", "38845", true, #date(2025, 9, 22)},
            // Exact match: InTrans.CustomerNo = "38845"
            
            {9, "Owen Bros.", "InTrans", "CustomerNo", "61055", true, #date(2025, 9, 22)}
            // Exact match: InTrans.CustomerNo = "61055"
            
            // ============================================================================
            // TO ADD NEW CUSTOMERS: Insert new row above this line
            // ============================================================================
            // Next available CustomerKey: 12
            // Format: {Key, "Name", "Source", "Method", "Rule", true, #date(YYYY, M, D)}
        }
    ),

    // STEP 2: Apply data types to all columns
    // ========================================
    // Converts text-based table structure into properly typed columns
    // This improves query performance and ensures data integrity
    TypedTable = Table.TransformColumnTypes(CustomersTable, {
        {"CustomerKey", Int64.Type},        // Integer - used for fact table joins
        {"CustomerName", type text},        // Text - display name
        {"DataSource", type text},          // Text - "InTrans" or "Invoice"
        {"IdentificationMethod", type text}, // Text - method description
        {"IdentificationRule", type text},  // Text - business rule
        {"IsActive", type logical},         // Boolean - true/false flag
        {"CreatedDate", type date}          // Date - audit timestamp
    })
    
    // STEP 3: Return the typed table as final output
    // ===============================================
    // This becomes the dim_UniqueCustomers dimension in the data model
in
    TypedTable