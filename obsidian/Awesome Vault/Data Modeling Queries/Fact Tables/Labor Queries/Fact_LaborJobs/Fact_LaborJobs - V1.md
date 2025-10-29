/*
============================================================================
FACT_LABORJOBS - COMPREHENSIVE JOB-LEVEL LABOR ANALYTICS FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Job-level labor tracking with complete financial, operational, and performance analytics
Grain: One row per technician per job (individual labor entries from wkmechwk)
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering via raw table)
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
• Minimal processing overhead - focuses on dimensional relationships
• Essential columns only for optimal memory usage
• Inherits incremental refresh capability from raw table
• Sub-3 minute refresh target achievable through raw table optimization
• ClockInDateKey generated directly to avoid dimension lookup issues
• Removed low-value columns (WorkOrderJobGUID, ReversalIndicator, LaborKey) for cleaner structure

🔧 MAINTENANCE NOTES:
• Business logic centralized in Raw_wkmechwk for consistency
• Monitor dimension lookup success rates for orphaned record identification
• Validate financial calculations if source system logic changes
• Review efficiency thresholds based on operational performance standards
• Ensure work order key alignment with dim_WorkOrderMaster
• ClockInDateKey can be linked to date dimension in Power BI if needed for advanced time intelligence

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA WITH COMPREHENSIVE BUSINESS LOGIC
    // ========================================================================
    /*
    PURPOSE: Leverage excellent raw table with complete job-level business calculations
    BUSINESS LOGIC: Raw table contains financial, efficiency, and operational metrics
    BENEFIT: Focus on dimensional relationships while preserving analytical richness
    */
    
    Source = Raw_wkmechwk,
    
    // ========================================================================
    // STEP 2: DIMENSION LOOKUP - TECHNICIAN
    // ========================================================================
    /*
    PURPOSE: Link job records to technician master data for performance analysis
    BUSINESS LOGIC: TechCode → TechnicianCode for individual performance tracking
    BENEFIT: Enables technician skill analysis, efficiency tracking, and development planning
    */
    
    TechnicianLookup = Table.NestedJoin(
        Source, {"TechCode"}, 
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
    // STEP 5: DIMENSION LOOKUP - WORK ORDER (CRITICAL!)
    // ========================================================================
    /*
    PURPOSE: Link job records to work order master data for cross-fact integration
    BUSINESS LOGIC: WorkOrder → WorkOrder for work order context and profitability analysis
    BENEFIT: CRITICAL - Enables cross-fact analysis and validates work order coverage
    */
    
    WorkOrderLookup = Table.NestedJoin(
        ExpandJobCode, {"WorkOrder"}, 
        dim_WorkOrderMaster, {"WorkOrder"}, 
        "WorkOrderDim", JoinKind.LeftOuter),
    
    ExpandWorkOrder = Table.ExpandTableColumn(
        WorkOrderLookup, "WorkOrderDim", 
        {"WorkOrderKey"}, {"WorkOrderMasterKey"}),
    
    // ========================================================================
    // STEP 6: CREATE DATE KEY FOR TIME INTELLIGENCE (ALTERNATIVE APPROACH)
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
    // STEP 7: CREATE CLEAN DIMENSION KEYS
    // ========================================================================
    /*
    PURPOSE: Create clean dimension keys for fact table relationships
    BUSINESS LOGIC: Use dimension lookup keys where available, default to -1 for missing relationships
    BENEFIT: Clean fact table keys for optimal Power BI relationships and orphaned record identification
    NOTE: ClockInDateKey created directly from date to avoid dimension lookup issues
    */
    
    HandleMissingKeys = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(CreateDateKey,
                    "TechnicianKey", each [TechnicianDimKey] ?? -1, Int64.Type),
                "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),
            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),
        "DimWorkOrderKey", each [WorkOrderMasterKey] ?? -1, Int64.Type),
    
    // ========================================================================
    // STEP 7: ENHANCED JOB-LEVEL BUSINESS LOGIC
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
    // STEP 8: OPERATIONAL FLAGS FOR FACT TABLE ANALYSIS
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
    // STEP 9: FINAL COLUMN SELECTION AND OPTIMIZATION
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
        
        // ===== ORIGINAL KEYS FOR REFERENCE =====
        "WorkOrderKey"
    }),
    
    // ========================================================================
    // STEP 10: FINAL DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for performance and memory efficiency
    BUSINESS LOGIC: Appropriate data types for each column based on content and usage
    BENEFIT: Optimal query performance and minimal memory footprint
    */
    
    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {
        // Dimension keys
        {"TechnicianKey", Int64.Type}, {"BranchKey", Int64.Type}, 
        {"JobCodeKey", Int64.Type}, {"DimWorkOrderKey", Int64.Type}, {"ClockInDateKey", Int64.Type},
        
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
        
        // Reference keys
        {"WorkOrderKey", type text}
    })

