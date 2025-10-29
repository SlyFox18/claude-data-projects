/*
============================================================================
RAW_WKINVREG - PERFORMANCE-OPTIMIZED INVOICE DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean, efficient extraction of invoice data from WkInvReg system table
Grain: One row per invoice per work order (invoice-level transaction record)
Refresh Strategy: Incremental refresh using ModifiedDate filtering (2023+ scope)
Performance: Target 1m - 1m 30s refresh time with optimized column selection
Source Dependencies: WkInvReg table (invoice registration system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for invoice-related fact tables
• Financial Analysis: Complete invoice financial breakdown (labor, parts, other, sublet)
• Revenue Tracking: Invoice totals and service category revenue analysis
• Customer Billing: Account-level invoice analysis and billing patterns
• Equipment Service: Vehicle-specific service revenue and patterns
• Cross-Fact Integration: Invoice data linking across work order analytics

📊 ESSENTIAL DATA STRUCTURE (TARGET: ~20 COLUMNS):

**Core Invoice Identifiers:**
• InvoiceNumber: Invoice document number (primary identifier)
• Branch: Invoice branch location
• WorkOrder: Associated work order number
• AccountNumber: Customer account identifier
• ROType: Work order type classification

**Complete Financial Breakdown:**
• LabourCost: Labor cost amount
• LabourCharged: Labor charged to customer
• PartsValue: Parts revenue amount
• OtherValue: Other services revenue
• SubletValue: Sublet services revenue
• InvoiceTotal: Total invoice amount
• ServiceTaxValue: Tax amount

**Equipment & Business Context:**
• Franchise: Manufacturer/franchise code
• Registration: Vehicle registration
• StockNumber: Stock/inventory number
• TradeType: Trade classification
• SalesAdvisor: Assigned sales advisor

**Timeline Intelligence:**
• WorkDate: Service work date
• CreatedOn: Invoice creation date
• ModifiedDate: Last modification for incremental refresh

🔧 DESIGN PRINCIPLES APPLIED:

**Raw Table Architecture:**
• Simple extraction: No business logic or currency type conversions
• Essential fields: Focus on actual downstream usage in fact tables
• Performance priority: Speed and reliability over theoretical completeness
• Clean naming: Consistent with other optimized raw tables

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL COLUMNS ONLY
    // ========================================================================
    /*
    STRATEGY: Essential invoice data with simple field aliasing
    PERFORMANCE: ~20 columns to stay within tested performance thresholds
    NAMING: Consistent with other optimized raw tables
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE INVOICE IDENTIFIERS ===== #(lf)
        DOCUMENT_NO AS InvoiceNumber, #(lf)
        BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        RO_TYPE AS ROType, #(lf)
        CHARGE_ACCT AS AccountNumber, #(lf)
        
        -- ===== COMPLETE FINANCIAL BREAKDOWN ===== #(lf)
        LABOUR_COST AS LabourCost, #(lf)
        LABOUR_CHARGED AS LabourCharged, #(lf)
        PARTS_VALUE AS PartsValue, #(lf)
        OTHER_VALUE AS OtherValue, #(lf)
        SUBLET_VALUE AS SubletValue, #(lf)
        INVOICE_VALUE AS InvoiceTotal, #(lf)
        serv_tax_val AS ServiceTaxValue, #(lf)
        
        -- ===== EQUIPMENT & BUSINESS CONTEXT ===== #(lf)
        FRANCHISE AS Franchise, #(lf)
        REG AS Registration, #(lf)
        STOCK_NO AS StockNumber, #(lf)
        TRADE_TYPE AS TradeType, #(lf)
        SALES_ADVISOR AS SalesAdvisor, #(lf)
        
        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        WORK_DATE AS WorkDate, #(lf)
        CreationDate AS CreatedOn, #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM WkInvReg #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RO_NUMBER",

    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKINVREG. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_WKINVREG - OPTIMIZED FOR PERFORMANCE & SIMPLICITY
============================================================================

🎯 OPTIMIZATION RESULTS:
• Removed Business Logic: Currency type conversions moved to fact table layer
• Essential Fields Only: 20 columns focused on actual downstream needs
• Performance Priority: Simple extraction maintains target 1m - 1m 30s refresh time
• Fact Table Ready: Clean data foundation for invoice fact table processing

🔍 BUSINESS LOGIC MOVED TO FACT TABLES:
• Currency Type Conversions: Applied in fact tables where financial calculations occur
• Financial Ratios: Labor cost vs charged analysis calculated in fact tables
• Revenue Classifications: Service category analysis handled in fact tables
• Business Categorizations: Trade type and advisor performance analysis in facts

🚀 EXPECTED BENEFITS:
• Maintained Performance: Should preserve or improve 1 minute baseline
• Sustainable Architecture: Business logic in appropriate architectural layer
• Column Count Control: 20 columns within tested performance thresholds
• Database Optimization: Simple extraction maintains query folding efficiency

============================================================================
*/