/*
============================================================================
RAW_INTRANS - PARTS TRANSACTION DATA EXTRACTION (INCREMENTAL REFRESH)
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract parts/inventory transaction data from SQL Anywhere database
Grain: One row per parts transaction (sales, returns, transfers, adjustments)
Refresh Strategy: Incremental refresh using Power BI automatic date range parameters
Performance: Leverages incremental refresh for optimal balance of data completeness and speed
Source Dependencies: InTrans table via SQL Anywhere ODBC connection

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for parts transaction fact tables
• Parts Sales Analysis: Revenue, margins, and customer purchasing patterns
• Work Order Parts: Parts used in service and repair work
• Inventory Management: Stock movement tracking and demand analysis
• Customer Analytics: Parts purchasing behavior and pricing analysis
• Financial Reporting: Parts revenue, cost of goods sold, and margin analysis
• Historical Analysis: Multi-year comparisons (Previous 36/48/60 month measures)

📊 ESSENTIAL DATA STRUCTURE (16 COLUMNS - COMPLETE TRANSACTION DATA):

**Core Transaction Identifiers:**
• TransDatetime: Transaction timestamp (primary business date - INCREMENTAL REFRESH KEY)
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

🔧 INCREMENTAL REFRESH DESIGN:

**Power BI Managed Date Filtering:**
• RangeStart and RangeEnd parameters automatically provided by Power BI
• Date range determined by incremental refresh policy settings (recommended: 5 years)
• No hardcoded date restrictions to conflict with incremental refresh system
• Supports historical measures requiring 36/48/60-month lookback periods

**Critical Field Mapping Notes:**
• RONumber contains Invoice Numbers (not work order numbers despite name)
• Work order linkage: Branch + RONumber + JobCode + JobType → wkothsub → work orders
• Historical naming cannot be changed due to downstream dependencies

⚡ INCREMENTAL REFRESH BENEFITS:
• Initial Load: Full historical data based on policy (5 years recommended)
• Ongoing Refreshes: Only new/modified data processed for optimal performance
• Historical Data: Complete data availability for all time-intelligence measures
• Scalability: Performance maintained as data volume grows over time

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - POWER BI MANAGED
    // ========================================================================
    /*
    STRATEGY: Use Power BI provided RangeStart and RangeEnd parameters
    BENEFIT: Automatic date range management based on incremental refresh policy
    CONFIGURATION: Set incremental refresh to 5 years to support 60-month lookback measures
    PERFORMANCE: Optimal balance of data completeness and refresh speed
    */
    
    // Power BI automatically provides these parameters when incremental refresh is enabled
    StartDate = RangeStart,
    EndDate = RangeEnd,

    // Convert to SQL Anywhere compatible format for WHERE clause
    StartStr = "'" & DateTime.ToText(StartDate, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(EndDate, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // INCREMENTAL REFRESH OPTIMIZED SQL QUERY
    // ========================================================================
    /*
    STRATEGY: Complete transaction data with Power BI managed date filtering
    PERFORMANCE: Incremental refresh handles date partitioning automatically
    COMPLETENESS: All essential fields for parts transaction analytics preserved
    SCALABILITY: Supports growing data volumes with consistent performance
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE TRANSACTION IDENTIFIERS ===== #(lf)
        Trans_Datetime AS TransDatetime, #(lf)
        ModifiedDate AS ModifiedDate, #(lf)
        CreationDate AS CreationDate, #(lf)
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
✅ RAW_INTRANS - INCREMENTAL REFRESH OPTIMIZED EXTRACTION
============================================================================

🎯 INCREMENTAL REFRESH IMPLEMENTATION:
• Date Range Management: Fully automated by Power BI incremental refresh policy
• Historical Data Support: Configurable range supports multi-year lookback measures
• Performance Optimization: Ongoing refreshes process only new/changed data
• Data Completeness: Complete transaction history based on policy configuration

🔧 INCREMENTAL REFRESH CONFIGURATION REQUIRED:
• Enable incremental refresh on this table
• Set "Extract data from the past: 5 Years" (to support 60-month measures)
• Choose Date/DateTime column: "TransDatetime"
• Set bucket size: "Month" (recommended for transaction data)
• Configure detect data changes: "ModifiedDate" (if available)

🔍 CRITICAL BUSINESS NOTES:
• RONumber Field: Contains Invoice Numbers (not work order numbers)
• Work Order Linkage: Branch + RONumber + JobCode + JobType → wkothsub → work orders
• Historical Naming: RONumber name cannot be changed due to downstream dependencies
• Transaction Types: Positive Qty = sales, Negative Qty = returns/adjustments

🚀 PRODUCTION CHARACTERISTICS:
• Scalable Performance: Maintains speed as historical data grows
• Complete Historical Access: Supports Previous 36/48/60 Sales measures
• Automatic Management: No manual date range adjustments required
• SQL Anywhere Optimized: ODBC connection and query structure optimized for source

📊 MEASURE SUPPORT ENABLED:
• Previous 12 Sales: ✓ Supported
• Previous 24 Sales: ✓ Supported  
• Previous 36 Sales: ✓ Supported (requires 5-year policy)
• Previous 48 Sales: ✓ Supported (requires 5-year policy)
• Previous 60 Sales: ✓ Supported (requires 5-year policy)

🔄 MAINTENANCE GUIDANCE:
• Monitor incremental refresh performance in Power BI service
• Review policy settings annually based on business requirements
• Verify "Previous XX Sales" measures populate correctly after policy change
• Consider ModifiedDate for change detection if available in source system
• No manual date range adjustments needed - Power BI handles automatically

⚠️ DEPLOYMENT STEPS:
1. Deploy this updated query to replace existing version
2. Configure incremental refresh policy to 5 years
3. Perform initial refresh (will load 5 years of historical data)
4. Verify Previous 36/48/60 Sales measures populate with data
5. Monitor ongoing refresh performance (should be significantly faster)

============================================================================
*/