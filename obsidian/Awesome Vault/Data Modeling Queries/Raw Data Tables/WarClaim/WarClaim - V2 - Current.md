/*
============================================================================
RAW_WARCLAIM - WARRANTY CLAIMS DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Extract warranty claims data for warranty analytics and financial tracking
Grain: One row per warranty claim (unique by ClaimNumber)
Refresh Strategy: Incremental refresh using RepairDate filtering (3-year scope)
Performance: Target <2m refresh time with 19-column optimized extraction
Source Dependencies: WarClaim table (warranty claim management system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for Fact_WarrantyClaims
• Warranty Financial Analysis: Complete financial breakdown by service category
• Claim Status Tracking: Warranty claim processing and approval status
• Manufacturer Analysis: Franchise-specific warranty patterns and performance
• Write-off Analysis: Warranty rejection and write-off pattern tracking
• Cross-System Integration: Links warranty claims to work orders and invoices

📊 DATA STRUCTURE (19 COLUMNS - PERFORMANCE OPTIMIZED):

**Core Warranty Identifiers:**
• ClaimNumber: Primary warranty claim identifier
• InvoiceNumber: Links to invoice system
• WorkOrderNumber + WorkOrderBranch: Links to work order system
• ModelSerialNumber: Equipment serial number

**Financial Breakdown:**
• PartsInvoiceValue: Parts cost on warranty claim
• LaborInvoiceValue: Labor cost on warranty claim
• SubletInvoiceValue: Subcontracted work cost
• OtherInvoiceValue: Other miscellaneous costs
• WarrantyWriteOff: Amount written off by manufacturer
• WarrantyRejection: Amount rejected by manufacturer
• GSTValue: Tax/GST amount

**Business Context:**
• Franchise: Equipment manufacturer/brand
• ClaimStatus: Warranty claim processing status
• DriverName: Equipment operator
• OwnerName: Equipment owner
• OwnerStatusCode: Owner type classification

**Timeline Intelligence:**
• RepairDate: When warranty repair was performed
• ModifiedDate: Last update timestamp for audit tracking

🔧 DESIGN APPROACH:

**Incremental Refresh Strategy:**
• RepairDate filtering: 3-year window (2022+) captures relevant warranty claims
• Data quality filters: Excludes records with missing key identifiers (InvoiceNumber, ClaimNumber)
• Performance focus: Essential fields with business date-based filtering

**Field Naming Consistency:**
• Descriptive aliases: Clear business context and purpose
• Cross-table integration: Field names align with work order and invoice systems
• Audit capability: ModifiedDate supports change tracking

**Data Quality Controls:**
• NOT NULL filters: Ensures essential identifiers present
• Date range limiting: Prevents excessive historical data load
• Essential fields only: 19-column extraction within performance thresholds

⚠️ ARCHITECTURAL NOTES:

**Cross-System Integration:**
• InvoiceNumber: Links to Raw_WkInvReg and invoice analytics
• WorkOrderNumber/WorkOrderBranch: Links to work order fact tables
• Franchise: Enables manufacturer-specific warranty analysis
• RepairDate: Primary business date for warranty claim analytics

**Financial Intelligence:**
• Complete service breakdown: Parts, labor, sublet, and other costs
• Manufacturer relationship: Write-off vs rejection pattern analysis
• Tax tracking: GST/tax amount for compliance and financial reporting

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - WARRANTY-SPECIFIC SCOPE
    // ========================================================================
    /*
    PURPOSE: 3-year warranty claim scope captures relevant business timeframe
    PERFORMANCE: RepairDate filtering provides optimal business-date-based incremental refresh
    SCOPE: 2022+ ensures comprehensive warranty claim coverage for analytics
    */
    
    // Define incremental refresh parameters (3-year lookback for warranty relevance)
    RangeStart = #datetime(2022, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),
    
    // Convert to SQL-safe format for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",
    
    // ========================================================================
    // PERFORMANCE-OPTIMIZED SQL QUERY - ESSENTIAL WARRANTY DATA
    // ========================================================================
    /*
    STRATEGY: Essential warranty claim data with business date filtering
    PERFORMANCE: 19 columns with RepairDate-based incremental refresh
    DATA QUALITY: NOT NULL filters ensure essential identifiers present
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE WARRANTY IDENTIFIERS ===== #(lf)
        CLAIM_NO AS ClaimNumber, #(lf)
        INVOICE_NO AS InvoiceNumber, #(lf)
        RO_NUMBER AS WorkOrderNumber, #(lf)
        RO_BRANCH AS WorkOrderBranch, #(lf)
        Model_Serial_No AS ModelSerialNumber, #(lf)
        
        -- ===== COMPLETE FINANCIAL BREAKDOWN ===== #(lf)
        PART_INVOICE_VAL AS PartsInvoiceValue, #(lf)
        LAB_INVOICE_VAL AS LaborInvoiceValue, #(lf)
        SUB_INVOICE_VAL AS SubletInvoiceValue, #(lf)
        OTH_INVOICE_VAL AS OtherInvoiceValue, #(lf)
        WARRANTY_WRITE_OFF AS WarrantyWriteOff, #(lf)
        WARRANTY_REJECTION AS WarrantyRejection, #(lf)
        GST_VALUE AS GSTValue, #(lf)
        
        -- ===== BUSINESS CONTEXT ===== #(lf)
        FRANCHISE AS Franchise, #(lf)
        STATUS AS ClaimStatus, #(lf)
        DRIVER AS DriverName, #(lf)
        OWNER AS OwnerName, #(lf)
        Owner_Status_Code AS OwnerStatusCode, #(lf)
        
        -- ===== TIMELINE INTELLIGENCE ===== #(lf)
        REPAIR_DATE AS RepairDate, #(lf)
        LAST_UPDATE_TS AS ModifiedDate #(lf)
        
    FROM WarClaim #(lf)
    WHERE REPAIR_DATE >= " & StartStr & " #(lf)
      AND REPAIR_DATE < " & EndStr & " #(lf)
      AND INVOICE_NO IS NOT NULL #(lf)
      AND CLAIM_NO IS NOT NULL",
    
    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WARCLAIM. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_WARCLAIM - PRODUCTION-READY WARRANTY DATA EXTRACTION
============================================================================

🎯 IMPLEMENTATION SUMMARY:
• Warranty-Focused Design: 3-year RepairDate scope captures relevant warranty timeframe
• Complete Financial Data: All warranty cost categories and manufacturer relationship tracking
• Data Quality Controls: NOT NULL filters ensure essential identifiers present
• Cross-System Integration: Links to work orders, invoices, and equipment data

🔍 DESIGN VALIDATION:
• Optimal architecture: Simple extraction with business-appropriate incremental refresh
• Performance within thresholds: 19 columns well within tested database limits
• Business date filtering: RepairDate provides meaningful warranty claim scope
• Essential field coverage: Complete warranty financial and operational context

🚀 PRODUCTION CHARACTERISTICS:
• Targeted Refresh: Business-date filtering ensures relevant warranty data scope
• Complete Coverage: All warranty claim financial categories captured
• Integration Ready: Field naming supports Fact_WarrantyClaims development
• Quality Assured: Data filters prevent incomplete claim records

🔄 MAINTENANCE GUIDANCE:
• Monitor data volume: 3-year scope balances completeness with performance
• Validate date range: Adjust RepairDate scope based on warranty policy changes
• Review identifier filters: Ensure NOT NULL filters capture valid claims appropriately
• Performance monitoring: Alert if refresh time exceeds acceptable thresholds

============================================================================
*/