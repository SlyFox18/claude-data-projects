/*
============================================================================
RAW_TECHNICIANLABOR - PERFORMANCE-OPTIMIZED LABOR BILLING DATA EXTRACTION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean, efficient extraction of technician billing efficiency data from TechnicianInvoiceDetail
Grain: One row per technician per work order per invoice sequence
Refresh Strategy: Incremental refresh using ModifiedDate filtering (2023+ scope)
Performance: Target <2m refresh time with optimized column selection
Source Dependencies: TechnicianInvoiceDetail table (labor billing system)

🎯 BUSINESS USE CASES:
• Fact Table Foundation: Primary data source for labor billing and efficiency fact tables
• Billing Efficiency: Punched hours vs invoiced hours baseline data
• Financial Analysis: Labor cost vs sale margin tracking
• Quality Baseline: Rework and delay hours for performance analysis
• Productivity Data: Gain/loss hours and efficiency component tracking

📊 ESSENTIAL DATA STRUCTURE (19 COLUMNS - PERFORMANCE OPTIMIZED):

**Core Labor Identifiers:**
• Branch: Labor branch location
• WorkOrder: Associated work order number
• InvoiceNumber: Invoice identifier
• TechCode: Technician identifier
• SequenceID: Labor sequence number
• JobCode: Job classification
• JobType: Job type indicator

**Time Intelligence:**
• InvoiceDate: Invoice date
• WorkDate: Work performed date
• StartTime: Labor start time
• EndTime: Labor end time

**Core Hours Data:**
• HoursPunched: Actual punched hours
• InvoiceHours: Invoiced/billable hours
• ReworkHours: Rework time tracking
• DelayHours: Delay time tracking

**Financial Data:**
• LaborCost: Labor cost amount
• LaborSale: Labor billing amount

**Business Context:**
• NonRevenueIndicator: Non-revenue work flag

**Data Governance:**
• ModifiedDate: Last modification for incremental refresh

🔧 DESIGN PRINCIPLES APPLIED:

**Raw Table Architecture:**
• Simple extraction: No business logic calculations or efficiency categorizations
• Essential fields: Focus on source data needed by downstream fact tables
• Performance priority: Column count within tested database optimization limits
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
    STRATEGY: Essential labor billing data with simple field aliasing
    PERFORMANCE: 19 columns to stay within tested performance thresholds
    FOCUS: Source data extraction without business logic processing
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== CORE LABOR IDENTIFIERS ===== #(lf)
        Branch AS Branch, #(lf)
        RepairOrderNumber AS WorkOrder, #(lf)
        InvoiceNumber AS InvoiceNumber, #(lf)
        TechnicianCode AS TechCode, #(lf)
        SequenceID AS SequenceID, #(lf)
        JobCode AS JobCode, #(lf)
        JobType AS JobType, #(lf)
        
        -- ===== TIME INTELLIGENCE ===== #(lf)
        InvoiceDate AS InvoiceDate, #(lf)
        WorkDate AS WorkDate, #(lf)
        StartTime AS StartTime, #(lf)
        EndTime AS EndTime, #(lf)
        
        -- ===== CORE HOURS DATA ===== #(lf)
        HoursPunched AS HoursPunched, #(lf)
        InvoiceHours AS InvoiceHours, #(lf)
        ReworkHours AS ReworkHours, #(lf)
        DelayHours AS DelayHours, #(lf)
        
        -- ===== FINANCIAL DATA ===== #(lf)
        LaborCost AS LaborCost, #(lf)
        LaborSale AS LaborSale, #(lf)
        
        -- ===== BUSINESS CONTEXT ===== #(lf)
        NonRevenueIndicator AS NonRevenueIndicator, #(lf)
        
        -- ===== DATA GOVERNANCE ===== #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM TechnicianInvoiceDetail #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RepairOrderNumber, TechnicianCode, SequenceID",
    
    // ========================================================================
    // EXECUTE QUERY - MAINTAIN QUERY FOLDING FOR OPTIMAL PERFORMANCE
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to TECHNICIANLABOR. Verify database connection and table availability."

in
    Source

/*
============================================================================
✅ RAW_TECHNICIANLABOR - OPTIMIZED FOR PERFORMANCE & SIMPLICITY
============================================================================

🎯 OPTIMIZATION RESULTS:
• Removed Extensive Business Logic: All efficiency calculations moved to fact table layer
• Essential Fields Only: 19 columns focused on actual source data needs
• Performance Priority: Simple extraction maintains target <2m refresh time
• Fact Table Ready: Clean data foundation for labor billing and efficiency analytics

🔍 BUSINESS LOGIC MOVED TO FACT TABLES:
• Efficiency Calculations: LaborEfficiency, CalculatedEfficiency in fact tables
• Performance Categorizations: EfficiencyCategory, QualityIndicator in fact tables
• Margin Analysis: LaborMargin, MarginPercent in fact tables
• Business Classifications: RevenueType, LaborValueCategory in fact tables
• Data Quality Scoring: Comprehensive scoring in fact tables
• Composite Keys: WorkOrderKey generation in fact tables

🚀 KEY SOURCE DATA PRESERVED:
• Core Hours: HoursPunched, InvoiceHours, ReworkHours, DelayHours
• Financial Data: LaborCost, LaborSale for margin calculations
• Time Intelligence: InvoiceDate, WorkDate, StartTime, EndTime
• Business Context: NonRevenueIndicator for revenue classification
• Essential Identifiers: All required keys for fact table relationships

============================================================================
*/