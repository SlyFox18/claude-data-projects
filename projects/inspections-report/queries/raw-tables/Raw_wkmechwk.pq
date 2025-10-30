/*
============================================================================
RAW_WKMECHWK - PERFORMANCE-OPTIMIZED LABOR DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean, efficient extraction of labor data from wkmechwk system table
Grain: Individual labor entries per technician per job
Refresh Strategy: Incremental refresh using ModifiedDate filtering (2023+ scope)
Performance: Target <2m refresh time with optimized column selection
Source Dependencies: wkmechwk table (technician labor tracking system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for Fact_LaborJobs
• Labor Time Tracking: Clock-in dates, start/finish times, and hours data
• Financial Analysis: Labor cost and sale amounts for profitability tracking
• Operational Context: Delay tracking and work categorization
• Technician Analytics: Individual labor performance and efficiency baseline
• Cross-Fact Integration: Work order and job relationships

📊 ESSENTIAL DATA STRUCTURE (TARGET: ~18 COLUMNS):

**Core Labor Identifiers:**
• Branch: Work order branch identifier
• WorkOrder: Work order number
• JobCode: Job code classification
• JobType: Job type indicator
• TechCode: Technician identifier
• SequenceNumber: Labor entry sequence

**Time Tracking:**
• ClockInDate: Labor clock-in date
• StartTime: Labor start time
• FinishTime: Labor finish time
• InvoiceHours: Billable hours
• HoursWorked: Actual work hours
• HoursRework: Rework hours

**Financial Data:**
• LaborCost: Labor cost amount
• LaborSale: Labor sale/billing amount

**Operational Context:**
• DelayCode: Delay reason code
• DelayHours: Delay time tracking
• LaborType: Labor classification
• WorkCategory: Work category classification

**Data Governance:**
• ModifiedDate: Last modification for incremental refresh

🔧 DESIGN PRINCIPLES APPLIED:

**Raw Table Architecture:**
• Simple extraction: No business logic calculations
• Essential fields: Focus on actual downstream usage
• Performance priority: Speed over theoretical completeness
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
    STRATEGY: Essential labor data extraction with simple field aliasing
    PERFORMANCE: ~18 columns to stay within tested performance thresholds
    NAMING: Consistent with other optimized raw tables
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE LABOR IDENTIFIERS ===== #(lf)
        RO_BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        JOB_CODE AS JobCode, #(lf)
        JOB_TYPE AS JobType, #(lf)
        MECHANIC_CODE AS TechCode, #(lf)
        SEQ AS SequenceNumber, #(lf)
        
        -- ===== TIME TRACKING ===== #(lf)
        DATE_CLOCKED_IN AS ClockInDate, #(lf)
        START_TIME AS StartTime, #(lf)
        FINISH_TIME AS FinishTime, #(lf)
        INVOICE_HRS AS InvoiceHours, #(lf)
        HOURS_WORK AS HoursWorked, #(lf)
        HOURS_REWORK AS HoursRework, #(lf)
        
        -- ===== FINANCIAL DATA ===== #(lf)
        COST_VAL AS LaborCost, #(lf)
        SELL_VAL AS LaborSale, #(lf)
        
        -- ===== OPERATIONAL CONTEXT ===== #(lf)
        DELAY_CODE AS DelayCode, #(lf)
        DELAY_HOURS AS DelayHours, #(lf)
        Labor_Type AS LaborType, #(lf)
        Work_Cat AS WorkCategory, #(lf)
        
        -- ===== DATA GOVERNANCE ===== #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM wkmechwk #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, RO_BRANCH, RO_NUMBER, SEQ",
    
    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to WKMECHWK. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_WKMECHWK - OPTIMIZED FOR PERFORMANCE & SIMPLICITY
============================================================================

🎯 OPTIMIZATION RESULTS:
• Removed Business Logic: All calculated fields moved to fact table layer
• Essential Fields Only: 19 columns focused on actual downstream needs
• Performance Priority: Simple extraction maintains target <2m refresh time
• Fact Table Ready: Clean data foundation for Fact_LaborJobs processing

🔍 BUSINESS LOGIC MOVED TO FACT TABLES:
• LaborEfficiency: (InvoiceHours / HoursWorked) calculated in Fact_LaborJobs
• LaborMargin: (LaborSale - LaborCost) calculated in Fact_LaborJobs
• TotalHours: (HoursWorked + HoursRework) calculated in Fact_LaborJobs
• HasRework: (HoursRework > 0) calculated in Fact_LaborJobs
• HasDelay: (DelayHours > 0) calculated in Fact_LaborJobs
• WorkOrderKey: (Branch + "-" + WorkOrder) calculated in Fact_LaborJobs

🚀 EXPECTED BENEFITS:
• Improved Performance: Simple extraction vs complex transformations
• Sustainable Architecture: Business logic in appropriate layer
• Easier Maintenance: Single responsibility for raw data extraction
• Reliable Performance: Within tested column count thresholds

============================================================================
*/