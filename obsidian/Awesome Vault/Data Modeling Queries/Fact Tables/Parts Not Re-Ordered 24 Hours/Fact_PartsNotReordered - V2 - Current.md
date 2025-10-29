/*
============================================================================
FACT_PARTSNOTREORDERED - PARTS REORDER MONITORING FACT TABLE (UPDATED)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Monitor parts sold at branches to identify items not reordered within business timeframes
Grain: One row per part transaction (sale) from the last 7 days
Refresh Strategy: Full refresh with 7-day rolling window
Performance: Lightweight - only 7 days of Franchise D transactions
Source Dependencies: 
- qry_SalesTransactions_Last7Days (deduplicated sales transactions)
- qry_PartsMaster_Current (deduplicated parts master with sales history)

🎯 BUSINESS USE CASES:
- Reorder Monitoring: Identify parts sold but not yet placed on order
- Inventory Management: Track bin quantities and stock availability  
- Branch Performance: Monitor which locations are timely with reordering
- Stock-Out Prevention: Proactive alerts before inventory depletes
- Sales Trend Analysis: Compare current vs previous 12-month sales activity (NEW)
- Dealer Group Analysis: Segment parts by dealer group classification (NEW)

📊 DATA STRUCTURE (14 COLUMNS - UPDATED):

**Stakeholder-Required Display Columns:**
- Branch: Branch location where part was sold
- PartNumber: Part number sold
- Description: Accurate part description from parts master table
- QtySold: Quantity sold in transaction
- InvoiceNumber: Invoice/RO number for transaction reference
- BinQty: Current bin quantity available at branch
- DealerGroupCode: Dealer group classification (NEW)
- Current12MoSales: Units sold in last 12 months (NEW)
- Previous12MoSales: Units sold in previous 12 months (NEW)

**Analysis & Context Columns:**
- TransDatetime: Date and time of sale (joins to dim_DateTable)
- SaleDate: Date portion of TransDatetime (helper for efficient DAX calculations)
- OnOrder: Current on-order quantity from parts master (0 or null = not ordered)
- Type: Transaction type from InTrans
- Franchise: Franchise code (filtered to "D" only)

🔗 DIMENSION RELATIONSHIPS:
- dim_DateTable → TransDatetime or SaleDate (for business day calculations)
- dim_BranchLocation → Branch (for territory and location analysis)
- dim_Parts → Branch + PartNumber (if parts dimension exists)

🎯 KEY BUSINESS RULES:
- 7-Day Window: Pulls last 7 days to ensure adequate history while staying performant
- Franchise D Only: Filtered to Franchise "D" as requested by stakeholder
- Deduplication Applied: Both source queries deduplicated to prevent duplicate fact records
- Parts Master Description: Uses accurate description from jdis_Part_Information, not InTrans
- Current Status: OnOrder, BinQty, and sales history reflect current snapshot at refresh time

⚠️ CRITICAL FIXES IMPLEMENTED:
- Parts Master Deduplication: Duplicate parts records eliminated at source (qry_PartsMaster_Current)
- Transaction Deduplication: Duplicate transactions eliminated at source (qry_SalesTransactions_Last7Days)
- Result: Fact table no longer has artificial duplicate records from source data issues

🔧 RECENT UPDATES (CURRENT SESSION):
- Added DealerGroupCode: Dealer group classification for segmentation and reporting
- Added Current12MoSales: Recent 12-month sales activity for trend analysis
- Added Previous12MoSales: Historical sales comparison for performance analysis
- Updated Documentation: Reflects deduplication fixes and new columns

============================================================================
*/

