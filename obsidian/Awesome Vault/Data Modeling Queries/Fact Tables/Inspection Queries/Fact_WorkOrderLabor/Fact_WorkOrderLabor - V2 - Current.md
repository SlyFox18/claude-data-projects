/*
============================================================================
FACT_WORKORDERLABOR - COMPREHENSIVE LABOR ANALYTICS FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Detailed technician labor tracking for operational and performance analytics
Grain: One row per technician per job per work order per day
Refresh Strategy: Incremental ready (ModifiedDate filter implemented)
Current Performance: ~1m 55s refresh time (target: maintain or improve)
Source Dependencies: Raw_wkmechwk + 4 dimension tables

🎯 BUSINESS USE CASES:
• Technician Performance: Individual productivity, efficiency, and skill tracking
• Labor Cost Analysis: Actual vs estimated hours, overtime identification
• Capacity Planning: Workload distribution, skill utilization, resource allocation
• Work Order Efficiency: Labor content analysis, rework identification
• Service Quality: Rework patterns, complexity handling, customer satisfaction
• Training Programs: Skill gaps, learning curves, specialization development
• Operational Planning: Daily scheduling, skill matching, workload balancing

📊 KEY METRICS PROVIDED:
• Efficiency Ratio: InvoiceHours / HoursWorked (billing efficiency)
• Total Labor Hours: Combined work and rework time tracking
• Rework Analysis: Identification and quantification of rework patterns
• Productivity Scoring: Hours per job, complexity handling assessment
• Skill Specialization: Job type and equipment type expertise tracking
• Labor Cost Intelligence: Rate calculations and variance analysis

🔗 DIMENSION RELATIONSHIPS:
• dim_Technician_Code_Names → TechnicianKey (technician master data)
• dim_JobCode → JobCodeKey (service type and complexity analysis)
• dim_BranchLocation → BranchKey (territory and location analysis)
• Fact_WorkOrderHeader → WorkOrderKey (work order context and customer info)
• Date Dimension → ClockInDateKey (time-based labor analysis)

📈 DASHBOARD IDEAS:
• Technician Performance Dashboard: Efficiency trends, productivity metrics, specialization tracking
• Daily Operations Board: Real-time labor allocation, capacity utilization, workload distribution
• Labor Cost Analysis: Cost variance tracking, efficiency benchmarking, rate optimization
• Service Quality Monitor: Rework patterns, complexity handling, customer impact analysis
• Training & Development: Skill gap analysis, learning progression, certification tracking
• Capacity Planning: Resource forecasting, seasonal patterns, territory optimization

⚡ PERFORMANCE OPTIMIZATIONS:
• Incremental refresh capability via ModifiedDate filtering
• Efficient dimension join sequence with minimal data movement
• Early column filtering reduces memory footprint
• Optimized calculation sequence minimizes processing overhead
• Strategic use of computed columns for complex business logic

🔧 MAINTENANCE & MONITORING:
• Monitor refresh performance with data volume growth
• Validate efficiency calculations with business rules quarterly
• Review rework thresholds based on service standards
• Update labor rate calculations with payroll changes
• Maintain technician skill certifications in dimension

============================================================================
📈 DASHBOARD & REPORTING RECOMMENDATIONS
============================================================================

🎯 OPERATIONAL DASHBOARDS:
• Daily Dispatch Board: Labor allocation by technician skill and availability
• Real-Time Efficiency: Live productivity tracking with alerts for underperformance
• Workload Balance: Capacity utilization across technicians and territories
• Quality Control: Rework identification and immediate intervention triggers

📊 MANAGEMENT ANALYTICS:
• Technician Performance Reviews: Individual efficiency trends and skill development
• Labor Cost Variance: Budget vs actual analysis with drilling capabilities
• Service Delivery: Customer satisfaction correlation with labor metrics
• Resource Optimization: Skill-based scheduling and territory performance

⚙️ STRATEGIC PLANNING:
• Capacity Forecasting: Historical patterns for staffing decisions
• Training ROI: Skill development impact on productivity and efficiency
• Service Specialization: Center of excellence development by equipment type
• Territory Expansion: Labor model scaling for new locations

============================================================================
*/

