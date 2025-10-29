/*
============================================================================
RAW_WKOTHSUB - JOB-LEVEL FINANCIAL DATA FOUNDATION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean, efficient extraction of job-level financial data from wkothsub system table
Grain: One row per job code per work order (detailed job breakdown within work orders)
Refresh Strategy: Incremental refresh using ModifiedDate filtering
Performance Target: 1m 30s - 2m (optimized for speed with minimal SQL complexity)
Source Dependencies: wkothsub table (core job financial details)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Raw data source for Fact_LaborJobSummary and related tables
• Job Financial Analysis: Est/Act/Inv values across Labor, Parts, Other, and Sublet categories  
• Service Classification: Job types, work categories, and operational context
• Invoice Integration: Direct linkage to billing and invoicing processes
• Efficiency Baseline: Standard vs actual performance comparison data
• Operational Intelligence: Field service, machine downtime, and service priority indicators

📊 KEY DATA PROVIDED:
• Complete Financial Cycle: Estimated → Actual → Invoiced values for all service categories
• Job Classification: Job codes, types, work categories, and task identifiers
• Operational Context: Field service flags, machine downtime, promotional work indicators
• Standards Intelligence: Standard rate flags across all service categories  
• Billing Integration: Invoice numbers, dates, and claim number references
• Tax & Revenue: Service tax values and revenue classification flags

🔧 PERFORMANCE OPTIMIZATION STRATEGY:
• Minimal Column Selection: Only essential fields to maximize SQL query folding
• Simple SQL Logic: Complex business categorizations moved to fact table layer
• Efficient Filtering: ModifiedDate-based incremental refresh with optimized WHERE clause
• Clean Field Naming: Consistent naming conventions established at source level

🔄 REFRESH STRATEGY:
• Incremental Pattern: ModifiedDate >= 2023-01-01 captures relevant historical modifications
• Query Folding: Simple SQL maintains database-level filtering for optimal performance
• Data Freshness: Daily refresh captures all recent job modifications and updates

⚠️ DESIGN PRINCIPLES:
• Raw Table Purpose: Clean, fast data extraction - NOT business logic processing
• Fact Table Purpose: Business categorizations, calculations, and complex transformations
• Performance Priority: Speed over convenience - keep raw tables lean and efficient
• Consistency Focus: Standardized field naming that propagates cleanly through model

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    /*
    PURPOSE: Consistent incremental refresh approach across all raw tables
    PERFORMANCE: Simple date range filtering maintains optimal SQL query folding
    */
    
    // Standard incremental refresh parameters (align with other raw tables)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),

    // Convert to SQL-safe format for database query optimization
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",

    // ========================================================================
    // OPTIMIZED SQL QUERY - PERFORMANCE FOCUSED WITH CONSISTENT NAMING
    // ========================================================================
    /*
    PURPOSE: Fast, clean data extraction with standardized field naming
    STRATEGY: Minimal columns, simple aliasing, no complex business logic
    PERFORMANCE: Maintains 1m 30s refresh target by avoiding SQL complexity
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE WORK ORDER IDENTIFIERS ===== #(lf)
        RO_BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        JOB_CODE AS JobCode, #(lf)
        TYPE AS JobType, #(lf)
        DETAIL_LINE AS DetailLine, #(lf)
        sort_order AS SortOrder, #(lf)
        
        -- ===== LABOR FINANCIAL CYCLE (EST → ACT → INV) ===== #(lf)
        EST_LAB_VAL AS EstLabor, #(lf)
        Act_Lab_Val AS ActLabor, #(lf)
        Inv_Lab_Val AS InvLabor, #(lf)
        est_hours AS EstHours, #(lf)
        
        -- ===== PARTS FINANCIAL CYCLE ===== #(lf)
        EST_PART_VAL AS EstParts, #(lf)
        Act_Part_Val AS ActParts, #(lf)
        Inv_Part_Val AS InvParts, #(lf)
        
        -- ===== OTHER SERVICES FINANCIAL CYCLE ===== #(lf)
        EST_OTH_VAL AS EstOther, #(lf)
        Act_Oth_Val AS ActOther, #(lf)
        Inv_Oth_Val AS InvOther, #(lf)
        
        -- ===== SUBLET SERVICES FINANCIAL CYCLE ===== #(lf)
        EST_SUB_VAL AS EstSublet, #(lf)
        Act_Sub_Val AS ActSublet, #(lf)
        Inv_Sub_Val AS InvSublet, #(lf)
        
        -- ===== OPERATIONAL CLASSIFICATION ===== #(lf)
        Work_Cat AS WorkCategory, #(lf)
        Task_No AS TaskNumber, #(lf)
        STATUS AS JobStatus, #(lf)
        
        -- ===== OPERATIONAL FLAGS (CONSISTENT NAMING) ===== #(lf)
        Field_Repair AS IsFieldRepair, #(lf)
        Machine_Down_Ind AS IsMachineDown, #(lf)
        Special_Promo_Ind AS IsSpecialPromo, #(lf)
        non_revenue AS IsNonRevenue, #(lf)
        
        -- ===== STANDARDS INTELLIGENCE ===== #(lf)
        Std_Lab_Ind AS IsStandardLabor, #(lf)
        Std_Part_Ind AS IsStandardParts, #(lf)
        Std_Oth_Ind AS IsStandardOther, #(lf)
        Std_Sub_Ind AS IsStandardSublet, #(lf)
        Multiplier AS RateMultiplier, #(lf)
        
        -- ===== TAX & REVENUE INTELLIGENCE ===== #(lf)
        serv_tax_val AS ServiceTaxValue, #(lf)
        serv_taxable_val AS ServiceTaxableValue, #(lf)
        Tax_Region AS TaxRegion, #(lf)
        Tax_Cat AS TaxCategory, #(lf)
        
        -- ===== INVOICE & BILLING INTEGRATION ===== #(lf)
        INVOICE_NO AS InvoiceNumber, #(lf)
        INVOICE_DATE AS InvoiceDate, #(lf)
        CLAIM_NO AS ClaimNumber, #(lf)
        
        -- ===== AUDIT TRAIL ===== #(lf)
        Creation_Date AS CreatedOn, #(lf)
        Creator_Code AS CreatedBy, #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM wkothsub #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RO_NUMBER, sort_order",

    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE  
    // ========================================================================
    /*
    PURPOSE: Clean execution with error handling but no complex transformations
    STRATEGY: Let SQL handle all filtering and aliasing for maximum performance
    */
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKOTHSUB. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_WKOTHSUB - PERFORMANCE OPTIMIZED & DOCUMENTATION ENHANCED
============================================================================

🎯 PERFORMANCE IMPROVEMENTS:
• Removed Complex SQL Logic: Eliminated CASE statements that caused 18m refresh times
• Streamlined Column Selection: Focused on essential fields for downstream fact tables
• Simple Aliasing Only: Consistent naming without business logic complexity
• Pure Query Folding: Database handles all filtering and processing efficiently

🔄 FIELD NAMING STANDARDIZATION:
• Operational Flags: Consistent "Is" prefix (IsFieldRepair, IsMachineDown, etc.)
• Financial Cycles: Clear Est/Act/Inv pattern across Labor/Parts/Other/Sublet
• Work Order Context: Branch, WorkOrder, JobCode, JobType standard naming
• Standards Intelligence: Consistent "IsStandard" prefix pattern

📊 COMPLETE DATA FOUNDATION:
• All Financial Cycles: Complete Est → Act → Inv data for all service categories
• Operational Intelligence: All flags and classifications needed for fact tables  
• Business Integration: Invoice, claim, and billing context for complete analytics
• Audit Trail: Creation and modification tracking for data governance

⚡ EXPECTED PERFORMANCE:
• Target Refresh Time: 1m 30s - 2m (restored to original performance levels)
• Query Folding: 100% SQL-level processing maintains optimal database performance
• Data Volume: Efficient handling of large datasets through proper SQL optimization

🏗️ DOWNSTREAM IMPACT:
• Fact Table Ready: Clean, consistent data for all downstream fact table processing
• Business Logic Placement: Complex categorizations moved to appropriate fact table layer
• Cross-Fact Integration: Standardized naming enables reliable table relationships
• Documentation Foundation: Clear field definitions propagate through entire model

============================================================================
*/