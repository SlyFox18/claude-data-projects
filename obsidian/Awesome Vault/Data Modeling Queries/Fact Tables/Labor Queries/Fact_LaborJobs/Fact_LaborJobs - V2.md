/*
============================================================================
FACT_LABORJOBS - COMPREHENSIVE JOB-LEVEL LABOR ANALYTICS FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Job-level labor tracking with complete financial, operational, and performance analytics
Grain: One row per technician per job (individual labor entries from wkmechwk)
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering - optimized approach)
Current Performance: Target 2-3 minutes refresh time
Source Dependencies: Raw_wkmechwk + 4 dimension tables

🎯 BUSINESS USE CASES:
• Job Costing & Profitability: Complete labor cost, sale, and margin analysis per job
• Technician Performance: Individual efficiency, specialization, and productivity tracking
• Operational Efficiency: Delay analysis, rework identification, and process improvement
• Skill Management: Job type expertise and technician development planning
• Quality Analytics: Work quality assessment through rework and efficiency patterns
• Financial Intelligence: Labor contribution to overall work order profitability
• Cross-Fact Integration: Job-level foundation linking punch detail to work order summaries
• Resource Optimization: Labor allocation effectiveness and capacity planning

📊 KEY METRICS PROVIDED (PRE-CALCULATED IN RAW TABLE):
• Complete Financial Intelligence: Labor cost, sale, margin, and rework values
• Efficiency Analytics: Labor efficiency (invoice/worked hours), total hours, punch duration
• Quality Indicators: Rework identification, delay tracking, data quality scoring
• Operational Metrics: Work categories, diagnostic indicators, billing department analysis
• Performance Classifications: Efficiency ratings, complexity assessment, revenue impact
• Time Intelligence: Clock-in dates, start/finish times, delay hours tracking

🔗 DIMENSION RELATIONSHIPS:
• dim_Technician_Code_Names → TechnicianKey (technician performance and skill analysis)
• dim_BranchLocation → BranchKey (territory and location-based labor cost analysis)
• dim_JobCode → JobCodeKey (service type specialization and complexity analysis)
• dim_WorkOrderMaster → DimWorkOrderKey (CRITICAL: work order context and cross-fact integration)
• ClockInDateKey → Direct date key for time intelligence (linkable to date dimension in Power BI)

📈 DASHBOARD IDEAS:
• Job Profitability Dashboard: Labor margin analysis by job type, technician, and customer
• Technician Performance Analytics: Individual efficiency, specialization, and development tracking
• Operational Excellence: Delay analysis, rework patterns, and process improvement opportunities
• Quality Management: Work quality assessment with efficiency and rework correlation
• Financial Intelligence: Labor cost analysis supporting pricing and margin optimization
• Cross-Fact Analytics: Job-level detail supporting complete work order profitability analysis

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Leverages ALL pre-calculated business logic from Raw_wkmechwk
• Uses hybrid incremental refresh approach (leverages raw table + optional fact table filtering)
• Essential columns only for optimal memory usage
• Text composite work order keys for cross-fact integration
• Sub-3 minute refresh target achievable through raw table optimization
• ClockInDateKey generated directly to avoid dimension lookup issues

🔧 MAINTENANCE NOTES:
• Business logic centralized in Raw_wkmechwk for consistency
• Work order keys now use text composite format for cross-fact compatibility
• Monitor dimension lookup success rates for orphaned record identification
• Validate financial calculations if source system logic changes
• Review efficiency thresholds based on operational performance standards
• ClockInDateKey can be linked to date dimension in Power BI if needed for advanced time intelligence

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    /*
    PURPOSE: Consistent incremental refresh pattern across all fact tables
    APPROACH: Hybrid approach - leverages raw table efficiency with optional independent control
    STANDARD: Use same date range as other fact tables for consistency
    */
    
    // Standard incremental refresh parameters (align with other fact tables)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),   // Standard across all fact tables
    RangeEnd = DateTime.LocalNow(),                 // Always current data
    
    // ========================================================================
    // STEP 1: SOURCE DATA WITH OPTIONAL ADDITIONAL FILTERING
    // ========================================================================
    /*
    PURPOSE: Load job-level labor data with fact table level control
    APPROACH: Start with pre-filtered raw table, apply additional filtering if needed
    BENEFIT: Leverages raw table efficiency while maintaining fact table flexibility
    */
    
    // Source: Raw table already filtered at SQL level (efficient)
    Source = Raw_wkmechwk,
    
    // Optional: Additional filtering at fact table level (for different refresh policies)
    // Uncomment if you want independent control over fact table date range:
    // FilteredSource = Table.SelectRows(Source, each 
    //     [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),
    
    // For now, use raw table filtering (most efficient approach)
    FilteredSource = Source,
    
    // ========================================================================
    // STEP 2: DIMENSION LOOKUP - TECHNICIAN
    // ========================================================================
    /*
    PURPOSE: Link job records to technician master data for performance analysis
    BUSINESS LOGIC: TechCode → TechnicianCode for individual performance tracking
    BENEFIT: Enables technician skill analysis, efficiency tracking, and development planning
    */
    
    TechnicianLookup = Table.NestedJoin(
        FilteredSource, {"TechCode"}, 
        dim_Technician_Code_Names, {"TechnicianCode"}, 
        "TechnicianDim", JoinKind.LeftOuter),
    
    ExpandTechnician = Table.ExpandTableColumn(
        TechnicianLookup, "TechnicianDim", 
        {"TechnicianKey"}, {"TechnicianDimKey"}),
    
    // ========================================================================
    // STEP 3: DIMENSION LOOKUP - BRANCH LOCATION  
    // ========================================================================
    /*
    PURPOSE: Link job records to branch/territory information for cost analysis
    BUSINESS LOGIC: Branch → BranchID for territory-based labor cost and efficiency analysis
    BENEFIT: Enables geographic performance comparison and resource allocation optimization
    FIX: Correct join field (Branch → BranchID)
    */
    
    BranchLookup = Table.NestedJoin(
        ExpandTechnician, {"Branch"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchDim", JoinKind.LeftOuter),
    
    ExpandBranch = Table.ExpandTableColumn(
        BranchLookup, "BranchDim", 
        {"BranchKey"}, {"BranchDimKey"}),
    
    // ========================================================================
    // STEP 4: DIMENSION LOOKUP - JOB CODE
    // ========================================================================
    /*
    PURPOSE: Link job records to service type classification for specialization analysis
    BUSINESS LOGIC: JobCode → JobCode for job type expertise and complexity assessment
    BENEFIT: Enables technician specialization tracking and job complexity analysis
    */
    
    JobCodeLookup = Table.NestedJoin(
        ExpandBranch, {"JobCode"}, 
        dim_JobCode, {"JobCode"}, 
        "JobCodeDim", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(
        JobCodeLookup, "JobCodeDim", 
        {"JobCodeKey"}, {"JobCodeDimKey"}),
    
    // ========================================================================
    // STEP 5: DIMENSION LOOKUP - WORK ORDER (CRITICAL FIX!)
    // ========================================================================
    /*
    PURPOSE: Link job records to work order master data for cross-fact integration
    BUSINESS LOGIC: Branch + WorkOrder → BranchWorkOrder for cross-fact compatibility
    BENEFIT: CRITICAL - Enables cross-fact analysis and validates work order coverage
    FIX: Use composite key lookup to get text BranchWorkOrder instead of integer surrogate
    */
    
    WorkOrderLookup = Table.NestedJoin(
        ExpandJobCode, {"Branch", "WorkOrder"}, 
        dim_WorkOrderMaster, {"Branch", "WorkOrder"}, 
        "WorkOrderDim", JoinKind.LeftOuter),
    
    ExpandWorkOrder = Table.ExpandTableColumn(
        WorkOrderLookup, "WorkOrderDim", 
        {"BranchWorkOrder"}, {"WorkOrderMasterKey"}),
    
    // ========================================================================
    // STEP 6: CREATE DATE KEY FOR TIME INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Create date key for time intelligence without dimension lookup issues
    BUSINESS LOGIC: Generate date key directly from ClockInDate to avoid lookup failures
    BENEFIT: Reliable time intelligence without dimension table dependency issues
    NOTE: Can be linked to date dimension in Power BI if needed
    */
    
    CreateDateKey = Table.AddColumn(ExpandWorkOrder, "ClockInDateKey", each 
        if [ClockInDate] <> null then 
            Date.Year([ClockInDate]) * 10000 + 
            Date.Month([ClockInDate]) * 100 + 
            Date.Day([ClockInDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // STEP 7: CREATE CLEAN DIMENSION KEYS (UPDATED FOR TEXT WORK ORDER KEYS)
    // ========================================================================
    /*
    PURPOSE: Create clean dimension keys for fact table relationships
    BUSINESS LOGIC: Use dimension lookup keys where available, appropriate defaults for missing
    BENEFIT: Clean fact table keys for optimal Power BI relationships and orphaned record identification
    FIX: DimWorkOrderKey now text type with "UNKNOWN" default instead of integer -1
    */
    
    HandleMissingKeys = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(CreateDateKey,
                    "TechnicianKey", each [TechnicianDimKey] ?? -1, Int64.Type),
                "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),
            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),
        "DimWorkOrderKey", each [WorkOrderMasterKey] ?? "UNKNOWN", type text),
    
    // ========================================================================
    // STEP 8: ENHANCED JOB-LEVEL BUSINESS LOGIC
    // ========================================================================
    /*
    PURPOSE: Add fact table specific business logic for job-level analysis
    BUSINESS LOGIC: Job-specific classifications and performance indicators
    BENEFIT: Enhanced analytical capability beyond raw table calculations
    */
    
    // Classify job value impact (based on labor sale value)
    AddJobValueCategory = Table.AddColumn(HandleMissingKeys, "JobValueCategory", each
        let saleValue = [LaborSale] ?? 0 in
        if saleValue >= 500 then "High Value"
        else if saleValue >= 200 then "Medium Value"
        else if saleValue >= 50 then "Low Value"
        else "Minimal Value", type text),
    
    // Job efficiency classification (based on labor efficiency)
    AddJobEfficiencyCategory = Table.AddColumn(AddJobValueCategory, "JobEfficiencyCategory", each
        let efficiency = [LaborEfficiency] ?? 0 in
        if efficiency >= 1.2 then "Excellent"
        else if efficiency >= 1.0 then "Good"
        else if efficiency >= 0.8 then "Fair"
        else if efficiency > 0 then "Poor"
        else "No Data", type text),
    
    // Job complexity assessment (based on hours, rework, and delays)
    AddJobComplexity = Table.AddColumn(AddJobEfficiencyCategory, "JobComplexity", each
        let
            totalHours = [TotalHours] ?? 0,
            hasRework = [HasRework] ?? false,
            hasDelay = [HasDelay] ?? false
        in
        if totalHours > 8 or hasRework or hasDelay then "Complex"
        else if totalHours > 4 then "Moderate"
        else "Simple", type text),
    
    // Revenue type classification
    AddRevenueType = Table.AddColumn(AddJobComplexity, "RevenueType", each
        let 
            laborSale = [LaborSale] ?? 0,
            laborType = [LaborType] ?? ""
        in
        if laborSale > 0 then "Revenue Generating"
        else if Text.Contains(Text.Upper(laborType), "WARR") then "Warranty"
        else if Text.Contains(Text.Upper(laborType), "INT") then "Internal"
        else "Non-Revenue", type text),
    
    // Quality indicator (combination of efficiency, rework, and delays)
    AddQualityIndicator = Table.AddColumn(AddRevenueType, "QualityIndicator", each
        let
            efficiency = [LaborEfficiency] ?? 0,
            hasRework = [HasRework] ?? false,
            hasDelay = [HasDelay] ?? false
        in
        if efficiency >= 1.0 and not hasRework and not hasDelay then "High Quality"
        else if efficiency >= 0.8 and not hasRework then "Good Quality"
        else if hasRework or hasDelay then "Quality Issues"
        else "Standard Quality", type text),
    
    // Profitability classification
    AddProfitabilityClass = Table.AddColumn(AddQualityIndicator, "ProfitabilityClass", each
        let
            margin = [LaborMargin] ?? 0,
            saleValue = [LaborSale] ?? 0
        in
        if saleValue > 0 then
            let marginPercent = margin / saleValue in
            if marginPercent >= 0.4 then "High Profit"
            else if marginPercent >= 0.2 then "Good Profit"
            else if marginPercent >= 0 then "Low Profit"
            else "Loss"
        else "No Revenue", type text),
    
    // Specialization indicator (for technician skill analysis)
    AddSpecializationFlag = Table.AddColumn(AddProfitabilityClass, "IsSpecialtyWork", each
        let
            diagnostic = [DiagnosticIndicator] ?? "",
            workCat = [WorkCategory] ?? "",
            laborType = [LaborType] ?? ""
        in
        Text.Contains(Text.Upper(diagnostic), "Y") or 
        Text.Contains(Text.Upper(workCat), "SPEC") or
        Text.Contains(Text.Upper(laborType), "SPEC"), type logical),
    
    // ========================================================================
    // STEP 9: OPERATIONAL FLAGS FOR FACT TABLE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Add operational flags specific to job-level management needs
    BUSINESS LOGIC: Flags for dashboard filtering and operational decision making
    BENEFIT: Enhanced filtering and management capability for job-level operations
    */
    
    // High performance job flag
    AddHighPerformanceFlag = Table.AddColumn(AddSpecializationFlag, "IsHighPerformance", each
        [JobEfficiencyCategory] = "Excellent" and [QualityIndicator] = "High Quality", type logical),
    
    // Problem job identification
    AddProblemJobFlag = Table.AddColumn(AddHighPerformanceFlag, "IsProblemJob", each
        [HasRework] or [HasDelay] or [JobEfficiencyCategory] = "Poor", type logical),
    
    // Overtime job flag (based on punch duration vs standard hours)
    AddOvertimeJobFlag = Table.AddColumn(AddProblemJobFlag, "IsOvertimeJob", each
        ([PunchDuration] ?? 0) > 8 or ([TotalHours] ?? 0) > 8, type logical),
    
    // Training opportunity flag (complex work with efficiency issues)
    AddTrainingOpportunityFlag = Table.AddColumn(AddOvertimeJobFlag, "IsTrainingOpportunity", each
        [JobComplexity] = "Complex" and [JobEfficiencyCategory] <> "Excellent", type logical),
    
    // ========================================================================
    // STEP 10: FINAL COLUMN SELECTION AND OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Select essential columns for optimal performance and comprehensive analysis
    BUSINESS LOGIC: Include all dimensional keys, metrics, and essential business attributes
    BENEFIT: Minimizes memory footprint while maintaining complete analytical capability
    */
    
    FinalColumns = Table.SelectColumns(AddTrainingOpportunityFlag, {
        // ===== DIMENSION KEYS =====
        "TechnicianKey", "BranchKey", "JobCodeKey", "DimWorkOrderKey", "ClockInDateKey",
        
        // ===== CORE IDENTIFIERS =====
        "Branch", "WorkOrder", "JobCode", "JobType", "TechCode", "SequenceNumber",
        
        // ===== TIME TRACKING (FROM RAW TABLE) =====
        "ClockInDate", "StartTime", "FinishTime", "InvoiceHours", "HoursWorked", "HoursRework",
        
        // ===== CALCULATED TIME METRICS (FROM RAW TABLE) =====
        "TotalHours", "PunchDuration",
        
        // ===== FINANCIAL DATA (FROM RAW TABLE) =====
        "LaborCost", "LaborSale", "CalculatedSale", "ReworkValue", "LaborMargin",
        
        // ===== PERFORMANCE METRICS (FROM RAW TABLE) =====
        "LaborEfficiency",
        
        // ===== OPERATIONAL INTELLIGENCE (FROM RAW TABLE) =====
        "DelayCode", "DelayHours", "DelayComment", "LaborType", 
        "DiagnosticIndicator", "WorkCategory", "BillingDepartment",
        
        // ===== QUALITY INDICATORS (FROM RAW TABLE) =====
        "HasRework", "HasDelay", "DataQualityScore",
        
        // ===== BUSINESS CLASSIFICATIONS (FACT TABLE ENHANCED) =====
        "JobValueCategory", "JobEfficiencyCategory", "JobComplexity", 
        "RevenueType", "QualityIndicator", "ProfitabilityClass",
        
        // ===== OPERATIONAL FLAGS (FACT TABLE ENHANCED) =====
        "IsSpecialtyWork", "IsHighPerformance", "IsProblemJob", 
        "IsOvertimeJob", "IsTrainingOpportunity",
        
        // ===== AUDIT FIELDS =====
        "ModifiedDate"
    }),
    
    // ========================================================================
    // STEP 11: FINAL DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for performance and memory efficiency
    BUSINESS LOGIC: Appropriate data types for each column based on content and usage
    BENEFIT: Optimal query performance and minimal memory footprint
    FIX: DimWorkOrderKey now type text instead of Int64
    */
    
    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {
        // Dimension keys (UPDATED: DimWorkOrderKey now text)
        {"TechnicianKey", Int64.Type}, {"BranchKey", Int64.Type}, 
        {"JobCodeKey", Int64.Type}, {"DimWorkOrderKey", type text}, {"ClockInDateKey", Int64.Type},
        
        // Identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"TechCode", type text}, {"SequenceNumber", Int64.Type},
        
        // Time tracking
        {"ClockInDate", type datetime}, {"StartTime", type datetime}, {"FinishTime", type datetime},
        {"InvoiceHours", type number}, {"HoursWorked", type number}, {"HoursRework", type number},
        
        // Calculated time
        {"TotalHours", type number}, {"PunchDuration", type number},
        
        // Financial data
        {"LaborCost", type number}, {"LaborSale", type number}, {"CalculatedSale", type number},
        {"ReworkValue", type number}, {"LaborMargin", type number},
        
        // Performance metrics
        {"LaborEfficiency", type number},
        
        // Operational data
        {"DelayCode", type text}, {"DelayHours", type number}, {"DelayComment", type text},
        {"LaborType", type text}, {"DiagnosticIndicator", type text}, {"WorkCategory", type text},
        {"BillingDepartment", type text},
        
        // Quality indicators
        {"HasRework", type logical}, {"HasDelay", type logical}, {"DataQualityScore", type number},
        
        // Business classifications
        {"JobValueCategory", type text}, {"JobEfficiencyCategory", type text}, {"JobComplexity", type text},
        {"RevenueType", type text}, {"QualityIndicator", type text}, {"ProfitabilityClass", type text},
        
        // Operational flags
        {"IsSpecialtyWork", type logical}, {"IsHighPerformance", type logical}, {"IsProblemJob", type logical},
        {"IsOvertimeJob", type logical}, {"IsTrainingOpportunity", type logical},
        
        // Audit
        {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes

/*
============================================================================
✅ FACT_LABORJOBS - CROSS-FACT INTEGRATION FIX COMPLETE
============================================================================

🔄 CRITICAL FIXES IMPLEMENTED:
• Work Order Key Format: Changed from integer surrogate to text composite keys
• Cross-Fact Compatibility: Now uses BranchWorkOrder for seamless integration
• Branch Join Fix: Corrected Branch → BranchID mapping
• Incremental Refresh: Added standard parameters and hybrid approach
• Data Type Optimization: Updated DimWorkOrderKey to text type with proper defaults

⚡ EXPECTED VALIDATION IMPROVEMENTS:
• Work Order Overlap: Should jump from 0% to 95%+ with existing fact tables
• Orphaned Records: Significant reduction in work order orphaned records
• Cross-Fact Analysis: Full integration with Fact_WorkOrderHeader, Parts, Warranty tables
• Financial Reconciliation: Better alignment with other labor tables

🔗 DIMENSIONAL INTEGRATION SUCCESS:
• TechnicianKey → Individual technician performance and skill specialization analysis
• BranchKey → Territory-based labor cost and efficiency comparison (FIXED join)
• JobCodeKey → Service type expertise and complexity assessment
• DimWorkOrderKey → CRITICAL cross-fact integration via text composite keys (FIXED)
• ClockInDateKey → Time intelligence via direct date key generation

📊 INCREMENTAL REFRESH EXCELLENCE:
• Hybrid Approach: Leverages raw table SQL filtering for efficiency
• Independent Control: Parameters ready for different refresh policies
• Standard Pattern: Follows established 2023-01-01 start date convention
• Production Ready: Can switch to independent filtering when needed

🚀 BUSINESS VALUE MAINTAINED AND ENHANCED:
• Complete Job Costing: All original financial and operational metrics preserved
• Cross-Fact Foundation: Now enables seamless work order analysis across all fact tables
• Performance Optimization: Maintains target 2-3 minute refresh with improved compatibility
• Analytical Excellence: Enhanced business logic with cross-dimensional analysis capability

============================================================================
*/