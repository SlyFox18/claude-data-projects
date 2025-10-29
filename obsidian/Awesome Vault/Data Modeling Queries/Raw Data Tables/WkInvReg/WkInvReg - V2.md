/*
============================================================================
RAW_WKINVREG - ENHANCED INVOICE & FINANCIAL INTELLIGENCE FOR WORK ORDER ANALYTICS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete invoice register with comprehensive financial breakdown and billing intelligence
Grain: One row per invoice per work order (invoice-level financial transaction record)
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering for optimal performance)
Current Performance: 1 minute baseline - enhanced version targets 1-1.5 minutes
Source Dependencies: WkInvReg table (invoice registration and financial tracking system)

🎯 BUSINESS USE CASES:
• Invoice Analytics: Complete invoice tracking with financial breakdown across all service categories
• Revenue Analysis: Labor, parts, other services, and sublet revenue classification and analysis
• Customer Billing: Account-level billing analysis and customer payment pattern tracking
• Equipment Service Revenue: Vehicle/equipment-specific service revenue and profitability analysis
• Territory Financial Performance: Branch-level revenue analysis and geographic profitability
• Service Mix Profitability: Understanding revenue composition across service categories
• Tax Intelligence: Service tax analysis and compliance reporting for financial accuracy
• Cross-Fact Foundation: Invoice-level data supporting financial and profitability fact tables

📊 KEY ENHANCEMENTS ADDED:
• Complete Financial Breakdown: Labor, Parts, Other Services, and Sublet revenue components
• Invoice Classification: Credit note vs invoice identification for accurate revenue reporting
• Equipment Integration: Vehicle registration and stock numbers for equipment-level analysis
• Business Context: Trade type classification and sales advisor assignment for performance analysis
• Tax Intelligence: Service tax values for comprehensive financial and compliance analysis
• Timeline Enhancement: Invoice creation date for complete billing lifecycle tracking
• Revenue Intelligence: Complete service revenue categorization for profitability analysis

⚡ PERFORMANCE CONSIDERATIONS:
Enhanced query maintains incremental refresh capability while adding significant financial intelligence. Strategic column selection balances comprehensive revenue analysis with 1-1.5 minute refresh time target, preserving excellent performance profile.

🔄 REFRESH STRATEGY:
Incremental refresh pattern using ModifiedDate-based filtering captures all invoice modifications since 2023. Approach ensures optimal performance while maintaining comprehensive financial coverage for revenue and profitability analysis.

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    /*
    PURPOSE: Consistent date filtering across all raw tables for optimal performance
    APPROACH: ModifiedDate filtering captures recent invoice modifications and new records
    BUSINESS LOGIC: Any invoice modified since 2023 is relevant for financial analysis
    */
    
    // Define parameters for refresh control (standard across all raw tables)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format for query folding optimization
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // ENHANCED SQL QUERY - COMPREHENSIVE FINANCIAL INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Extract comprehensive invoice and financial data for complete revenue analytics
    STRATEGY: Balance comprehensive financial intelligence with 1-minute refresh performance
    ENHANCEMENTS: Added complete financial breakdown and business context fields
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE INVOICE IDENTIFIERS ===== #(lf)
        DOCUMENT_NO AS InvoiceNumber, #(lf)
        BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        RO_TYPE AS ROType, #(lf)
        CHARGE_ACCT AS AccountNumber, #(lf)
        
        -- ===== COMPREHENSIVE FINANCIAL BREAKDOWN ===== #(lf)
        -- Labor Financial Intelligence #(lf)
        LABOUR_COST AS LabourCost, #(lf)
        LABOUR_CHARGED AS LabourCharged, #(lf)
        CALCULATED_LABOUR AS CalculatedLabour, #(lf)
        
        -- Complete Service Revenue Breakdown #(lf)
        PARTS_VALUE AS PartsValue, #(lf)
        OTHER_VALUE AS OtherValue, #(lf)
        SUBLET_VALUE AS SubletValue, #(lf)
        INVOICE_VALUE AS InvoiceTotal, #(lf)
        
        -- Tax & Financial Intelligence #(lf)
        serv_tax_val AS ServiceTaxValue, #(lf)
        INVOICE_CREDIT AS InvoiceCredit, #(lf)
        
        -- ===== EQUIPMENT & BUSINESS CONTEXT ===== #(lf)
        FRANCHISE AS Franchise, #(lf)
        REG AS Registration, #(lf)
        STOCK_NO AS StockNumber, #(lf)
        TRADE_TYPE AS TradeType, #(lf)
        SALES_ADVISOR AS SalesAdvisor, #(lf)
        
        -- ===== BUSINESS INTELLIGENCE ===== #(lf)
        STOCK_SOLD AS IsStockSold, #(lf)
        SUB_CUSTOMER_NO AS SubCustomerNumber, #(lf)
        PERIOD_NO AS AccountingPeriod, #(lf)
        
        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        WORK_DATE AS WorkDate, #(lf)
        CreationDate AS CreatedOn, #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM WkInvReg #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RO_NUMBER",

    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKINVREG. Check connection and table availability.",

    // ========================================================================
    // DATA TYPE OPTIMIZATION - MAINTAIN PERFORMANCE
    // ========================================================================
    /*
    PURPOSE: Optimize data types for financial calculations and dimensional modeling
    APPROACH: Strategic type conversion for analytical efficiency
    STRATEGY: Balance type safety with performance preservation
    */
    
    OptimizedData = Table.TransformColumnTypes(Source,{
        // Core identifiers
        {"InvoiceNumber", type text},
        {"Branch", type text},
        {"WorkOrder", type text},
        {"ROType", type text},
        {"AccountNumber", type text},
        
        // Financial fields - use currency type for accurate calculations
        {"LabourCost", Currency.Type},
        {"LabourCharged", Currency.Type},
        {"CalculatedLabour", Currency.Type},
        {"PartsValue", Currency.Type},
        {"OtherValue", Currency.Type},
        {"SubletValue", Currency.Type},
        {"InvoiceTotal", Currency.Type},
        {"ServiceTaxValue", Currency.Type},
        
        // Classification and context
        {"InvoiceCredit", type text},
        {"Franchise", type text},
        {"Registration", type text},
        {"StockNumber", type text},
        {"TradeType", type text},
        {"SalesAdvisor", type text},
        {"IsStockSold", type text},
        {"SubCustomerNumber", type text},
        {"AccountingPeriod", Int64.Type},
        
        // Timeline fields
        {"WorkDate", type datetime},
        {"CreatedOn", type datetime},
        {"ModifiedDate", type datetime}
    })

in
    OptimizedData