in
    FinalDataTypes

/*
============================================================================
✅ FACT_LABORJOBS - COMPREHENSIVE JOB-LEVEL ANALYTICS EXCELLENCE
============================================================================

🎯 CRITICAL BUSINESS CAPABILITIES:
• Complete Job Costing: Labor cost, sale, margin, and profitability analysis per job
• Technician Specialization: Individual skill tracking and development planning
• Operational Excellence: Delay analysis, rework patterns, and quality improvement
• Financial Intelligence: Job-level profitability supporting pricing and margin optimization
• Cross-Fact Integration: Perfect foundation linking punch detail to work order summaries
• Performance Management: Efficiency tracking, quality assessment, and training identification

⚡ PERFORMANCE & ARCHITECTURE EXCELLENCE:
• Target Refresh: 2-3 minutes (optimized by leveraging raw table calculations)
• Memory Efficient: Uses existing calculated fields with minimal additional processing
• CU Optimized: Inherits raw table optimization with focused dimensional relationships
• Incremental Ready: Full incremental refresh capability through raw table design
• Data Quality Optimized: Removed low-value columns and fixed date key generation issues

🔗 DIMENSIONAL INTEGRATION SUCCESS:
• TechnicianKey → Individual technician performance and skill specialization analysis
• BranchKey → Territory-based labor cost and efficiency comparison
• JobCodeKey → Service type expertise and complexity assessment
• DimWorkOrderKey → CRITICAL cross-fact integration enabling complete work order analysis
• ClockInDateKey → Time intelligence via direct date key (Power BI can link to date dimension)

📊 JOB-LEVEL BUSINESS INTELLIGENCE:
• Financial Analysis: Complete cost/sale/margin breakdown with profitability classification
• Quality Management: Efficiency categorization with rework and delay correlation
• Skill Development: Specialty work identification with training opportunity flagging
• Operational Optimization: Problem job identification with performance improvement focus
• Resource Planning: Overtime detection and complexity assessment for capacity planning

🚀 CROSS-FACT ANALYTICAL FOUNDATION:
• Punch Integration: Links to Fact_LaborPunches via TechnicianKey and DimWorkOrderKey
• Work Order Analysis: Provides job-level detail for complete work order profitability
• Customer Intelligence: Job-level performance supporting customer satisfaction analysis
• Equipment Analysis: Service complexity analysis for equipment reliability and maintenance

============================================================================

📈 DASHBOARD IMPLEMENTATION RECOMMENDATIONS:

🎯 EXECUTIVE JOB PROFITABILITY DASHBOARD:
• KPI Matrix: Total labor margin, efficiency %, high-value job count, quality score
• Profitability Analysis: Job margin by customer, equipment type, and service complexity
• Performance Trends: Monthly job efficiency and profitability trending with targets
• Territory Comparison: Branch labor performance with cost and efficiency benchmarking

⚙️ OPERATIONS MANAGEMENT DASHBOARD:
• Job Queue Analytics: Real-time job status with efficiency and quality predictions
• Problem Job Management: Rework and delay analysis with root cause identification
• Resource Optimization: Technician workload balancing with skill matching recommendations
• Quality Improvement: Job quality trends with training opportunity identification

👥 TECHNICIAN DEVELOPMENT DASHBOARD:
• Individual Performance: Comprehensive technician scorecards with efficiency and specialization
• Skill Analysis: Job type expertise mapping with development opportunity identification
• Training Programs: Performance gap analysis with targeted improvement recommendations
• Career Pathing: Specialization trends supporting technician advancement planning

🔧 OPERATIONAL EXCELLENCE DASHBOARD:
• Job Complexity Analytics: Complexity distribution with resource allocation optimization
• Efficiency Improvement: Best practice identification and performance benchmarking
• Process Optimization: Delay and rework pattern analysis with process improvement recommendations
• Financial Performance: Job-level margin analysis supporting pricing and service optimization

============================================================================

🏆 CROSS-FACT INTEGRATION CAPABILITIES:

📊 WITH FACT_LABORPUNCHES:
• Complete Labor Analysis: Punch detail combined with job-level costing and profitability
• Efficiency Correlation: Individual punch efficiency vs job-level performance analysis
• Time Management: Punch patterns supporting job completion and quality outcomes

💰 WITH FACT_WORKORDERHEADER:
• Complete Service Profitability: Job-level labor costs within total work order analysis
• Customer Service Excellence: Labor quality and efficiency impact on customer satisfaction
• Equipment Service Analysis: Job complexity and labor requirements by equipment type

🔧 WITH FUTURE FACT TABLES:
• Parts Integration: Labor and parts cost correlation for complete service cost analysis
• Invoice Integration: Job-level labor supporting complete financial and billing analysis
• Warranty Integration: Labor quality correlation with warranty claims and equipment reliability

============================================================================
*/