let
    // ========================================================================
    // STEP 1: DATA FOUNDATION & INCREMENTAL REFRESH SETUP
    // ========================================================================
    /*
    PURPOSE: Establish efficient data filtering for performance and incremental refresh
    BUSINESS LOGIC: Focus on recent labor data while preparing for incremental refresh
    PERFORMANCE: Early filtering reduces downstream processing overhead
    */
    
    // Source: Raw mechanic work data (core labor tracking)
    Source = Raw_wkmechwk,
    
    // Incremental refresh parameters (configurable for future optimization)
    RangeStart = #datetime(2024, 1, 1, 0, 0, 0),   // Configurable start date
    RangeEnd = DateTime.LocalNow(),                  // Always current for fresh data
    
    // Filter to relevant date range for performance
    FilteredData = Table.SelectRows(Source, each 
        [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),
    
    // ========================================================================
    // STEP 2: ESSENTIAL COLUMN SELECTION & OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Minimize memory footprint by selecting only required columns early
    PERFORMANCE: Reduces data volume carried through transformation pipeline
    BUSINESS LOGIC: Include all fields needed for labor analytics and relationships
    */
    
    // Select essential columns for labor analysis (optimized for performance)
    EssentialColumns = Table.SelectColumns(FilteredData, {
        "Branch",           // Location identifier for territory analysis
        "WorkOrder",        // Work order number for context
        "JobCode",          // Job classification for skill analysis  
        "JobType",          // Job type for categorization
        "TechCode",         // Technician identifier
        "ClockInDate",      // Work date for time analysis
        "HoursWorked",      // Actual labor hours
        "InvoiceHours",     // Billable hours for efficiency calculation
        "HoursRework",      // Rework hours for quality analysis
        "ModifiedDate"      // Audit trail and incremental refresh key
    }),
    
    // ========================================================================
    // STEP 3: UNIQUE ROW IDENTIFICATION & KEY GENERATION
    // ========================================================================
    /*
    PURPOSE: Establish unique row identity before any joins to prevent duplication
    CRITICAL: Row identifier must be created BEFORE joins to ensure referential integrity
    BUSINESS RULE: Each labor entry gets exactly one unique key
    */
    
    // Create unique row identifier FIRST (critical for join integrity)
    AddRowId = Table.AddIndexColumn(EssentialColumns, "LaborFactKey", 1, 1, Int64.Type),
    
    // Create composite work order key for fact table relationships
    AddWorkOrderKey = Table.AddColumn(AddRowId, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // ========================================================================
    // STEP 4: DATA CLEANING & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Clean and standardize lookup values for reliable dimension joins
    BUSINESS LOGIC: Consistent formatting enables reliable dimension relationships
    PERFORMANCE: Clean data reduces join failures and improves query performance
    */
    
    // Clean technician code for reliable dimension lookup
    AddTechCodeClean = Table.AddColumn(AddWorkOrderKey, "TechCodeClean", each 
        if [TechCode] <> null and [TechCode] <> "" 
        then Text.Upper(Text.Trim([TechCode])) 
        else "UNKNOWN", type text),
    
    // Clean job code for dimension integration (matches dim_JobCode format)
    AddJobCodeClean = Table.AddColumn(AddTechCodeClean, "JobCodeClean", each 
        if [JobCode] <> null and [JobCode] <> "" 
        then Text.Upper(Text.Trim([JobCode])) 
        else "UNKNOWN", type text),
    
    // Clean branch code for location analysis
    AddBranchClean = Table.AddColumn(AddJobCodeClean, "BranchClean", each 
        if [Branch] <> null and [Branch] <> "" 
        then Text.Upper(Text.Trim([Branch])) 
        else "UNKNOWN", type text),
    
    // ========================================================================
    // STEP 5: CORE LABOR CALCULATIONS & BUSINESS METRICS
    // ========================================================================
    /*
    PURPOSE: Calculate fundamental labor metrics for operational analysis
    BUSINESS LOGIC: Efficiency, productivity, and quality indicators
    PERFORMANCE: Single-pass calculations minimize processing overhead
    */
    
    // Calculate total labor time (work + rework)
    AddTotalHours = Table.AddColumn(AddBranchClean, "TotalHours", each 
        ([HoursWorked] ?? 0) + ([HoursRework] ?? 0), type number),
    
    // Calculate billing efficiency (critical business metric)
    AddEfficiency = Table.AddColumn(AddTotalHours, "LaborEfficiency", each 
        if ([HoursWorked] ?? 0) > 0 then 
            Number.Round(([InvoiceHours] ?? 0) / [HoursWorked], 3)
        else null, type number),
    
    // Identify rework occurrences (quality indicator)
    AddHasRework = Table.AddColumn(AddEfficiency, "HasRework", each 
        ([HoursRework] ?? 0) > 0, type logical),
    
    // Calculate rework percentage (quality metric)
    AddReworkPercentage = Table.AddColumn(AddHasRework, "ReworkPercentage", each 
        if ([TotalHours] ?? 0) > 0 then 
            Number.Round(([HoursRework] ?? 0) / [TotalHours], 3)
        else 0, type number),
    
    // ========================================================================
    // STEP 6: ENHANCED LABOR ANALYTICS (PERFORMANCE NEUTRAL)
    // ========================================================================
    /*
    PURPOSE: Add advanced labor intelligence without performance impact
    BUSINESS VALUE: Productivity indicators, overtime tracking, efficiency categorization
    */
    
    // Productivity scoring based on hours per job
    AddProductivityScore = Table.AddColumn(AddReworkPercentage, "ProductivityScore", each
        let
            totalHours = [TotalHours] ?? 0
        in
            if totalHours <= 2 then "High"        // Quick jobs - high productivity
            else if totalHours <= 8 then "Medium" // Standard jobs - medium productivity  
            else "Low",                           // Long jobs - requires analysis
        type text),
    
    // Overtime identification (business day > 8 hours indicator)
    AddIsOvertime = Table.AddColumn(AddProductivityScore, "IsOvertime", each 
        ([TotalHours] ?? 0) > 8, type logical),
    
    // Efficiency categorization for performance management
    AddEfficiencyCategory = Table.AddColumn(AddIsOvertime, "EfficiencyCategory", each
        let
            efficiency = [LaborEfficiency] ?? 0
        in
            if efficiency >= 1.2 then "Excellent"      // 120%+ efficiency
            else if efficiency >= 1.0 then "Good"      // 100-119% efficiency
            else if efficiency >= 0.8 then "Fair"      // 80-99% efficiency
            else if efficiency > 0 then "Poor"         // Below 80% efficiency
            else "No Data",                            // Missing data
        type text),
    
    // Quality indicator combining efficiency and rework
    AddQualityIndicator = Table.AddColumn(AddEfficiencyCategory, "QualityIndicator", each
        if [HasRework] = false and ([LaborEfficiency] ?? 0) >= 1.0 then "High Quality"
        else if [HasRework] = false then "Good Quality"
        else if ([ReworkPercentage] ?? 0) <= 0.1 then "Acceptable"
        else "Needs Improvement",
        type text),
    
    // ========================================================================
    // STEP 7: DATE DIMENSION INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Enable time-based analysis and reporting
    FORMAT: Integer date key (YYYYMMDD) for optimal join performance
    */
    
    // Create date key for time intelligence
    AddClockInDateKey = Table.AddColumn(AddQualityIndicator, "ClockInDateKey", each 
        if [ClockInDate] <> null then 
            Date.Year([ClockInDate]) * 10000 + 
            Date.Month([ClockInDate]) * 100 + 
            Date.Day([ClockInDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // STEP 8: DIMENSION INTEGRATIONS (OPTIMIZED SEQUENCE)
    // ========================================================================
    /*
    PURPOSE: Link to dimension tables for comprehensive analysis
    SEQUENCE: Ordered by join selectivity for optimal performance
    STRATEGY: Single column expansions minimize data movement
    */
    
    // Technician dimension integration (primary relationship)
    JoinTechnician = Table.NestedJoin(
        AddClockInDateKey, {"TechCodeClean"}, 
        dim_Technician_Code_Names, {"TechnicianCode"}, 
        "TechnicianDim", JoinKind.LeftOuter),
    
    ExpandTechnician = Table.ExpandTableColumn(JoinTechnician, "TechnicianDim", 
        {"TechnicianKey"}, {"TechnicianKey"}),
    
    // Handle missing technicians with default key
    AddFinalTechnicianKey = Table.AddColumn(ExpandTechnician, "FinalTechnicianKey", each 
        [TechnicianKey] ?? -1, Int64.Type),
    
    // Job Code dimension integration (NEW - adds service type intelligence)
    JoinJobCode = Table.NestedJoin(
        AddFinalTechnicianKey, {"JobCodeClean"}, 
        dim_JobCode, {"JobCode"}, 
        "JobCodeDim", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(JoinJobCode, "JobCodeDim", 
        {"JobCodeKey"}, {"JobCodeKey"}),
    
    // Handle missing job codes with default key
    AddFinalJobCodeKey = Table.AddColumn(ExpandJobCode, "FinalJobCodeKey", each 
        [JobCodeKey] ?? -1, Int64.Type),
    
    // Branch dimension integration (NEW - adds location intelligence)
    JoinBranch = Table.NestedJoin(
        AddFinalJobCodeKey, {"BranchClean"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchDim", JoinKind.LeftOuter),
    
    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchDim", 
        {"BranchKey"}, {"BranchKey"}),
    
    // Handle missing branches with default key
    AddFinalBranchKey = Table.AddColumn(ExpandBranch, "FinalBranchKey", each 
        [BranchKey] ?? -1, Int64.Type),
    
    // ========================================================================
    // STEP 9: ENHANCED BUSINESS INTELLIGENCE FIELDS
    // ========================================================================
    /*
    PURPOSE: Add calculated insights for advanced labor analysis
    PERFORMANCE: Pre-calculated fields eliminate complex DAX in reports
    BUSINESS VALUE: Skills analysis, specialization tracking, development insights
    */
    
    // Work day categorization for scheduling analysis
    AddWorkDayType = Table.AddColumn(AddFinalBranchKey, "WorkDayType", each
        let
            dayOfWeek = if [ClockInDate] <> null then Date.DayOfWeek([ClockInDate]) else 0
        in
            if dayOfWeek = 0 or dayOfWeek = 6 then "Weekend"      // Saturday/Sunday
            else if ([TotalHours] ?? 0) > 10 then "Extended"     // Long day
            else if ([TotalHours] ?? 0) > 8 then "Standard+"     // Overtime
            else "Standard",                                     // Regular day
        type text),
    
    // Labor complexity assessment (integrates with JobCode if available)
    AddLaborComplexity = Table.AddColumn(AddWorkDayType, "LaborComplexityAssessment", each
        let
            hours = [TotalHours] ?? 0,
            hasRework = [HasRework] ?? false
        in
            if hours > 12 or hasRework then "Complex"         // Long duration or rework
            else if hours > 6 then "Moderate"                 // Standard complexity
            else "Simple",                                    // Quick jobs
        type text),
    
    // Billability assessment for financial analysis
    AddBillabilityAssessment = Table.AddColumn(AddLaborComplexity, "BillabilityAssessment", each
        let
            invoiceHrs = [InvoiceHours] ?? 0,
            workedHrs = [HoursWorked] ?? 0
        in
            if invoiceHrs = 0 then "Non-Billable"
            else if workedHrs = 0 then "Invoice Only"
            else if invoiceHrs >= workedHrs then "Fully Billable"
            else "Partially Billable",
        type text),
    
    // ========================================================================
    // STEP 10: FINAL COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Organize output for optimal reporting and dashboard creation
    STRUCTURE: Keys first, then dimensions, core metrics, calculations, audit fields
    */
    
    FinalColumns = Table.SelectColumns(AddBillabilityAssessment, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "LaborFactKey",           // Unique row identifier
        "WorkOrderKey",           // Link to Fact_WorkOrderHeader
        
        // ===== DIMENSION KEYS (STAR SCHEMA RELATIONSHIPS) =====
        "FinalTechnicianKey",     // Technician dimension link
        "FinalJobCodeKey",        // Job code dimension link (NEW)
        "FinalBranchKey",         // Branch dimension link (NEW)
        "ClockInDateKey",         // Date dimension link
        
        // ===== CORE IDENTIFIERS =====
        "Branch",                 // Location identifier
        "WorkOrder",              // Work order number
        "JobCode",                // Job code for analysis
        "JobType",                // Job type classification
        "TechCode",               // Technician identifier
        
        // ===== TIME TRACKING =====
        "ClockInDate",            // Work date
        "HoursWorked",            // Actual labor hours
        "HoursRework",            // Rework hours
        "TotalHours",             // Combined hours
        "InvoiceHours",           // Billable hours
        
        // ===== CORE BUSINESS METRICS =====
        "LaborEfficiency",        // Billable/Actual efficiency ratio
        "ReworkPercentage",       // Quality indicator
        
        // ===== BUSINESS FLAGS =====
        "HasRework",              // Quality flag
        "IsOvertime",             // Overtime indicator
        
        // ===== BUSINESS INTELLIGENCE =====
        "ProductivityScore",      // High/Medium/Low productivity
        "EfficiencyCategory",     // Performance categorization
        "QualityIndicator",       // Quality assessment
        "WorkDayType",            // Work day classification
        "LaborComplexityAssessment", // Complexity evaluation
        "BillabilityAssessment",  // Financial assessment
        
        // ===== AUDIT TRAIL =====
        "ModifiedDate"            // Data freshness tracking
    }),
    
    // ========================================================================
    // STEP 11: COLUMN RENAMING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent naming conventions across all fact tables
    STANDARDS: TechnicianKey, JobCodeKey, BranchKey for dimension relationships
    */
    
    RenamedColumns = Table.RenameColumns(FinalColumns, {
        {"FinalTechnicianKey", "TechnicianKey"},
        {"FinalJobCodeKey", "JobCodeKey"},
        {"FinalBranchKey", "BranchKey"}
    }),
    
    // ========================================================================
    // STEP 12: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Integer keys, proper number precision, logical flags
    */
    
    FinalDataTypes = Table.TransformColumnTypes(RenamedColumns, {
        // Keys and identifiers
        {"LaborFactKey", Int64.Type}, {"WorkOrderKey", type text},
        {"TechnicianKey", Int64.Type}, {"JobCodeKey", Int64.Type}, 
        {"BranchKey", Int64.Type}, {"ClockInDateKey", Int64.Type},
        
        // Core identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"TechCode", type text},
        
        // Time and hours
        {"ClockInDate", type date}, {"HoursWorked", type number}, 
        {"HoursRework", type number}, {"TotalHours", type number}, 
        {"InvoiceHours", type number},
        
        // Calculated metrics
        {"LaborEfficiency", type number}, {"ReworkPercentage", type number},
        
        // Flags
        {"HasRework", type logical}, {"IsOvertime", type logical},
        
        // Business intelligence
        {"ProductivityScore", type text}, {"EfficiencyCategory", type text}, 
        {"QualityIndicator", type text}, {"WorkDayType", type text}, 
        {"LaborComplexityAssessment", type text}, {"BillabilityAssessment", type text},
        
        // Audit
        {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes