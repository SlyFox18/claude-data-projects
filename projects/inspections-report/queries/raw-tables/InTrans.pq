/*
============================================================================
RAW_INTRANS - TEMPORARY FULL LOAD QUERY (5.5 YEARS)
============================================================================

⚠️ TEMPORARY QUERY FOR INITIAL FULL LOAD ONLY ⚠️

📋 PURPOSE:
• Load 5.5 years of historical data to support Previous 60 Sales measures
• Bypass incremental refresh issues by doing controlled full load first
• After successful load, switch back to incremental refresh version

🎯 STRATEGY:
• Hardcoded 5.5-year date range ensures adequate historical data
• Conservative buffer (66 months vs 60 required) prevents edge cases
• Same field structure as incremental refresh version for consistency

⚠️ DEPLOYMENT PROCESS:
1. Deploy this query to replace current version
2. Disable incremental refresh temporarily  
3. Run full refresh to load 5.5 years of data
4. Validate Previous 60 Sales measures populate correctly
5. Switch back to incremental refresh query
6. Re-enable incremental refresh with proper settings

============================================================================
*/

let
    // ========================================================================
    // TEMPORARY HARDCODED DATE RANGE - 5.5 YEARS FOR SAFETY BUFFER
    // ========================================================================
    /*
    PURPOSE: Ensure adequate historical data for 60-month lookback measures
    RANGE: 5.5 years (66 months) provides safety buffer beyond 60-month requirement
    TEMPORARY: Will be replaced with incremental refresh version after initial load
    */
    
    // Calculate 5.5 years back from today for safety buffer
    RangeStart = Date.AddYears(Date.From(DateTime.LocalNow()), -6),  // 6 years to be extra safe
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL Anywhere compatible format
    StartStr = "'" & Date.ToText(RangeStart, "yyyy-MM-dd") & " 00:00:00'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // FULL HISTORICAL DATA SQL QUERY
    // ========================================================================
    /*
    STRATEGY: Complete transaction data with controlled 6-year date range
    PERFORMANCE: Will take longer than usual but ensures complete historical coverage
    COMPLETENESS: All essential fields preserved for fact table transformation
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
⚠️ DEPLOYMENT AND VALIDATION CHECKLIST ⚠️
============================================================================

🔧 DEPLOYMENT STEPS:
1. ✅ Temporarily disable incremental refresh on InTrans table
2. ✅ Deploy this query to replace current InTrans query
3. ✅ Run full refresh (expect longer refresh time - possibly 10-15 minutes)
4. ✅ Validate data loaded successfully with date range validation query
5. ✅ Test Previous 36/48/60 Sales measures - should now show data
6. ✅ Switch back to incremental refresh version of query
7. ✅ Re-enable incremental refresh with 5-year policy and quarterly buckets

📊 EXPECTED RESULTS:
• Data Range: Should span approximately 2018-2024 (6+ years)
• Previous 60 Sales: Should populate with historical data
• Previous 48 Sales: Should populate with historical data  
• Previous 36 Sales: Should populate with historical data
• Refresh Time: Longer than usual (potentially 10-15 minutes) but one-time cost

🔍 VALIDATION QUERIES TO RUN AFTER DEPLOYMENT:
• Date Range Validation: Verify 6+ years of data loaded
• Measure Testing: Check Previous 60 Sales shows values, not blanks
• Record Count: Compare total records vs previous version

⚠️ IMPORTANT REMINDERS:
• This is TEMPORARY - switch back to incremental refresh version after validation
• Do NOT leave this hardcoded version in production long-term
• Full refresh with this query will take significantly longer than usual
• Once validated, incremental refresh will provide ongoing performance benefits

🎯 SUCCESS CRITERIA:
• EarliestDate: Should be 2018 or earlier
• Previous 60 Sales measures: Should show actual values instead of blanks
• Data completeness: Should have 70+ months of transaction data
• Ready for incremental refresh: Can then deploy incremental version safely

============================================================================
*/