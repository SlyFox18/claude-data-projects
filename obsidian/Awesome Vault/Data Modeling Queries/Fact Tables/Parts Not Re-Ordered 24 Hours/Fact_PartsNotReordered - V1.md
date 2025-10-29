/*
============================================================================
FACT_PARTSNOTREORDERED - PARTS REORDER MONITORING FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Monitor parts sold at branches to identify items not reordered within business timeframes
Grain: One row per part transaction (sale) from the last 7 days
Refresh Strategy: Full refresh with 7-day rolling window
Performance: Lightweight - only 7 days of Franchise D transactions
Source Dependencies: InTrans (sales transactions), jdis_Part_Information (parts master)

🎯 BUSINESS USE CASES:
- Reorder Monitoring: Identify parts sold but not yet placed on order
- Inventory Management: Track bin quantities and stock availability  
- Branch Performance: Monitor which locations are timely with reordering
- Stock-Out Prevention: Proactive alerts before inventory depletes
- Operational Efficiency: Ensure 24-hour reorder compliance for Franchise D parts

📊 DATA STRUCTURE (11 COLUMNS):

**Stakeholder-Required Columns (Display Columns):**
- Branch: Branch location where part was sold
- PartNumber: Part number sold
- Description: Accurate part description from parts master table
- QtySold: Quantity sold in transaction
- InvoiceNumber: Invoice/RO number for transaction reference
- BinQty: Current bin quantity available at branch

**Analysis & Context Columns:**
- TransDatetime: Date and time of sale (joins to dim_DateTable)
- SaleDate: Date portion of TransDatetime (helper for efficient DAX calculations)
- OnOrder: Current on-order quantity from parts master (0 or null = not ordered)
- Type: Transaction type from InTrans (to be filtered once verified)
- Franchise: Franchise code (filtered to "D" only)

🔗 DIMENSION RELATIONSHIPS:
- dim_DateTable → TransDatetime (for business day calculations and time intelligence)
- dim_DateTable → SaleDate (alternative join for day-level analysis)
- dim_BranchLocation → Branch (for territory and location analysis)
- dim_Parts → Branch + PartNumber (if parts dimension exists)

🎯 KEY BUSINESS RULES:
- 7-Day Window: Pulls last 7 days to ensure adequate history while staying performant
- Franchise D Only: Filtered to Franchise "D" as requested by stakeholder
- Parts Master Description: Uses accurate description from jdis_Part_Information, not InTrans
- Current Status: OnOrder reflects CURRENT reorder status (snapshot at refresh time)
- Type Filter: Currently unfiltered - pending stakeholder clarification on transaction types

⚠️ IMPORTANT NOTES:
- Business Day Logic: Handled in DAX calculated columns/measures using dim_DateTable
- Weekend Handling: DAX calculations will account for weekends using date helpers
- OnOrder Status: Reflects current state, not historical - part may have been ordered after sale
- 24-Hour Rule: "Not reordered after 24 hours" logic implemented in Power BI Desktop
- SaleDate Helper: Added to enable efficient DAX calculations without complex measure overhead

🔧 RECENT UPDATES:
- Added SaleDate column: Extracted date portion for efficient DAX business day calculations
- Performance Optimization: SaleDate enables calculated columns instead of expensive measures

🔧 MAINTENANCE GUIDELINES:
- Type Filter: Add Type filter once stakeholder confirms correct transaction codes
- Date Window: 7-day window can be adjusted if more/less history needed
- Franchise: Currently hardcoded to "D" - can be parameterized if needed
- Refresh Frequency: Recommend 2-4 hour refresh during business hours

============================================================================
*/

