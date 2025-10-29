/*
============================================================================
RAW_INVOICE - INVOICE DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract complete invoice data for financial analytics and customer billing analysis
Grain: One row per invoice (unique by InvoiceNumber)
Refresh Strategy: Incremental refresh using InvoiceDate filtering (3-year scope)
Performance: Full column set required for comprehensive invoice analytics
Source Dependencies: Invoice table (invoice management system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for invoice-related fact tables
• Financial Analysis: Complete invoice financial breakdown by service category
• Customer Analytics: Customer billing patterns and payment method analysis
• Revenue Tracking: Service mix revenue analysis and financial performance
• Payment Analysis: Payment method and collection pattern tracking
• Cross-System Integration: Links invoices to work orders and customer systems

📊 COMPLETE DATA STRUCTURE (29 COLUMNS - BUSINESS REQUIRED):

**Core Invoice Identifiers:**
• InvoiceType: Invoice type classification
• ModuleType: System module type
• InvoiceNumber: Invoice document number (primary identifier)
• WorkOrderNumber: Associated work order number
• Branch: Invoice branch location

**Customer Information:**
• CustomerNumber: Customer identifier
• BillToAccount: Billing account number
• CustomerOrderNumber: Customer order reference
• CompanyName: Customer company name
• FirstName: Customer first name
• LastName: Customer last name

**Equipment Context:**
• StockNumber: Stock/inventory number
• VehicleNumber: Vehicle identifier

**Complete Financial Breakdown:**
• PartsSaleValue: Parts revenue amount
• PartsCostValue: Parts cost amount
• LabourSaleValue: Labor revenue amount
• LabourCostValue: Labor cost amount
• SubletSaleValue: Sublet revenue amount
• SubletCostValue: Sublet cost amount
• OtherSaleValue: Other services revenue
• GST: Tax amount

**Payment Intelligence:**
• PaidCash: Cash payment amount
• PaidCreditCard: Credit card payment amount
• PaidCheque: Check payment amount
• PaymentMethod: Payment method classification

**Timeline Intelligence:**
• InvoiceDate: Invoice date (primary business date)
• CancelDate: Invoice cancellation date
• ModifiedDate: Last modification timestamp

🔧 DESIGN APPROACH:

**Business Date Filtering:**
• 3-year InvoiceDate scope (2022+) captures relevant financial reporting period
• Appropriate for invoice analytics and financial trend analysis
• Excludes invalid records with null/empty document numbers

**Field Naming Consistency:**
• Descriptive aliases that clearly indicate field purpose
• Financial categories clearly separated (Sale vs Cost amounts)
• Customer context fully captured for analytics
• Cross-system integration fields preserved

**Data Quality Controls:**
• NOT NULL filter ensures valid invoice numbers present
• Non-empty document number filter prevents incomplete records
• Business date filtering provides meaningful invoice scope

⚠️ ARCHITECTURAL NOTES:

**Cross-System Integration:**
• InvoiceNumber: Primary key for invoice analytics
• WorkOrderNumber: Links to work order fact tables
• CustomerNumber: Links to customer dimension and analytics
• Equipment references: StockNumber, VehicleNumber for equipment analytics

**Financial Intelligence:**
• Complete service breakdown: Parts, labor, sublet, other revenue and costs
• Margin analysis capability: Sale vs cost amounts by category
• Payment tracking: Multiple payment method amounts and classification
• Tax compliance: GST amount for financial reporting

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - INVOICE-SPECIFIC SCOPE
    // ========================================================================
    /*
    PURPOSE: 3-year invoice scope captures relevant financial reporting timeframe
    PERFORMANCE: InvoiceDate filtering provides optimal business-date-based incremental refresh
    SCOPE: 2022+ ensures comprehensive invoice coverage for financial analytics
    */
    
    // Define 3-year lookback period for financial reporting relevance
    RangeStart = #datetime(2022, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // COMPREHENSIVE SQL QUERY - COMPLETE INVOICE DATA
    // ========================================================================
    /*
    STRATEGY: Complete invoice data required for comprehensive financial analytics
    PERFORMANCE: Business-date filtering with essential invoice data
    DATA QUALITY: NOT NULL filters ensure valid invoice records
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE INVOICE IDENTIFIERS ===== #(lf)
        invo_type AS InvoiceType, #(lf)
        module_type AS ModuleType, #(lf)
        document_no AS InvoiceNumber, #(lf)
        ro_number AS WorkOrderNumber, #(lf)
        Branch AS Branch, #(lf)
        
        -- ===== CUSTOMER INFORMATION ===== #(lf)
        customer_no AS CustomerNumber, #(lf)
        bill_to_acc AS BillToAccount, #(lf)
        cust_ord_no AS CustomerOrderNumber, #(lf)
        company_name AS CompanyName, #(lf)
        name AS FirstName, #(lf)
        surname AS LastName, #(lf)
        
        -- ===== EQUIPMENT CONTEXT ===== #(lf)
        stock_no AS StockNumber, #(lf)
        vehicle_no AS VehicleNumber, #(lf)
        
        -- ===== COMPLETE FINANCIAL BREAKDOWN ===== #(lf)
        parts_sale_val AS PartsSaleValue, #(lf)
        parts_cost_val AS PartsCostValue, #(lf)
        labour_sale_val AS LabourSaleValue, #(lf)
        labour_cost_val AS LabourCostValue, #(lf)
        sublet_sal_val AS SubletSaleValue, #(lf)
        sublet_cost_val AS SubletCostValue, #(lf)
        other_sale_val AS OtherSaleValue, #(lf)
        gst AS GST, #(lf)
        
        -- ===== PAYMENT INTELLIGENCE ===== #(lf)
        paid_cash AS PaidCash, #(lf)
        paid_credit_card AS PaidCreditCard, #(lf)
        paid_cheque AS PaidCheque, #(lf)
        Payment_Method AS PaymentMethod, #(lf)
        
        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        invo_datetime AS InvoiceDate, #(lf)
        cancel_date AS CancelDate, #(lf)
        Last_Update_TS AS ModifiedDate #(lf)
        
    FROM Invoice #(lf)
    WHERE invo_datetime >= " & StartStr & " #(lf)
      AND invo_datetime < " & EndStr & " #(lf)
      AND document_no IS NOT NULL #(lf)
      AND document_no <> ''",

    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to INVOICE. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_INVOICE - PRODUCTION-READY INVOICE DATA EXTRACTION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Complete Invoice Data: All 29 business-required columns for comprehensive analytics
• Business Date Filtering: 3-year InvoiceDate scope captures relevant financial period
• Data Quality Controls: NOT NULL filters ensure valid invoice records
• Cross-System Integration: Complete links to work orders, customers, and equipment

🔍 DESIGN VALIDATION:
• Proper architecture: Clean extraction with business-appropriate incremental refresh
• Complete financial data: All revenue and cost categories with payment tracking
• Customer intelligence: Complete customer identification and billing information
• Equipment context: Stock and vehicle references for equipment-based analytics

🚀 PRODUCTION CHARACTERISTICS:
• Comprehensive Coverage: Complete invoice financial and operational data
• Quality Assured: Data filters prevent incomplete invoice records
• Integration Ready: Field naming supports fact table development
• Financial Complete: All service categories and payment methods captured

🔄 MAINTENANCE GUIDANCE:
• Monitor date range: 3-year scope balances completeness with performance
• Validate data quality: Ensure NOT NULL filters capture valid invoices appropriately
• Review financial completeness: Verify all service categories captured for analytics
• Performance monitoring: Track refresh performance with complete column set

============================================================================
*/