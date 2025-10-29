/*
============================================================================
FACT_LABORCOST - COMPREHENSIVE LABOR COST & PROFITABILITY ANALYTICS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Labor cost tracking and variance analysis separate from hours tracking
Grain: One row per job per work order (job-level cost analysis)
Refresh Strategy: Incremental ready (ModifiedDate filter implemented)
Current Performance: ~XX seconds (needs current timing)
Source Dependencies: Raw_wkothsub + 2 dimension tables

🎯 BUSINESS USE CASES:
• Cost Variance Analysis: Estimated vs actual labor cost tracking
• Profitability Assessment: Labor margin analysis by job type and location
• Pricing Optimization: Cost efficiency patterns for rate setting
• Field vs Shop Analysis: Location-based cost comparison and optimization
• Budget Management: Estimate accuracy tracking and improvement
• Service Pricing: Margin analysis for service pricing strategies
• Operational Efficiency: Cost performance benchmarking across branches
• Financial Planning: Labor cost forecasting and budget variance analysis

📊 KEY METRICS PROVIDED:
• Labor Cost Variance: ActLabor - EstLabor (estimation accuracy)
• Labor Margin: InvLabor - ActLabor (profitability per job)
• Cost Efficiency: ActLabor / EstLabor (performance vs estimate)
• Field/Shop Cost Comparison: Location-based cost analysis
• Profitability Scoring: Margin categorization and assessment
• Cost Trend Analysis: Historical cost pattern identification

🔗 DIMENSION RELATIONSHIPS:
• dim_JobCode → JobCodeKey (service type and complexity cost analysis)
• dim_BranchLocation → BranchKey (territory cost performance analysis)
• Fact_WorkOrderHeader → WorkOrderKey (work order context integration)
• Fact_WorkOrderLabor → WorkOrderKey (cost vs hours correlation analysis)
• Date Dimension → InvoiceDateKey (time-based cost trend analysis)

📈 DASHBOARD IDEAS:
• Cost Variance Dashboard: Estimation accuracy tracking with improvement recommendations
• Profitability Analysis: Margin trends by service type, location, and complexity
• Field Operations Cost: Field vs shop cost efficiency comparison
• Budget Performance: Actual vs estimated cost variance monitoring
• Pricing Intelligence: Cost-based pricing recommendations and margin optimization
• Branch Performance: Territory-based cost efficiency and profitability ranking

⚡ PERFORMANCE OPTIMIZATIONS:
• Incremental refresh capability via ModifiedDate filtering
• Separate table avoids many-to-many join complexity with labor hours
• Early column filtering reduces memory footprint
• Efficient dimension join sequence minimizes processing overhead
• Strategic cost calculations performed once in ETL vs multiple times in DAX

🔧 MAINTENANCE & MONITORING:
• Monitor estimation accuracy trends for continuous improvement
• Review labor rate changes quarterly for cost calculation accuracy
• Validate field repair cost differentials with operational teams
• Update standard labor indicators based on service offerings
• Track margin trends for pricing strategy adjustments

============================================================================
📈 DASHBOARD & REPORTING RECOMMENDATIONS
============================================================================

🎯 EXECUTIVE DASHBOARDS:
• Profitability Overview: Labor margin trends with actionable insights
• Cost Performance: Variance analysis with root cause identification
• Service Pricing: Margin-based pricing recommendations and optimization
• Territory Performance: Branch-level cost efficiency ranking and improvement

📊 OPERATIONAL ANALYTICS:
• Estimation Accuracy: Cost variance tracking for process improvement
• Field Operations: Location-based cost analysis and resource optimization
• Service Efficiency: Job type cost performance and specialization benefits
• Budget Monitoring: Real-time cost tracking vs budget with alerts

⚙️ STRATEGIC PLANNING:
• Pricing Strategy: Historical cost trends for competitive pricing decisions
• Service Mix: Profitability analysis for service portfolio optimization
• Capacity Planning: Cost-based resource allocation and territory expansion
• Investment ROI: Cost efficiency improvements and technology investments

============================================================================
*/