let
    // ========================================================================
    // STEP 1: REFERENCE SOURCE QUERIES
    // ========================================================================
    /*
    PURPOSE: Bring in sales transactions and current parts master data
    SOURCES: 
    - qry_SalesTransactions_Last7Days: Recent sales (7-day rolling window, Franchise D)
    - qry_PartsMaster_Current: Current parts inventory status (OnOrder, BinQty)
    */
    
    SalesTransactions = qry_SalesTransactions_Last7Days,
    PartsMaster = qry_PartsMaster_Current,
    
    // ========================================================================
    // STEP 2: JOIN SALES WITH PARTS MASTER DATA
    // ========================================================================
    /*
    PURPOSE: Enrich sales transactions with current parts master information
    JOIN TYPE: Left Outer Join - keeps all sales even if part not in master
    JOIN KEYS: Branch + PartNumber (composite key for branch-specific parts)
    BUSINESS LOGIC: We need current OnOrder and BinQty status for each sold part
    */
    
    JoinTables = Table.NestedJoin(
        SalesTransactions, 
        {"Branch", "PartNumber"},
        PartsMaster, 
        {"Branch", "PartNumber"},
        "PartsMaster", 
        JoinKind.LeftOuter
    ),
    
    // ========================================================================
    // STEP 3: EXPAND PARTS MASTER COLUMNS
    // ========================================================================
    /*
    PURPOSE: Bring parts master columns into main table for analysis
    COLUMNS EXPANDED:
    - Description: Accurate part description from parts master (replaces InTrans description)
    - OnOrder: Current on-order quantity (key indicator for reorder status)
    - BinQty: Current bin quantity (stakeholder requirement for visibility)
    */
    
    ExpandPartsMaster = Table.ExpandTableColumn(
        JoinTables, 
        "PartsMaster", 
        {"Description", "OnOrder", "BinQty"}, 
        {"MasterDescription", "OnOrder", "BinQty"}
    ),
    
    // ========================================================================
    // STEP 4: DATA QUALITY - USE PARTS MASTER DESCRIPTION
    // ========================================================================
    /*
    PURPOSE: Use accurate description from parts master table
    BUSINESS RULE: InTrans descriptions may be outdated or incorrect
    STAKEHOLDER REQUIREMENT: Use jdis_Part_Information description as source of truth
    */
    
    RemoveInTransDescription = Table.RemoveColumns(ExpandPartsMaster, {"Description"}),
    
    RenameDescription = Table.RenameColumns(RemoveInTransDescription, {
        {"MasterDescription", "Description"}
    }),
    
    // ========================================================================
    // STEP 5: ADD PERFORMANCE HELPER COLUMN - SALE DATE
    // ========================================================================
    /*
    PURPOSE: Extract date portion of TransDatetime for efficient DAX calculations
    BUSINESS BENEFIT: Enables calculated columns in Power BI without measure overhead
    PERFORMANCE: Pre-calculated in Power Query reduces DAX complexity and query time
    USE CASE: Business day calculations in DAX can use this date for dim_DateTable joins
    
    WHY THIS MATTERS:
    - DAX measures iterating over dates are computationally expensive
    - Calculated columns using this helper are evaluated once at refresh
    - Enables efficient weekend/business day logic without query timeouts
    */
    
    AddSaleDate = Table.AddColumn(RenameDescription, "SaleDate", each
        DateTime.Date([TransDatetime]),
        type date
    ),
    
    // ========================================================================
    // STEP 6: COLUMN ORGANIZATION FOR STAKEHOLDER REQUIREMENTS
    // ========================================================================
    /*
    PURPOSE: Organize columns for optimal report layout and user experience
    COLUMN ORDER LOGIC:
    - Primary display columns first (Branch, PartNumber, Description, QtySold, InvoiceNumber, BinQty)
    - Time dimensions next (TransDatetime, SaleDate for dim_DateTable relationship)
    - Analysis columns last (OnOrder, Type, Franchise)
    */
    
    ReorderColumns = Table.ReorderColumns(AddSaleDate, {
        // ===== STAKEHOLDER DISPLAY COLUMNS =====
        "Branch",              // Location identifier
        "PartNumber",          // Part sold
        "Description",         // Accurate part description from master
        "QtySold",             // Quantity sold
        "InvoiceNumber",       // Transaction reference
        "BinQty",              // Current bin quantity
        
        // ===== TIME DIMENSIONS =====
        "TransDatetime",       // Full date/time of sale
        "SaleDate",            // Date only - helper for efficient DAX calculations
        
        // ===== ANALYSIS COLUMNS =====
        "OnOrder",             // Current reorder status (0/null = not ordered)
        "Type",                // Transaction type (pending filter clarification)
        "Franchise"            // Franchise code (filtered to "D")
    }),
    
    // ========================================================================
    // STEP 7: FINAL DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for performance and proper relationships
    STRATEGY: Appropriate types for joins, calculations, and display
    */
    
    SetFinalDataTypes = Table.TransformColumnTypes(ReorderColumns, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"QtySold", type number},
        {"InvoiceNumber", type text},
        {"BinQty", type number},
        {"TransDatetime", type datetime},
        {"SaleDate", type date},
        {"OnOrder", type number},
        {"Type", type text},
        {"Franchise", type text}
    })

