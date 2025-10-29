/*
============================================================================
RAW_WKMECHWK - COMPREHENSIVE LABOR TRACKING FOUNDATION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete technician labor data foundation for all analytics
Grain: Individual labor entries per technician per job
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering)
Dependencies: Source system wkmechwk table
Target Performance: <2 minutes refresh time

🎯 ENHANCED FEATURES:
• Complete financial data (cost, sell, calculated values)
• Actual punch times for precise efficiency calculations
• Delay tracking for operational improvement analysis
• Work categorization for business intelligence
• Comprehensive audit trail for data quality
• Cross-table relationship keys for dimensional modeling

📊 BUSINESS VALUE ADDED:
• Labor Cost Analysis: Full cost/sell/margin calculations
• Efficiency Tracking: Actual punch times vs invoice hours
• Operational Intelligence: Delay codes and categories for improvement
• Quality Tracking: Rework identification and analysis
• Productivity Analysis: Work categories and diagnostic patterns
• Financial Analysis: Complete revenue and cost attribution

⚡ OPTIMIZATION FEATURES:
• Incremental refresh via ModifiedDate filtering
• Essential column selection for performance
• Standardized naming for dimensional modeling
• Date range parameterization for flexibility
• SQL query folding for optimal lakehouse performance

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION PARAMETERS
    // ========================================================================
    /*
    PURPOSE: Centralized configuration for easy maintenance and optimization
    BUSINESS LOGIC: Align with business requirements and data retention policies
    PERFORMANCE: Date filtering significantly improves query performance
    */
    
    // Date range parameters (configurable for business needs)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),    // Align with business requirements
    RangeEnd = DateTime.LocalNow(),                   // Always current data
    
    // Convert to SQL-safe format for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",
    
    // ========================================================================
    // COMPREHENSIVE SQL QUERY WITH ENHANCED COLUMNS
    // ========================================================================
    /*
    PURPOSE: Extract complete labor data set for all analytical needs
    STRATEGY: Include all columns that provide business value
    PERFORMANCE: SQL query folding ensures optimal lakehouse performance
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== PRIMARY IDENTIFIERS ===== #(lf)
        RO_BRANCH AS Branch, #(lf)
        RO_NUMBER AS WorkOrder, #(lf)
        JOB_CODE AS JobCode, #(lf)
        JOB_TYPE AS JobType, #(lf)
        MECHANIC_CODE AS TechCode, #(lf)
        SEQ AS SequenceNumber, #(lf)
        
        -- ===== TIME TRACKING (ENHANCED) ===== #(lf)
        DATE_CLOCKED_IN AS ClockInDate, #(lf)
        START_TIME AS StartTime, #(lf)
        FINISH_TIME AS FinishTime, #(lf)
        INVOICE_HRS AS InvoiceHours, #(lf)
        HOURS_WORK AS HoursWorked, #(lf)
        HOURS_REWORK AS HoursRework, #(lf)
        
        -- ===== FINANCIAL DATA (COMPLETE) ===== #(lf)
        COST_VAL AS LaborCost, #(lf)
        SELL_VAL AS LaborSale, #(lf)
        CALC_SELL_VAL AS CalculatedSale, #(lf)
        REWORK_VAL AS ReworkValue, #(lf)
        
        -- ===== OPERATIONAL INTELLIGENCE ===== #(lf)
        DELAY_CODE AS DelayCode, #(lf)
        DELAY_HOURS AS DelayHours, #(lf)
        Delay_Comment AS DelayComment, #(lf)
        Labor_Type AS LaborType, #(lf)
        Diagnostic_Ind AS DiagnosticIndicator, #(lf)
        Work_Cat AS WorkCategory, #(lf)
        
        -- ===== BUSINESS FLAGS & INDICATORS ===== #(lf)
        Reversal_Ind AS ReversalIndicator, #(lf)
        Lab_Key AS LaborKey, #(lf)
        Billing_dept_code AS BillingDepartment, #(lf)
        
        -- ===== AUDIT TRAIL & RELATIONSHIPS ===== #(lf)
        CreationDate AS CreationDate, #(lf)
        ModifiedDate AS ModifiedDate, #(lf)
        WKOTHSUB_GUID_SO AS WorkOrderJobGUID #(lf)
        
    FROM wkmechwk #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate, RO_BRANCH, RO_NUMBER, SEQ",
    
    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    /*
    PURPOSE: Execute SQL with proper error handling and monitoring
    PERFORMANCE: Direct SQL execution with query folding
    */
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to data source. Check connection and permissions.",
    
    // ========================================================================
    // DATA TYPE OPTIMIZATION & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for downstream processing
    PERFORMANCE: Proper data types improve query performance and reduce memory usage
    BUSINESS LOGIC: Standardize formats for reliable dimensional modeling
    */
    
    StandardizedDataTypes = Table.TransformColumnTypes(Source, {
        // Primary identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"TechCode", type text}, {"SequenceNumber", Int64.Type},
        
        // Time tracking
        {"ClockInDate", type datetime}, {"StartTime", type datetime}, {"FinishTime", type datetime},
        {"InvoiceHours", type number}, {"HoursWorked", type number}, {"HoursRework", type number},
        
        // Financial data
        {"LaborCost", type number}, {"LaborSale", type number}, 
        {"CalculatedSale", type number}, {"ReworkValue", type number},
        
        // Operational data
        {"DelayCode", type text}, {"DelayHours", type number}, {"DelayComment", type text},
        {"LaborType", type text}, {"DiagnosticIndicator", type text}, {"WorkCategory", type text},
        
        // Business flags
        {"ReversalIndicator", type text}, {"LaborKey", type text}, {"BillingDepartment", type text},
        
        // Audit trail
        {"CreationDate", type datetime}, {"ModifiedDate", type datetime}, {"WorkOrderJobGUID", type text}
    }),
    
    // ========================================================================
    // ENHANCED BUSINESS LOGIC COLUMNS
    // ========================================================================
    /*
    PURPOSE: Add calculated columns that provide immediate business value
    PERFORMANCE: Calculate once in ETL vs multiple times in DAX
    BUSINESS LOGIC: Common calculations needed across all labor analytics
    */
    
    // Calculate total labor time (work + rework)
    AddTotalHours = Table.AddColumn(StandardizedDataTypes, "TotalHours", each 
        ([HoursWorked] ?? 0) + ([HoursRework] ?? 0), type number),
    
    // Calculate actual punch duration (if punch times available)
    AddPunchDuration = Table.AddColumn(AddTotalHours, "PunchDuration", each 
        if [StartTime] <> null and [FinishTime] <> null and [FinishTime] > [StartTime] then
            Duration.TotalHours([FinishTime] - [StartTime])
        else null, type number),
    
    // Calculate labor margin (sale - cost)
    AddLaborMargin = Table.AddColumn(AddPunchDuration, "LaborMargin", each 
        ([LaborSale] ?? 0) - ([LaborCost] ?? 0), type number),
    
    // Calculate labor efficiency (invoice hours / worked hours)
    AddLaborEfficiency = Table.AddColumn(AddLaborMargin, "LaborEfficiency", each 
        if ([HoursWorked] ?? 0) > 0 then 
            Number.Round(([InvoiceHours] ?? 0) / [HoursWorked], 4)
        else null, type number),
    
    // Identify rework entries
    AddHasRework = Table.AddColumn(AddLaborEfficiency, "HasRework", each 
        ([HoursRework] ?? 0) > 0, type logical),
    
    // Identify delay entries
    AddHasDelay = Table.AddColumn(AddHasRework, "HasDelay", each 
        ([DelayHours] ?? 0) > 0, type logical),
    
    // Create composite work order key for dimensional modeling
    AddWorkOrderKey = Table.AddColumn(AddHasDelay, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // ========================================================================
    // FINAL OPTIMIZATION & QUALITY CHECKS
    // ========================================================================
    /*
    PURPOSE: Final data quality improvements and optimization
    PERFORMANCE: Remove unnecessary whitespace and standardize formats
    */
    
    // Clean text fields
    CleanTextFields = Table.TransformColumns(AddWorkOrderKey, {
        {"JobCode", Text.Trim}, {"JobType", Text.Trim}, {"TechCode", Text.Trim},
        {"DelayCode", Text.Trim}, {"LaborType", Text.Trim}, {"WorkCategory", Text.Trim}
    }),
    
    // Add data quality flag
    AddDataQualityFlag = Table.AddColumn(CleanTextFields, "DataQualityScore", each
        let
            score = 0 +
                (if [WorkOrder] <> null then 20 else 0) +
                (if [TechCode] <> null and [TechCode] <> "" then 20 else 0) +
                (if [HoursWorked] <> null and [HoursWorked] > 0 then 20 else 0) +
                (if [StartTime] <> null and [FinishTime] <> null then 20 else 0) +
                (if [LaborCost] <> null or [LaborSale] <> null then 20 else 0)
        in
            score, type number)

in
    AddDataQualityFlag

/*
============================================================================
🎯 BUSINESS VALUE SUMMARY
============================================================================

✅ COMPLETE LABOR FOUNDATION:
• All financial data for cost/margin analysis
• Complete time tracking for efficiency analysis  
• Operational data for process improvement
• Quality indicators for performance management

✅ DIMENSIONAL MODELING READY:
• Standardized naming conventions
• Proper data types for optimal performance
• Relationship keys for fact table integration
• Business logic pre-calculated for dashboard efficiency

✅ PERFORMANCE OPTIMIZED:
• Incremental refresh capability
• SQL query folding for lakehouse optimization
• Essential calculations performed once in ETL
• Data quality scoring for monitoring

✅ ANALYTICS READY:
• Supports detailed technician performance analysis
• Enables operational efficiency improvement
• Provides complete financial profitability data
• Ready for advanced labor analytics and reporting

============================================================================
*/