let
    // ========================================================================
    // STEP 1: DATA FOUNDATION & INCREMENTAL REFRESH SETUP
    // ========================================================================
    /*
    PURPOSE: Efficient data filtering and incremental refresh preparation
    BUSINESS LOGIC: Focus on recent cost data while maintaining complete analysis
    PERFORMANCE: Early filtering reduces processing overhead throughout pipeline
    */
    
    // Source: Raw work order other sub data (job-level cost information)
    Source = Raw_wkothsub,
    
    // Incremental refresh parameters (configurable for optimization)
    RangeStart = #datetime(2024, 1, 1, 0, 0, 0),   // Configurable start date
    RangeEnd = DateTime.LocalNow(),                  // Current data for real-time analysis
    
    // Filter to relevant date range for performance and incremental refresh
    FilteredData = Table.SelectRows(Source, each 
        [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),
    
    // ========================================================================
    // STEP 2: ESSENTIAL COLUMN SELECTION & OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Minimize memory footprint with strategic column selection
    PERFORMANCE: Reduces data volume through transformation pipeline
    BUSINESS LOGIC: Include all fields required for cost analysis and relationships
    */
    
    // Select essential columns for cost analysis (performance optimized)
    EssentialColumns = Table.SelectColumns(FilteredData, {
        "Branch",           // Location identifier for territory cost analysis
        "WorkOrder",        // Work order number for context and relationships
        "JobCode",          // Job classification for cost categorization
        "JobType",          // Job type for cost pattern analysis
        "EstHours",         // Estimated hours for efficiency calculation
        "EstLabor",         // Estimated labor cost (budget baseline)
        "ActLabor",         // Actual labor cost (performance measurement)
        "InvLabor",         // Invoiced labor amount (revenue realization)
        "FieldRepair",      // Field vs shop indicator for cost comparison
        "IsStandardLabor",  // Standard labor flag for categorization
        "InvoiceNumber",    // Invoice reference for financial tracking
        "InvoiceDate",      // Invoice date for time-based analysis
        "ModifiedDate"      // Audit trail and incremental refresh key
    }),
    
    // ========================================================================
    // STEP 3: UNIQUE ROW IDENTIFICATION & KEY GENERATION
    // ========================================================================
    /*
    PURPOSE: Establish unique row identity and relationship keys
    BUSINESS RULE: Each job cost entry gets exactly one unique identifier
    CRITICAL: Unique identifier created before joins to ensure integrity
    */
    
    // Create unique row identifier for cost tracking
    AddRowId = Table.AddIndexColumn(EssentialColumns, "CostFactKey", 1, 1, Int64.Type),
    
    // Create composite work order key for fact table relationships
    AddWorkOrderKey = Table.AddColumn(AddRowId, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Create detailed job-level key for granular analysis
    AddJobKey = Table.AddColumn(AddWorkOrderKey, "JobKey", each 
        [Branch] & "-" & Text.From([WorkOrder]) & "-" & 
        Text.Trim([JobCode] ?? "") & "-" & Text.Trim([JobType] ?? ""), 
        type text),
    
    // ========================================================================
    // STEP 4: DATA CLEANING & STANDARDIZATION
    // ========================================================================
    /*
    PURPOSE: Clean and standardize data for reliable dimension joins
    BUSINESS LOGIC: Consistent formatting enables reliable relationships
    PERFORMANCE: Clean data reduces join failures and improves performance
    */
    
    // Clean job code for dimension integration
    AddJobCodeClean = Table.AddColumn(AddJobKey, "JobCodeClean", each 
        if [JobCode] <> null and [JobCode] <> "" 
        then Text.Upper(Text.Trim([JobCode])) 
        else "UNKNOWN", type text),
    
    // Clean branch code for location analysis
    AddBranchClean = Table.AddColumn(AddJobCodeClean, "BranchClean", each 
        if [Branch] <> null and [Branch] <> "" 
        then Text.Upper(Text.Trim([Branch])) 
        else "UNKNOWN", type text),
    
    // ========================================================================
    // STEP 5: BUSINESS LOGIC FLAGS & LOCATION ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Convert text flags to logical values and add location intelligence
    BUSINESS LOGIC: Field repairs typically have different cost structures
    PERFORMANCE: Boolean operations are more efficient than text comparisons
    */
    
    // Convert field repair flag to logical for efficient filtering
    AddIsFieldRepair = Table.AddColumn(AddBranchClean, "IsFieldRepair", each 
        Text.Upper([FieldRepair] ?? "N") = "Y", type logical),
    
    // Create descriptive work location for analysis
    AddWorkLocation = Table.AddColumn(AddIsFieldRepair, "WorkLocation", each 
        if Text.Upper([FieldRepair] ?? "N") = "Y" then "Field" else "Shop", 
        type text),
    
    // Convert standard labor flag to logical
    AddIsStandardLaborFlag = Table.AddColumn(AddWorkLocation, "IsStandardLaborFlag", each 
        Text.Upper([IsStandardLabor] ?? "N") = "Y", type logical),
    
    // ========================================================================
    // STEP 6: CORE COST CALCULATIONS & VARIANCE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Calculate fundamental cost metrics for financial analysis
    BUSINESS LOGIC: Track estimation accuracy, profitability, and efficiency
    PERFORMANCE: Single-pass calculations minimize processing overhead
    */
    
    // Calculate labor cost variance (actual vs estimated)
    AddLaborCostVariance = Table.AddColumn(AddIsStandardLaborFlag, "LaborCostVariance", each 
        ([ActLabor] ?? 0) - ([EstLabor] ?? 0), type number),
    
    // Calculate labor margin (profitability per job)
    AddLaborMargin = Table.AddColumn(AddLaborCostVariance, "LaborMargin", each 
        ([InvLabor] ?? 0) - ([ActLabor] ?? 0), type number),
    
    // Calculate cost efficiency (performance vs estimate)
    AddCostEfficiency = Table.AddColumn(AddLaborMargin, "CostEfficiency", each 
        if ([EstLabor] ?? 0) > 0 then 
            Number.Round(([ActLabor] ?? 0) / [EstLabor], 3)
        else null, type number),
    
    // Calculate margin percentage for profitability analysis
    AddMarginPercentage = Table.AddColumn(AddCostEfficiency, "MarginPercentage", each 
        if ([InvLabor] ?? 0) > 0 then 
            Number.Round(([LaborMargin] ?? 0) / [InvLabor], 3)
        else null, type number),
    
    // ========================================================================
    // STEP 7: ENHANCED COST ANALYTICS (PERFORMANCE NEUTRAL)
    // ========================================================================
    /*
    PURPOSE: Add advanced cost intelligence without performance impact
    BUSINESS VALUE: Profitability categorization, cost trend analysis, variance assessment
    */
    
    // Profitability categorization for business analysis
    AddProfitabilityCategory = Table.AddColumn(AddMarginPercentage, "ProfitabilityCategory", each
        let
            margin = [MarginPercentage] ?? 0
        in
            if margin >= 0.4 then "High Profit"        // 40%+ margin
            else if margin >= 0.2 then "Good Profit"   // 20-39% margin
            else if margin >= 0.05 then "Low Profit"   // 5-19% margin
            else if margin >= 0 then "Break Even"      // 0-4% margin
            else "Loss",                               // Negative margin
        type text),
    
    // Cost variance categorization for estimation improvement
    AddVarianceCategory = Table.AddColumn(AddProfitabilityCategory, "CostVarianceCategory", each
        let
            variance = [LaborCostVariance] ?? 0,
            estimated = [EstLabor] ?? 0,
            variancePercent = if estimated > 0 then variance / estimated else 0
        in
            if Number.Abs(variancePercent) <= 0.05 then "Accurate"      // Within 5%
            else if variancePercent > 0.2 then "Significant Over"       // 20%+ over estimate
            else if variancePercent > 0.05 then "Over Estimate"         // 5-20% over
            else if variancePercent < -0.2 then "Significant Under"     // 20%+ under estimate
            else "Under Estimate",                                      // 5-20% under
        type text),
    
    // Cost efficiency assessment for performance management
    AddEfficiencyAssessment = Table.AddColumn(AddVarianceCategory, "CostEfficiencyAssessment", each
        let
            efficiency = [CostEfficiency] ?? 0
        in
            if efficiency <= 0.8 then "Excellent"      // 20%+ under budget
            else if efficiency <= 1.0 then "Good"      // At or under budget
            else if efficiency <= 1.2 then "Fair"      // 20% over budget
            else "Poor",                               // More than 20% over
        type text),
    
    // Job value categorization for resource allocation
    AddJobValueCategory = Table.AddColumn(AddEfficiencyAssessment, "JobValueCategory", each
        let
            invoiced = [InvLabor] ?? 0
        in
            if invoiced >= 2000 then "High Value"      // $2000+ jobs
            else if invoiced >= 500 then "Medium Value" // $500-2000 jobs
            else if invoiced > 0 then "Low Value"      // Under $500 jobs
            else "No Value",                           // $0 jobs
        type text),
    
    // Field vs shop cost differential analysis
    AddLocationCostIndicator = Table.AddColumn(AddJobValueCategory, "LocationCostIndicator", each
        let
            actual = [ActLabor] ?? 0,
            location = [WorkLocation]
        in
            if location = "Field" and actual > 1000 then "High Field Cost"
            else if location = "Field" and actual > 300 then "Medium Field Cost"
            else if location = "Field" then "Low Field Cost"
            else if location = "Shop" and actual > 800 then "High Shop Cost"
            else if location = "Shop" and actual > 200 then "Medium Shop Cost"
            else "Low Shop Cost",
        type text),
    
    // ========================================================================
    // STEP 8: DATE DIMENSION INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Enable time-based cost analysis and trending
    FORMAT: Integer date key (YYYYMMDD) for optimal join performance
    */
    
    // Create invoice date key for time intelligence
    AddInvoiceDateKey = Table.AddColumn(AddLocationCostIndicator, "InvoiceDateKey", each 
        if [InvoiceDate] <> null then 
            Date.Year([InvoiceDate]) * 10000 + 
            Date.Month([InvoiceDate]) * 100 + 
            Date.Day([InvoiceDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // STEP 9: DIMENSION INTEGRATIONS (OPTIMIZED SEQUENCE)
    // ========================================================================
    /*
    PURPOSE: Link to dimension tables for comprehensive cost analysis
    SEQUENCE: Ordered by relationship importance and join selectivity
    STRATEGY: Single column expansions minimize data movement
    */
    
    // Job Code dimension integration (cost analysis by service type)
    JoinJobCode = Table.NestedJoin(
        AddInvoiceDateKey, {"JobCodeClean"}, 
        dim_JobCode, {"JobCode"}, 
        "JobCodeDim", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(JoinJobCode, "JobCodeDim", 
        {"JobCodeKey"}, {"JobCodeKey"}),
    
    // Handle missing job codes with default key
    AddFinalJobCodeKey = Table.AddColumn(ExpandJobCode, "FinalJobCodeKey", each 
        [JobCodeKey] ?? -1, Int64.Type),
    
    // Branch dimension integration (NEW - adds location cost intelligence)
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
    // STEP 10: FINAL COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Organize output for optimal reporting and dashboard creation
    STRUCTURE: Keys first, then identifiers, core metrics, calculations, audit fields
    */
    
    FinalColumns = Table.SelectColumns(AddFinalBranchKey, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "CostFactKey",            // Unique row identifier
        "WorkOrderKey",           // Link to Fact_WorkOrderHeader
        "JobKey",                 // Unique job-level identifier
        
        // ===== DIMENSION KEYS (STAR SCHEMA RELATIONSHIPS) =====
        "FinalJobCodeKey",        // Job code dimension link
        "FinalBranchKey",         // Branch dimension link (NEW)
        "InvoiceDateKey",         // Date dimension link
        
        // ===== CORE IDENTIFIERS =====
        "Branch",                 // Location identifier
        "WorkOrder",              // Work order number
        "JobCode",                // Job code for analysis
        "JobType",                // Job type classification
        "InvoiceNumber",          // Invoice reference
        
        // ===== TIME TRACKING =====
        "InvoiceDate",            // Invoice date
        "EstHours",               // Estimated hours
        
        // ===== CORE COST METRICS =====
        "EstLabor",               // Estimated labor cost
        "ActLabor",               // Actual labor cost
        "InvLabor",               // Invoiced labor amount
        
        // ===== CALCULATED COST ANALYTICS =====
        "LaborCostVariance",      // Actual vs estimated variance
        "LaborMargin",            // Profitability amount
        "CostEfficiency",         // Efficiency ratio
        "MarginPercentage",       // Margin percentage
        
        // ===== BUSINESS CATEGORIZATION =====
        "ProfitabilityCategory",  // Profit level classification
        "CostVarianceCategory",   // Variance assessment
        "CostEfficiencyAssessment", // Efficiency evaluation
        "JobValueCategory",       // Value tier classification
        "LocationCostIndicator",  // Field vs shop cost analysis
        
        // ===== LOCATION & OPERATIONAL FLAGS =====
        "WorkLocation",           // Field vs shop designation
        "IsFieldRepair",          // Field repair flag
        "IsStandardLaborFlag",    // Standard labor flag (temporary name)
        
        // ===== AUDIT TRAIL =====
        "ModifiedDate"            // Data freshness tracking
    }),
    
    // ========================================================================
    // STEP 11: COLUMN RENAMING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent naming conventions across all fact tables
    STANDARDS: JobCodeKey, BranchKey for dimension relationships
    */
    
    RenamedColumns = Table.RenameColumns(FinalColumns, {
        {"FinalJobCodeKey", "JobCodeKey"},
        {"FinalBranchKey", "BranchKey"},
        {"IsStandardLaborFlag", "IsStandardLabor"}
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
        {"CostFactKey", Int64.Type}, {"WorkOrderKey", type text}, {"JobKey", type text},
        {"JobCodeKey", Int64.Type}, {"BranchKey", Int64.Type}, {"InvoiceDateKey", Int64.Type},
        
        // Core identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"InvoiceNumber", type text},
        
        // Time and estimates
        {"InvoiceDate", type date}, {"EstHours", type number},
        
        // Cost metrics
        {"EstLabor", type number}, {"ActLabor", type number}, {"InvLabor", type number},
        
        // Calculated analytics
        {"LaborCostVariance", type number}, {"LaborMargin", type number}, 
        {"CostEfficiency", type number}, {"MarginPercentage", type number},
        
        // Categorization
        {"ProfitabilityCategory", type text}, {"CostVarianceCategory", type text}, 
        {"CostEfficiencyAssessment", type text}, {"JobValueCategory", type text}, 
        {"LocationCostIndicator", type text},
        
        // Location and flags
        {"WorkLocation", type text}, {"IsFieldRepair", type logical}, 
        {"IsStandardLabor", type logical},
        
        // Audit
        {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes