/*
============================================================================
RAW_TECHNICIANLABOR - COMPREHENSIVE LABOR BILLING & EFFICIENCY FOUNDATION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Complete technician billing efficiency and financial tracking foundation
Grain: One row per technician per work order per invoice sequence
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering)
Dependencies: Source system TechnicianInvoiceDetail table
Target Performance: <2 minutes refresh time

🎯 BUSINESS VALUE:
• Billing Efficiency: Punched hours vs invoiced hours analysis
• Rework Analysis: Quality tracking and cost impact assessment
• Gain/Loss Analysis: Productivity optimization and variance tracking
• Financial Integration: Complete labor cost vs revenue margin analysis
• Quality Metrics: Delay tracking and efficiency rate calculations
• Performance Management: Individual technician productivity and billing accuracy

📊 KEY METRICS PROVIDED:
• Labor Efficiency: InvoiceHours / HoursPunched (billing accuracy)
• Rework Impact: ReworkHours cost and frequency analysis
• Gain/Loss Tracking: Productivity variance and optimization opportunities
• Financial Margins: LaborSale - LaborCost profitability per technician
• Quality Indicators: Delay analysis and non-revenue work identification

⚡ OPTIMIZATION FEATURES:
• Incremental refresh via ModifiedDate filtering for performance
• Essential column selection with business value focus
• Pre-calculated efficiency and margin metrics
• Standardized naming for dimensional modeling consistency
• Relationship keys for fact table integration

============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION PARAMETERS
    // ========================================================================
    /*
    PURPOSE: Centralized configuration for performance and data management
    BUSINESS LOGIC: Align with business requirements and data retention policies
    PERFORMANCE: Date filtering critical for billing data which can be voluminous
    */
    
    // Date range parameters (configurable for business needs)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),    // Align with other raw tables
    RangeEnd = DateTime.LocalNow(),                   // Always current data
    
    // Convert to SQL-safe format for query folding
    StartStr = "'" & DateTime.ToText(RangeStart, "yyyy-MM-dd HH:mm:ss") & "'",
    EndStr = "'" & DateTime.ToText(RangeEnd, "yyyy-MM-dd HH:mm:ss") & "'",
    
    // ========================================================================
    // COMPREHENSIVE SQL QUERY WITH ESSENTIAL COLUMNS
    // ========================================================================
    /*
    PURPOSE: Extract complete labor billing data for efficiency and financial analysis
    STRATEGY: Include all columns that provide business value for billing and performance
    PERFORMANCE: SQL query folding with selective column extraction
    */
    
    SQL = 
    "SELECT #(lf)
        -- ===== PRIMARY IDENTIFIERS ===== #(lf)
        Branch AS Branch, #(lf)
        RepairOrderNumber AS WorkOrder, #(lf)
        InvoiceNumber AS InvoiceNumber, #(lf)
        TechnicianCode AS TechCode, #(lf)
        SequenceID AS SequenceID, #(lf)
        JobCode AS JobCode, #(lf)
        JobType AS JobType, #(lf)
        
        -- ===== TIMING & DATE INTELLIGENCE ===== #(lf)
        InvoiceDate AS InvoiceDate, #(lf)
        WorkDate AS WorkDate, #(lf)
        StartTime AS StartTime, #(lf)
        EndTime AS EndTime, #(lf)
        
        -- ===== CORE LABOR HOURS (CRITICAL FOR EFFICIENCY) ===== #(lf)
        HoursPunched AS HoursPunched, #(lf)
        InvoiceHours AS InvoiceHours, #(lf)
        ReworkHours AS ReworkHours, #(lf)
        DelayHours AS DelayHours, #(lf)
        GainLossHours AS GainLossHours, #(lf)
        OtherHours AS OtherHours, #(lf)
        LostHours AS LostHours, #(lf)
        
        -- ===== EFFICIENCY RATE COMPONENTS ===== #(lf)
        EfficiencyRateNumerator AS EfficiencyNumerator, #(lf)
        EfficiencyRateDenominator AS EfficiencyDenominator, #(lf)
        
        -- ===== FINANCIAL DATA ===== #(lf)
        LaborCost AS LaborCost, #(lf)
        LaborSale AS LaborSale, #(lf)
        
        -- ===== BUSINESS INDICATORS ===== #(lf)
        SpecialPromoIndicator AS SpecialPromoIndicator, #(lf)
        NonRevenueIndicator AS NonRevenueIndicator, #(lf)
        
        -- ===== AUDIT TRAIL ===== #(lf)
        CreationDate AS CreationDate, #(lf)
        ModifiedDate AS ModifiedDate #(lf)
        
    FROM TechnicianInvoiceDetail #(lf)
    WHERE ModifiedDate >= " & StartStr & " #(lf)
      AND ModifiedDate < " & EndStr & " #(lf)
    ORDER BY ModifiedDate DESC, Branch, RepairOrderNumber, TechnicianCode, SequenceID",
    
    // ========================================================================
    // EXECUTE QUERY WITH ERROR HANDLING
    // ========================================================================
    
    Source = try Odbc.Query("dsn=EquipRDB64", SQL) otherwise 
        error "Failed to connect to TechnicianInvoiceDetail. Check connection and table availability.",
    
    // ========================================================================
    // DATA TYPE OPTIMIZATION & STANDARDIZATION
    // ========================================================================
    
    StandardizedDataTypes = Table.TransformColumnTypes(Source, {
        // Primary identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"InvoiceNumber", type text},
        {"TechCode", type text}, {"SequenceID", Int64.Type}, {"JobCode", type text}, {"JobType", type text},
        
        // Timing and dates
        {"InvoiceDate", type datetime}, {"WorkDate", type datetime}, 
        {"StartTime", type datetime}, {"EndTime", type datetime},
        
        // Labor hours
        {"HoursPunched", type number}, {"InvoiceHours", type number}, {"ReworkHours", type number},
        {"DelayHours", type number}, {"GainLossHours", type number}, {"OtherHours", type number}, {"LostHours", type number},
        
        // Efficiency components
        {"EfficiencyNumerator", type number}, {"EfficiencyDenominator", type number},
        
        // Financial data
        {"LaborCost", type number}, {"LaborSale", type number},
        
        // Business indicators
        {"SpecialPromoIndicator", type text}, {"NonRevenueIndicator", type text},
        
        // Audit trail
        {"CreationDate", type datetime}, {"ModifiedDate", type datetime}
    }),
    
    // ========================================================================
    // ENHANCED BUSINESS LOGIC COLUMNS
    // ========================================================================
    /*
    PURPOSE: Add calculated columns that provide immediate business value
    PERFORMANCE: Calculate once in ETL vs multiple times in DAX
    BUSINESS LOGIC: Core efficiency and quality metrics for labor management
    */
    
    // Create composite work order key for dimensional modeling
    AddWorkOrderKey = Table.AddColumn(StandardizedDataTypes, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Calculate labor efficiency (critical business metric)
    AddLaborEfficiency = Table.AddColumn(AddWorkOrderKey, "LaborEfficiency", each 
        if ([HoursPunched] ?? 0) > 0 then 
            Number.Round(([InvoiceHours] ?? 0) / [HoursPunched], 4)
        else null, type number),
    
    // Calculate alternative efficiency using provided components
    AddCalculatedEfficiency = Table.AddColumn(AddLaborEfficiency, "CalculatedEfficiency", each 
        if ([EfficiencyDenominator] ?? 0) > 0 then 
            Number.Round(([EfficiencyNumerator] ?? 0) / [EfficiencyDenominator], 4)
        else null, type number),
    
    // Calculate labor margin (profitability per entry)
    AddLaborMargin = Table.AddColumn(AddCalculatedEfficiency, "LaborMargin", each 
        ([LaborSale] ?? 0) - ([LaborCost] ?? 0), type number),
    
    // Calculate margin percentage
    AddMarginPercent = Table.AddColumn(AddLaborMargin, "MarginPercent", each 
        if ([LaborSale] ?? 0) > 0 then 
            Number.Round(([LaborMargin] ?? 0) / [LaborSale], 4)
        else null, type number),
    
    // Calculate total accountable hours
    AddTotalAccountedHours = Table.AddColumn(AddMarginPercent, "TotalAccountedHours", each 
        ([InvoiceHours] ?? 0) + ([ReworkHours] ?? 0) + ([DelayHours] ?? 0) + ([OtherHours] ?? 0) + ([LostHours] ?? 0), type number),
    
    // Calculate actual work duration (punch time)
    AddPunchDuration = Table.AddColumn(AddTotalAccountedHours, "PunchDurationHours", each 
        if [StartTime] <> null and [EndTime] <> null and [EndTime] > [StartTime] then
            Duration.TotalHours([EndTime] - [StartTime])
        else null, type number),
    
    // ========================================================================
    // BUSINESS INTELLIGENCE & CATEGORIZATION
    // ========================================================================
    
    // Efficiency categorization for performance management
    AddEfficiencyCategory = Table.AddColumn(AddPunchDuration, "EfficiencyCategory", each
        let efficiency = [LaborEfficiency] ?? 0 in
        if efficiency >= 1.2 then "Excellent"      // 120%+ efficiency
        else if efficiency >= 1.0 then "Good"      // 100-119% efficiency
        else if efficiency >= 0.8 then "Fair"      // 80-99% efficiency
        else if efficiency > 0 then "Poor"         // Below 80% efficiency
        else "No Data", type text),
    
    // Rework analysis
    AddHasRework = Table.AddColumn(AddEfficiencyCategory, "HasRework", each 
        ([ReworkHours] ?? 0) > 0, type logical),
    
    AddReworkPercentage = Table.AddColumn(AddHasRework, "ReworkPercentage", each 
        if ([TotalAccountedHours] ?? 0) > 0 then 
            Number.Round(([ReworkHours] ?? 0) / [TotalAccountedHours], 4)
        else 0, type number),
    
    // Delay analysis
    AddHasDelay = Table.AddColumn(AddReworkPercentage, "HasDelay", each 
        ([DelayHours] ?? 0) > 0, type logical),
    
    // Gain/Loss analysis
    AddGainLossIndicator = Table.AddColumn(AddHasDelay, "GainLossIndicator", each
        let gainLoss = [GainLossHours] ?? 0 in
        if gainLoss > 0.25 then "Significant Gain"
        else if gainLoss > 0 then "Minor Gain"
        else if gainLoss = 0 then "No Variance"
        else if gainLoss >= -0.25 then "Minor Loss"
        else "Significant Loss", type text),
    
    // Quality indicator combining efficiency and rework
    AddQualityIndicator = Table.AddColumn(AddGainLossIndicator, "QualityIndicator", each
        let 
            efficiency = [LaborEfficiency] ?? 0,
            hasRework = [HasRework] ?? false,
            hasDelay = [HasDelay] ?? false
        in
        if efficiency >= 1.0 and not hasRework and not hasDelay then "High Quality"
        else if efficiency >= 0.9 and not hasRework then "Good Quality"
        else if not hasRework and not hasDelay then "Acceptable"
        else "Needs Improvement", type text),
    
    // Labor value categorization
    AddLaborValueCategory = Table.AddColumn(AddQualityIndicator, "LaborValueCategory", each
        let sale = [LaborSale] ?? 0 in
        if sale >= 1000 then "High Value"
        else if sale >= 300 then "Medium Value"
        else if sale > 0 then "Low Value"
        else "No Value", type text),
    
    // Revenue classification
    AddRevenueType = Table.AddColumn(AddLaborValueCategory, "RevenueType", each
        if Text.Upper([NonRevenueIndicator] ?? "N") = "Y" then "Non-Revenue"
        else if Text.Upper([SpecialPromoIndicator] ?? "N") = "Y" then "Promotional"
        else "Standard Revenue", type text),
    
    // Date keys for time intelligence
    AddInvoiceDateKey = Table.AddColumn(AddRevenueType, "InvoiceDateKey", each 
        if [InvoiceDate] <> null then 
            Date.Year([InvoiceDate]) * 10000 + 
            Date.Month([InvoiceDate]) * 100 + 
            Date.Day([InvoiceDate])
        else 99999999, Int64.Type),
    
    AddWorkDateKey = Table.AddColumn(AddInvoiceDateKey, "WorkDateKey", each 
        if [WorkDate] <> null then 
            Date.Year([WorkDate]) * 10000 + 
            Date.Month([WorkDate]) * 100 + 
            Date.Day([WorkDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // FINAL OPTIMIZATION & QUALITY VALIDATION
    // ========================================================================
    
    // Clean text fields
    CleanTextFields = Table.TransformColumns(AddWorkDateKey, {
        {"JobCode", Text.Trim}, {"JobType", Text.Trim}, {"TechCode", Text.Trim},
        {"SpecialPromoIndicator", Text.Upper}, {"NonRevenueIndicator", Text.Upper}
    }),
    
    // Add comprehensive data quality score
    AddDataQualityScore = Table.AddColumn(CleanTextFields, "DataQualityScore", each
        let
            score = 0 +
                (if [WorkOrder] <> null then 15 else 0) +
                (if [TechCode] <> null and [TechCode] <> "" then 15 else 0) +
                (if [InvoiceNumber] <> null and [InvoiceNumber] <> "" then 15 else 0) +
                (if [HoursPunched] <> null and [HoursPunched] > 0 then 15 else 0) +
                (if [InvoiceHours] <> null then 15 else 0) +
                (if [LaborSale] <> null or [LaborCost] <> null then 10 else 0) +
                (if [WorkDate] <> null then 10 else 0) +
                (if [StartTime] <> null and [EndTime] <> null then 5 else 0)
        in
            score, type number)

in
    AddDataQualityScore

/*
============================================================================
🎯 BUSINESS VALUE SUMMARY
============================================================================

✅ COMPREHENSIVE BILLING EFFICIENCY FOUNDATION:
• Complete labor billing cycle from punch to invoice
• Efficiency calculations (multiple methods for validation)
• Rework analysis and quality tracking
• Gain/Loss analysis for productivity optimization
• Financial margin analysis per technician per job

✅ PERFORMANCE MANAGEMENT READY:
• Efficiency categorization (Excellent, Good, Fair, Poor)
• Quality indicators combining efficiency, rework, and delays
• Individual technician performance tracking
• Revenue type classification (Standard, Promotional, Non-Revenue)

✅ FINANCIAL INTELLIGENCE:
• Labor cost vs sale margin analysis
• Value categorization for priority management
• Revenue type tracking for billing accuracy
• Complete financial attribution per labor entry

✅ OPERATIONAL ANALYTICS:
• Delay tracking and root cause analysis
• Rework cost impact assessment
• Productivity variance analysis (Gain/Loss hours)
• Time tracking validation (punch duration vs reported hours)

✅ DIMENSIONAL MODELING OPTIMIZED:
• WorkOrderKey for fact table relationships
• Date keys for time intelligence integration
• Standardized naming conventions
• Pre-calculated business metrics for dashboard efficiency

✅ DATA QUALITY ASSURANCE:
• Comprehensive validation scoring
• Clean text field standardization
• Proper data type optimization
• Incremental refresh capability for performance

============================================================================
*/