in
    SetFinalDataTypes

/*
============================================================================
✅ FCT_PARTSNOTREORDERED - OPTIMIZED FACT TABLE WITH PERFORMANCE HELPERS
============================================================================

🎯 IMPLEMENTATION SUMMARY:
- Clean Data Foundation: 7-day rolling window of Franchise D sales transactions
- Current Status Snapshot: Parts master data provides real-time OnOrder and BinQty
- Accurate Descriptions: Uses jdis_Part_Information as source of truth
- Dimension-Ready: TransDatetime AND SaleDate enable relationships to dim_DateTable
- Performance Optimized: SaleDate helper enables efficient DAX calculated columns
- Stakeholder Alignment: Columns match exact requirements for report display

📊 WHAT THIS TABLE PROVIDES:
- Sales Transaction History: Last 7 days of parts sold (adequate for 24-hour monitoring)
- Current Reorder Status: OnOrder field shows if part has been placed on order
- Inventory Context: BinQty shows current stock levels at each branch
- Time Intelligence Ready: TransDatetime AND SaleDate connect to dim_DateTable
- DAX Performance: SaleDate enables efficient business day calculations

🔄 PERFORMANCE ENHANCEMENT - SALEDATE COLUMN:
PROBLEM SOLVED: DAX measures iterating dates caused "exceeded resources" errors
SOLUTION: Pre-calculate date portion in Power Query for one-time evaluation
BENEFIT: Business day logic can now use calculated columns instead of expensive measures
IMPLEMENTATION: DAX calculated columns use SaleDate to efficiently join with dim_DateTable

🔄 NEXT STEPS - DAX CALCULATED COLUMNS (Not Measures):
The following will be implemented as calculated columns in Power BI Desktop:
1. Business Hours Since Sale: Use SaleDate + dim_DateTable for weekend logic
2. Needs Reorder Flag: TRUE when BusinessHours > 24 AND OnOrder = 0/null
3. Then create simple aggregate measures on top of these columns

📈 DAX PATTERN TO USE (Calculated Columns):
Instead of complex measures, use calculated columns like:
- Business Hours Since Sale (Column): Calculates once at refresh
- Then aggregate with simple measures: COUNT, SUM, AVERAGE

🚀 PRODUCTION CHARACTERISTICS:
- Refresh Speed: Fast (7-day window, single franchise)
- Data Quality: Parts master description ensures accuracy
- Performance: SaleDate helper prevents DAX timeout errors
- Flexibility: Business day logic in calculated columns allows filtering/slicing
- Scalability: Can add additional franchises or extend date window as needed

⚠️ PENDING ITEMS:
- Type Filter: Add transaction type filter once stakeholder confirms codes
- DAX Calculated Columns: Create business hours and reorder flag columns in Power BI Desktop
- Relationships: Verify dim_DateTable relationships to both TransDatetime and SaleDate
- Testing: Validate business day logic with real weekend scenarios

🔗 RELATIONSHIP SETUP IN POWER BI DESKTOP:
Primary: fct_PartsNotReordered[TransDatetime] → dim_DateTable[Date] (or DateKey)
Alternative: fct_PartsNotReordered[SaleDate] → dim_DateTable[Date]
Note: Use SaleDate relationship for day-level business day calculations

This optimized approach separates data preparation (Power Query) from business
logic (DAX calculated columns), providing performance and maintainability for 
the reorder monitoring solution without query timeout errors.

============================================================================
*/