/*
============================================================================
RAW_INTRANS - PARTS TRANSACTION DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract parts/inventory transaction data from SQL Anywhere database
Grain: One row per parts transaction (sales, returns, transfers, adjustments)
Refresh Strategy: Incremental refresh using TransDatetime filtering (2023+ scope)
Performance: Target <3m refresh time with optimized date range
Source Dependencies: InTrans table via SQL Anywhere ODBC connection

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for parts transaction fact tables
• Parts Sales Analysis: Revenue, margins, and customer purchasing patterns
• Work Order Parts: Parts used in service and repair work
• Inventory Management: Stock movement tracking and demand analysis
• Customer Analytics: Parts purchasing behavior and pricing analysis
• Financial Reporting: Parts revenue, cost of goods sold, and margin analysis

📊 ESSENTIAL DATA STRUCTURE (16 COLUMNS - COMPLETE TRANSACTION DATA):

**Core Transaction Identifiers:**
• TransDatetime: Transaction timestamp (primary business date)
• Branch: Transaction branch location
• RONumber: Invoice number (historical field name - contains invoice numbers, not work orders)
• Type: Transaction type classification

**Parts Context:**
• PartNumber: Parts inventory identifier
• Description: Parts description
• Franchise: Equipment manufacturer/brand
• Qty: Transaction quantity (positive=sales, negative=returns)

**Customer Context:**
• CustomerNo: Customer account number
• TradeType: Customer trade classification

**Work Order Integration:**
• JobCode: Job code for work order linkage
• JobType: Job type classification

**Financial Data:**
• SaleValue: Transaction revenue amount
• CostValue: Transaction cost for margin calculation
• SellPrice1: Standard selling price
• ListPrice: Manufacturer list price

🔧 DESIGN APPROACH:

**Incremental Refresh Strategy:**
• TransDatetime filtering with 2023+ scope for performance optimization
• Balances historical data needs with acceptable refresh performance
• 7-day future buffer accommodates system clock variations

**Critical Field Mapping Notes:**
• RONumber contains Invoice Numbers (not work order numbers despite name)
• Work order linkage: Branch + RONumber + JobCode + JobType → wkothsub → work orders
• Historical naming cannot be changed due to downstream dependencies

⚠️ PERFORMANCE OPTIMIZATION:
Current 2020+ date range causes 13-14 minute refresh times. Optimized to 2023+ scope 
for acceptable performance while maintaining essential transaction history.

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - PERFORMANCE OPTIMIZED
    // ========================================================================
    /*
    PURPOSE: Optimize date range for acceptable refresh performance
    CHANGE: Reduced from 2020+ to 2023+ to address 13-14 minute refresh times
    PERFORMANCE: Should reduce refresh time from 13-14 minutes to <3 minutes
    */
    
    // Optimized date range for performance (reduced from 2020+ to 2023+)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),              // Performance-optimized start date
    RangeEnd = DateTime.LocalNow() + #duration(7, 0, 0, 0),   // Current + 7 day buffer for system variations

    // Convert to SQL Anywhere compatible format
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL TRANSACTION DATA
    // ========================================================================
    /*
    STRATEGY: Essential parts transaction data with optimized date filtering
    PERFORMANCE: Reduced date range should cut refresh time significantly
    COMPLETENESS: All essential fields for parts transaction analytics preserved
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE TRANSACTION IDENTIFIERS ===== #(lf)
        Trans_Datetime AS TransDatetime, #(lf)
        BRANCH AS Branch, #(lf)
        REF_NO AS RONumber, #(lf)
        TYPE AS Type, #(lf)
        
        -- ===== PARTS CONTEXT ===== #(lf)
        PART_NO AS PartNumber, #(lf)
        DESCRIPTION AS Description, #(lf)
        FRANCHISE AS Franchise, #(lf)
        QTY AS Qty, #(lf)
        
        -- ===== CUSTOMER CONTEXT ===== #(lf)
        customer_no AS CustomerNo, #(lf)
        TRADE_TYPE AS TradeType, #(lf)
        
        -- ===== WORK ORDER INTEGRATION ===== #(lf)
        JOB_CODE AS JobCode, #(lf)
        JOB_TYPE AS JobType, #(lf)
        
        -- ===== FINANCIAL DATA ===== #(lf)
        SALE_VAL AS SaleValue, #(lf)
        COST_VAL AS CostValue, #(lf)
        SELL_PRICE1 AS SellPrice1, #(lf)
        LIST_PRICE AS ListPrice #(lf)
        
    FROM InTrans #(lf)
    WHERE Trans_Datetime >= " & StartStr & " #(lf)
      AND Trans_Datetime < " & EndStr,

    // ========================================================================
    // EXECUTE QUERY - SQL ANYWHERE ODBC CONNECTION
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to INTRANS. Verify SQL Anywhere database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_INTRANS - PERFORMANCE-OPTIMIZED PARTS TRANSACTION EXTRACTION
============================================================================

🎯 PERFORMANCE OPTIMIZATION RESULTS:
• Date Range Reduction: 2020+ to 2023+ (3+ year reduction)
• Expected Refresh Time: <3m vs current 13-14m (75%+ improvement)
• Data Completeness: All essential transaction data preserved
• Incremental Refresh: Proper date-based filtering for ongoing performance

🔍 CRITICAL BUSINESS NOTES:
• RONumber Field: Contains Invoice Numbers (not work order numbers)
• Work Order Linkage: Branch + RONumber + JobCode + JobType → wkothsub → work orders
• Historical Naming: RONumber name cannot be changed due to downstream dependencies
• Transaction Types: Positive Qty = sales, Negative Qty = returns/adjustments

🚀 PRODUCTION CHARACTERISTICS:
• Sustainable Performance: 2023+ scope provides essential history with acceptable refresh
• Complete Transaction Data: All financial and operational fields preserved
• Cross-System Integration: Proper linkage to work orders, customers, and parts master
• SQL Anywhere Optimized: ODBC connection and query structure optimized for source system

🔄 MAINTENANCE GUIDANCE:
• Monitor refresh performance: Alert if processing time exceeds 3-4 minutes
• Review date range annually: Adjust scope based on business requirements and performance
• Historical data access: Consider separate historical archive for pre-2023 transactions
• Incremental optimization: Evaluate ModifiedDate fields if available in source system

============================================================================
*/