let
    // ========================================================================
    // STEP 1: REFERENCE DEDUPLICATED SOURCE QUERIES
    // ========================================================================
    /*
    PURPOSE: Bring in clean, deduplicated sales transactions and parts master data
    SOURCES: 
    - qry_SalesTransactions_Last7Days: Deduplicated sales (7-day window, Franchise D)
    - qry_PartsMaster_Current: Deduplicated parts master (one record per Branch + Part)
    
    DEDUPLICATION BENEFIT: Prevents fact table from multiplying due to source duplicates
    EXAMPLE: Branch 13, Part AR86745
    - OLD: 2 transactions × 2 parts master records = 4 fact rows (wrong)
    - NEW: 2 transactions × 1 parts master record = 2 fact rows (correct) ✓
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
    BUSINESS LOGIC: Attach current inventory status and sales history to each transaction
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
    // STEP 3: EXPAND PARTS MASTER COLUMNS (INCLUDING NEW COLUMNS)
    // ========================================================================
    /*
    PURPOSE: Bring parts master columns into main table for analysis and reporting
    COLUMNS EXPANDED:
    - Description: Accurate part description from parts master
    - OnOrder: Current on-order quantity (key reorder status indicator)
    - BinQty: Current bin quantity (stakeholder requirement)
    - DealerGroupCode: Dealer group classification (NEW)
    - Current12MoSales: Recent sales activity for trend analysis (NEW)
    - Previous12MoSales: Historical sales for comparison (NEW)
    */
    
    ExpandPartsMaster = Table.ExpandTableColumn(
        JoinTables, 
        "PartsMaster", 
        {"Description", "OnOrder", "BinQty", "DealerGroupCode", "Current12MoSales", "Previous12MoSales"}, 
        {"MasterDescription", "OnOrder", "BinQty", "DealerGroupCode", "Current12MoSales", "Previous12MoSales"}
    ),
    
    // ========================================================================
    // STEP 4: DATA QUALITY - USE PARTS MASTER DESCRIPTION
    // ========================================================================
    /*
    PURPOSE: Use accurate description from parts master table
    BUSINESS RULE: InTrans descriptions may be customer names or outdated info
    STAKEHOLDER REQUIREMENT: jdis_Part_Information is source of truth for descriptions
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
    PERFORMANCE: Enables calculated columns in Power BI without expensive measures
    USE CASE: Business day calculations use this for dim_DateTable joins
    */
    
    AddSaleDate = Table.AddColumn(RenameDescription, "SaleDate", each
        DateTime.Date([TransDatetime]),
        type date
    ),
    
    // ========================================================================
    // STEP 6: COLUMN ORGANIZATION FOR OPTIMAL REPORTING
    // ========================================================================
    /*
    PURPOSE: Organize columns for stakeholder reporting requirements
    COLUMN ORDER:
    1. Core identification and transaction details
    2. Sales history and classification (NEW columns)
    3. Time dimensions
    4. Analysis columns
    */
    
    ReorderColumns = Table.ReorderColumns(AddSaleDate, {
        // ===== CORE TRANSACTION DATA =====
        "Branch",              
        "PartNumber",          
        "Description",         
        "QtySold",             
        "InvoiceNumber",       
        "BinQty",              
        
        // ===== NEW: SALES HISTORY & CLASSIFICATION =====
        "DealerGroupCode",     // Dealer group segmentation
        "Current12MoSales",    // Recent sales trend
        "Previous12MoSales",   // Historical comparison
        
        // ===== TIME DIMENSIONS =====
        "TransDatetime",       
        "SaleDate",            
        
        // ===== ANALYSIS COLUMNS =====
        "OnOrder",             
        "Type",                
        "Franchise"            
    }),
    
    // ========================================================================
    // STEP 7: FINAL DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for performance and relationships
    */
    
    SetFinalDataTypes = Table.TransformColumnTypes(ReorderColumns, {
        {"Branch", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"QtySold", type number},
        {"InvoiceNumber", type text},
        {"BinQty", type number},
        {"DealerGroupCode", type text},
        {"Current12MoSales", type number},
        {"Previous12MoSales", type number},
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
✅ FCT_PARTSNOTREORDERED - ENHANCED WITH SALES HISTORY & DEDUPLICATION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
✓ Deduplication Applied: Source queries eliminate duplicates before join
✓ Sales History Added: Current and previous 12-month sales for trend analysis
✓ Classification Added: DealerGroupCode for segmentation and reporting
✓ Clean Data Foundation: One fact row per unique transaction (no artificial duplicates)
✓ Performance Optimized: SaleDate helper enables efficient DAX calculations

📊 NEW ANALYTICAL CAPABILITIES:
- Sales Trend Analysis: Compare Current12MoSales vs Previous12MoSales
- Parts Performance: Identify fast-moving vs slow-moving parts
- Dealer Group Segmentation: Report by DealerGroupCode classification
- Inventory Intelligence: Parts with high sales but low BinQty = reorder priority

🔧 DATA QUALITY IMPROVEMENTS:
BEFORE DEDUPLICATION FIX:
- Branch 13, Part AR86745: 2 transactions created 4 fact rows (2× multiplier from parts duplicates)
- Multiple parts had obsolete duplicate records from years ago

AFTER DEDUPLICATION FIX:
- Branch 13, Part AR86745: 2 transactions create 2 fact rows (correct 1:1 relationship) ✓
- Only current/active parts master records included

📈 EXAMPLE USE CASES WITH NEW COLUMNS:

**High-Priority Reorder Alert:**
Part with Current12MoSales > 100 AND BinQty < 10 AND OnOrder = 0
→ Fast-moving part with low inventory not yet reordered = urgent

**Sales Trend Analysis:**
Current12MoSales > Previous12MoSales × 1.5
→ Identify parts with accelerating demand for proactive inventory planning

**Dealer Group Performance:**
Compare reorder compliance rates by DealerGroupCode
→ Which dealer groups are better at timely reordering?

🚀 PRODUCTION READY:
- Refresh Speed: Fast (deduplicated sources, 7-day window)
- Data Quality: No artificial duplicates, accurate descriptions
- Business Value: Enhanced with sales history and classification
- Reporting Ready: Optimized column order for stakeholder reports

⚡ PERFORMANCE NOTES:
- Deduplication at source = smaller fact table
- Smaller fact table = faster refreshes and queries
- Sales history columns add minimal overhead (already in parts master)

============================================================================
*/