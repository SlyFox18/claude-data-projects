/*
============================================================================
FACT_LABORINVOICED - COMPREHENSIVE BILLING EFFICIENCY & REVENUE ANALYTICS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Invoice-level labor tracking with complete billing efficiency and revenue realization analytics
Grain: One row per technician per invoice entry (individual invoice records from TechnicianInvoiceDetail)
Refresh Strategy: Incremental refresh ready (ModifiedDate filtering via raw table)
Current Performance: Target 2-3 minutes refresh time
Source Dependencies: Raw_TechnicianInvoiceDetail + 4 dimension tables

🎯 BUSINESS USE CASES:
• Billing Efficiency Analysis: Complete invoice hours vs punched hours efficiency tracking
• Revenue Realization: Labor revenue analysis from work completion to invoice generation
• Quality & Performance: Rework analysis, delay tracking, and efficiency categorization
• Financial Intelligence: Labor margin analysis, profitability assessment, and cost optimization
• Technician Performance: Individual billing accuracy and revenue generation tracking
• Operational Excellence: Gain/loss analysis, productivity variance, and process improvement
• Cross-Fact Integration: Invoice-level foundation completing the labor analytics cycle
• Customer Billing Analysis: Invoice patterns, pricing efficiency, and revenue optimization

📊 KEY METRICS PROVIDED (PRE-CALCULATED IN RAW TABLE):
• Billing Efficiency Intelligence: Labor efficiency, calculated efficiency, efficiency categorization
• Financial Performance: Labor cost, sale, margin, margin percentage analysis
• Quality Assessment: Rework analysis, delay tracking, quality indicators
• Productivity Analytics: Gain/loss hours, total accounted hours, punch duration analysis
• Revenue Classification: Standard revenue, promotional, non-revenue categorization
• Performance Scoring: Efficiency categories, quality indicators, data quality assessment

🔗 DIMENSION RELATIONSHIPS:
• dim_Technician_Code_Names → TechnicianKey (technician billing performance and accuracy analysis)
• dim_BranchLocation → BranchKey (territory-based billing efficiency and revenue analysis)
• dim_JobCode → JobCodeKey (service type billing patterns and profitability analysis)
• dim_WorkOrderMaster → DimWorkOrderKey (CRITICAL: work order context and cross-fact integration)
• InvoiceDateKey & WorkDateKey → Direct date keys for time intelligence (from raw table)

📈 DASHBOARD IDEAS:
• Billing Efficiency Dashboard: Invoice hours vs punched hours with efficiency trending and targets
• Revenue Realization Analytics: Labor revenue tracking with margin analysis and optimization opportunities
• Technician Performance Scorecards: Individual billing accuracy, efficiency, and revenue generation
• Quality Management Dashboard: Rework analysis, delay tracking, and process improvement metrics
• Financial Intelligence: Labor profitability analysis supporting pricing and margin optimization
• Cross-Fact Revenue Analysis: Complete labor cycle from punch to job to invoice for total profitability

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Leverages ALL pre-calculated business logic from Raw_TechnicianInvoiceDetail
• Minimal processing overhead - focuses on dimensional relationships and fact table optimization
• Essential columns only for optimal memory usage and performance
• Inherits incremental refresh capability from raw table design
• Sub-3 minute refresh target achievable through raw table optimization
• Uses existing date keys to avoid dimension lookup issues

🔧 MAINTENANCE NOTES:
• Business logic centralized in Raw_TechnicianInvoiceDetail for consistency
• Monitor dimension lookup success rates for orphaned record identification
• Validate billing efficiency calculations if source system logic changes
• Review efficiency and quality thresholds based on operational performance standards
• Ensure work order key alignment with dim_WorkOrderMaster for cross-fact analysis

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA WITH COMPREHENSIVE BILLING INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Leverage excellent raw table with complete invoice-level business calculations
    BUSINESS LOGIC: Raw table contains billing efficiency, financial, and quality metrics
    BENEFIT: Focus on dimensional relationships while preserving comprehensive analytical richness
    */
    
    Source = Raw_TechnicianInvoiceDetail,
    
    // ========================================================================
    // STEP 2: DIMENSION LOOKUP - TECHNICIAN
    // ========================================================================
    /*
    PURPOSE: Link invoice records to technician master data for billing performance analysis
    BUSINESS LOGIC: TechCode → TechnicianCode for individual billing accuracy and efficiency tracking
    BENEFIT: Enables technician billing performance analysis, accuracy tracking, and development planning
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
    PURPOSE: Link invoice records to branch/territory information for billing analysis
    BUSINESS LOGIC: Branch → BranchID for territory-based billing efficiency and revenue analysis
    BENEFIT: Enables geographic billing performance comparison and revenue optimization
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
    PURPOSE: Link invoice records to service type classification for billing pattern analysis
    BUSINESS LOGIC: JobCode → JobCode for service type billing efficiency and profitability assessment
    BENEFIT: Enables job type billing analysis and service pricing optimization
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
    PURPOSE: Link invoice records to work order master data for cross-fact integration
    BUSINESS LOGIC: WorkOrder → WorkOrder for work order context and complete labor cycle analysis
    BENEFIT: CRITICAL - Enables cross-fact analysis and completes labor analytics cycle
    */
    
    WorkOrderLookup = Table.NestedJoin(
        ExpandJobCode, {"WorkOrder"}, 
        dim_WorkOrderMaster, {"WorkOrder"}, 
        "WorkOrderDim", JoinKind.LeftOuter),
    
    ExpandWorkOrder = Table.ExpandTableColumn(
        WorkOrderLookup, "WorkOrderDim", 
        {"WorkOrderKey"}, {"WorkOrderMasterKey"}),
    
    // ========================================================================
    // STEP 6: CREATE CLEAN DIMENSION KEYS
    // ========================================================================
    /*
    PURPOSE: Create clean dimension keys for fact table relationships
    BUSINESS LOGIC: Use dimension lookup keys where available, default to -1 for missing relationships
    BENEFIT: Clean fact table keys for optimal Power BI relationships and orphaned record identification
    NOTE: Using existing InvoiceDateKey and WorkDateKey from raw table for time intelligence
    */
    
    HandleMissingKeys = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(ExpandWorkOrder,
                    "TechnicianKey", each [TechnicianDimKey] ?? -1, Int64.Type),
                "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),
            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),
        "DimWorkOrderKey", each [WorkOrderMasterKey] ?? -1, Int64.Type),
    
    // ========================================================================
    // STEP 7: ENHANCED INVOICE-LEVEL BUSINESS LOGIC
    // ========================================================================
    /*
    PURPOSE: Add fact table specific business logic for invoice-level analysis
    BUSINESS LOGIC: Invoice-specific classifications and performance indicators
    BENEFIT: Enhanced analytical capability beyond raw table calculations
    */
    
    // Invoice value classification (based on labor sale value)
    AddInvoiceValueCategory = Table.AddColumn(HandleMissingKeys, "InvoiceValueCategory", each
        let saleValue = [LaborSale] ?? 0 in
        if saleValue >= 1000 then "High Value"
        else if saleValue >= 300 then "Medium Value"
        else if saleValue >= 50 then "Low Value"
        else "Minimal Value", type text),
    
    // Billing accuracy assessment (comparing different efficiency calculations)
    AddBillingAccuracy = Table.AddColumn(AddInvoiceValueCategory, "BillingAccuracy", each
        let
            laborEff = [LaborEfficiency] ?? 0,
            calcEff = [CalculatedEfficiency] ?? 0,
            difference = Number.Abs(laborEff - calcEff)
        in
        if difference <= 0.05 then "High Accuracy"
        else if difference <= 0.15 then "Good Accuracy"
        else if difference <= 0.25 then "Fair Accuracy"
        else "Low Accuracy", type text),
    
    // Time lag analysis (work date to invoice date)
    AddTimeLag = Table.AddColumn(AddBillingAccuracy, "WorkToInvoiceDays", each
        if [WorkDate] <> null and [InvoiceDate] <> null then
            Duration.Days([InvoiceDate] - [WorkDate])
        else null, type number),
    
    AddTimeLagCategory = Table.AddColumn(AddTimeLag, "TimeLagCategory", each
        let days = [WorkToInvoiceDays] ?? 0 in
        if days <= 1 then "Same Day"
        else if days <= 7 then "Within Week"
        else if days <= 30 then "Within Month"
        else "Over Month", type text),
    
    // Profitability classification with enhanced logic
    AddProfitabilityClass = Table.AddColumn(AddTimeLagCategory, "ProfitabilityClass", each
        let
            marginPercent = [MarginPercent] ?? 0,
            revenueType = [RevenueType] ?? ""
        in
        if revenueType = "Non-Revenue" then "Non-Revenue"
        else if marginPercent >= 0.5 then "Excellent Profit"
        else if marginPercent >= 0.3 then "Good Profit"
        else if marginPercent >= 0.1 then "Fair Profit"
        else if marginPercent >= 0 then "Low Profit"
        else "Loss", type text),
    
    // Productivity indicator (combining efficiency and quality)
    AddProductivityIndicator = Table.AddColumn(AddProfitabilityClass, "ProductivityIndicator", each
        let
            efficiency = [LaborEfficiency] ?? 0,
            quality = [QualityIndicator] ?? "",
            hasRework = [HasRework] ?? false
        in
        if efficiency >= 1.2 and quality = "High Quality" then "High Productivity"
        else if efficiency >= 1.0 and not hasRework then "Good Productivity"
        else if efficiency >= 0.8 then "Average Productivity"
        else "Below Average", type text),
    
    // Billing complexity assessment
    AddBillingComplexity = Table.AddColumn(AddProductivityIndicator, "BillingComplexity", each
        let
            accountedHours = [TotalAccountedHours] ?? 0,
            hasRework = [HasRework] ?? false,
            hasDelay = [HasDelay] ?? false,
            gainLoss = Number.Abs([GainLossHours] ?? 0)
        in
        if accountedHours > 8 or hasRework or hasDelay or gainLoss > 1 then "Complex"
        else if accountedHours > 4 or gainLoss > 0.5 then "Moderate"
        else "Simple", type text),
    
    // ========================================================================
    // STEP 8: OPERATIONAL FLAGS FOR INVOICE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Add operational flags specific to invoice-level management needs
    BUSINESS LOGIC: Flags for dashboard filtering and billing operational decision making
    BENEFIT: Enhanced filtering and management capability for invoice-level operations
    */
    
    // High performance invoice flag
    AddHighPerformanceFlag = Table.AddColumn(AddBillingComplexity, "IsHighPerformance", each
        [ProductivityIndicator] = "High Productivity" and [BillingAccuracy] = "High Accuracy", type logical),
    
    // Problem invoice identification
    AddProblemInvoiceFlag = Table.AddColumn(AddHighPerformanceFlag, "IsProblemInvoice", each
        [HasRework] or [HasDelay] or [EfficiencyCategory] = "Poor" or [BillingAccuracy] = "Low Accuracy", type logical),
    
    // Same day billing flag (operational efficiency)
    AddSameDayBillingFlag = Table.AddColumn(AddProblemInvoiceFlag, "IsSameDayBilling", each
        [TimeLagCategory] = "Same Day", type logical),
    
    // High value invoice flag
    AddHighValueFlag = Table.AddColumn(AddSameDayBillingFlag, "IsHighValue", each
        [InvoiceValueCategory] = "High Value", type logical),
    
    // Training opportunity flag (efficiency issues with complex billing)
    AddTrainingOpportunityFlag = Table.AddColumn(AddHighValueFlag, "IsTrainingOpportunity", each
        [BillingComplexity] = "Complex" and [ProductivityIndicator] <> "High Productivity", type logical),
    
    // Revenue optimization flag (good efficiency but low margin)
    AddRevenueOptimizationFlag = Table.AddColumn(AddTrainingOpportunityFlag, "IsRevenueOptimization", each
        [EfficiencyCategory] = "Good" and [ProfitabilityClass] = "Low Profit", type logical),
    
    // ========================================================================
    // STEP 9: FINAL COLUMN SELECTION AND OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Select essential columns for optimal performance and comprehensive analysis
    BUSINESS LOGIC: Include all dimensional keys, metrics, and essential business attributes
    BENEFIT: Minimizes memory footprint while maintaining complete analytical capability
    */
    
    FinalColumns = Table.SelectColumns(AddRevenueOptimizationFlag, {
        // ===== DIMENSION KEYS =====
        "TechnicianKey", "BranchKey", "JobCodeKey", "DimWorkOrderKey",
        
        // ===== TIME INTELLIGENCE KEYS (FROM RAW TABLE) =====
        "InvoiceDateKey", "WorkDateKey",
        
        // ===== CORE IDENTIFIERS =====
        "Branch", "WorkOrder", "InvoiceNumber", "TechCode", "SequenceID", "JobCode", "JobType",
        
        // ===== TIME TRACKING (FROM RAW TABLE) =====
        "InvoiceDate", "WorkDate", "StartTime", "EndTime", "PunchDurationHours",
        
        // ===== CORE LABOR HOURS (FROM RAW TABLE) =====
        "HoursPunched", "InvoiceHours", "ReworkHours", "DelayHours", 
        "GainLossHours", "OtherHours", "LostHours", "TotalAccountedHours",
        
        // ===== EFFICIENCY METRICS (FROM RAW TABLE) =====
        "LaborEfficiency", "CalculatedEfficiency", "EfficiencyNumerator", "EfficiencyDenominator",
        
        // ===== FINANCIAL DATA (FROM RAW TABLE) =====
        "LaborCost", "LaborSale", "LaborMargin", "MarginPercent",
        
        // ===== QUALITY & PERFORMANCE (FROM RAW TABLE) =====
        "EfficiencyCategory", "HasRework", "ReworkPercentage", "HasDelay", 
        "GainLossIndicator", "QualityIndicator", "LaborValueCategory",
        
        // ===== REVENUE CLASSIFICATION (FROM RAW TABLE) =====
        "RevenueType", "SpecialPromoIndicator", "NonRevenueIndicator",
        
        // ===== INVOICE-LEVEL ANALYTICS (FACT TABLE ENHANCED) =====
        "InvoiceValueCategory", "BillingAccuracy", "WorkToInvoiceDays", "TimeLagCategory",
        "ProfitabilityClass", "ProductivityIndicator", "BillingComplexity",
        
        // ===== OPERATIONAL FLAGS (FACT TABLE ENHANCED) =====
        "IsHighPerformance", "IsProblemInvoice", "IsSameDayBilling", "IsHighValue",
        "IsTrainingOpportunity", "IsRevenueOptimization",
        
        // ===== DATA QUALITY (FROM RAW TABLE) =====
        "DataQualityScore",
        
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
        {"JobCodeKey", Int64.Type}, {"DimWorkOrderKey", Int64.Type},
        
        // Time intelligence keys
        {"InvoiceDateKey", Int64.Type}, {"WorkDateKey", Int64.Type},
        
        // Identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"InvoiceNumber", type text},
        {"TechCode", type text}, {"SequenceID", Int64.Type}, {"JobCode", type text}, {"JobType", type text},
        
        // Time tracking
        {"InvoiceDate", type datetime}, {"WorkDate", type datetime}, 
        {"StartTime", type datetime}, {"EndTime", type datetime}, {"PunchDurationHours", type number},
        
        // Labor hours
        {"HoursPunched", type number}, {"InvoiceHours", type number}, {"ReworkHours", type number},
        {"DelayHours", type number}, {"GainLossHours", type number}, {"OtherHours", type number}, 
        {"LostHours", type number}, {"TotalAccountedHours", type number},
        
        // Efficiency metrics
        {"LaborEfficiency", type number}, {"CalculatedEfficiency", type number},
        {"EfficiencyNumerator", type number}, {"EfficiencyDenominator", type number},
        
        // Financial data
        {"LaborCost", type number}, {"LaborSale", type number}, 
        {"LaborMargin", type number}, {"MarginPercent", type number},
        
        // Quality and performance
        {"EfficiencyCategory", type text}, {"HasRework", type logical}, {"ReworkPercentage", type number},
        {"HasDelay", type logical}, {"GainLossIndicator", type text}, {"QualityIndicator", type text},
        {"LaborValueCategory", type text},
        
        // Revenue classification
        {"RevenueType", type text}, {"SpecialPromoIndicator", type text}, {"NonRevenueIndicator", type text},
        
        // Invoice-level analytics
        {"InvoiceValueCategory", type text}, {"BillingAccuracy", type text}, 
        {"WorkToInvoiceDays", type number}, {"TimeLagCategory", type text},
        {"ProfitabilityClass", type text}, {"ProductivityIndicator", type text}, {"BillingComplexity", type text},
        
        // Operational flags
        {"IsHighPerformance", type logical}, {"IsProblemInvoice", type logical}, 
        {"IsSameDayBilling", type logical}, {"IsHighValue", type logical},
        {"IsTrainingOpportunity", type logical}, {"IsRevenueOptimization", type logical},
        
        // Data quality and reference
        {"DataQualityScore", type number}, {"WorkOrderKey", type text}
    })

in
    FinalDataTypes

/*
============================================================================
✅ FACT_LABORINVOICED - COMPREHENSIVE BILLING & REVENUE ANALYTICS EXCELLENCE
============================================================================

🎯 CRITICAL BUSINESS CAPABILITIES:
• Complete Billing Efficiency: Invoice hours vs punched hours with accuracy and performance tracking
• Revenue Realization Intelligence: Labor revenue analysis from work completion to invoice generation
• Quality & Performance Management: Rework analysis, delay tracking, and efficiency optimization
• Financial Profitability: Complete margin analysis with profitability classification and optimization
• Cross-Fact Integration: Perfect completion of labor analytics cycle (punch → job → invoice)
• Operational Excellence: Time lag analysis, billing complexity assessment, and process improvement

⚡ PERFORMANCE & ARCHITECTURE EXCELLENCE:
• Target Refresh: 2-3 minutes (optimized by leveraging raw table calculations)
• Memory Efficient: Uses existing calculated fields with minimal additional processing
• CU Optimized: Inherits raw table optimization with focused dimensional relationships
• Incremental Ready: Full incremental refresh capability through raw table design
• Time Intelligence: Uses existing date keys avoiding dimension lookup issues

🔗 DIMENSIONAL INTEGRATION SUCCESS:
• TechnicianKey → Individual technician billing performance and accuracy analysis
• BranchKey → Territory-based billing efficiency and revenue comparison
• JobCodeKey → Service type billing patterns and profitability assessment
• DimWorkOrderKey → CRITICAL cross-fact integration completing labor analytics cycle
• InvoiceDateKey & WorkDateKey → Complete time intelligence for billing cycle analysis

📊 INVOICE-LEVEL BUSINESS INTELLIGENCE:
• Billing Efficiency: Complete efficiency analysis with accuracy validation and performance tracking
• Revenue Analysis: Profitability classification with margin optimization and pricing intelligence
• Quality Management: Rework and delay correlation with billing accuracy and efficiency impact
• Operational Optimization: Time lag analysis and billing complexity assessment for process improvement
• Performance Management: Productivity indicators with training and optimization opportunity identification

🚀 COMPLETE LABOR ANALYTICS CYCLE:
• Punch Integration: Links to Fact_LaborPunches via TechnicianKey and DimWorkOrderKey for complete time analysis
• Job Integration: Links to Fact_LaborJobs via DimWorkOrderKey for complete cost-to-revenue analysis
• Work Order Analysis: Provides invoice-level detail for complete work order profitability and billing efficiency
• Customer Intelligence: Invoice-level performance supporting customer satisfaction and pricing optimization

============================================================================

📈 DASHBOARD IMPLEMENTATION RECOMMENDATIONS:

🎯 EXECUTIVE BILLING PERFORMANCE DASHBOARD:
• KPI Matrix: Total labor revenue, billing efficiency %, same-day billing rate, profit margin
• Revenue Analysis: Labor revenue by customer, equipment type, and service complexity with margin trends
• Performance Trends: Monthly billing efficiency and revenue realization with targets and benchmarks
• Territory Comparison: Branch billing performance with efficiency and revenue optimization opportunities

⚙️ BILLING OPERATIONS DASHBOARD:
• Billing Queue Analytics: Real-time invoice status with efficiency predictions and quality indicators
• Problem Invoice Management: Rework and delay analysis with billing accuracy improvement tracking
• Process Optimization: Time lag analysis from work completion to invoice generation with automation opportunities
• Quality Improvement: Billing accuracy trends with training opportunity identification and best practice sharing

👥 TECHNICIAN BILLING PERFORMANCE DASHBOARD:
• Individual Scorecards: Comprehensive billing efficiency, accuracy, and revenue generation per technician
• Performance Analysis: Billing efficiency vs work efficiency correlation with development opportunity identification
• Revenue Contribution: Individual technician revenue generation with profitability and margin analysis
• Accuracy Tracking: Billing accuracy consistency with training and improvement recommendation systems

🔧 FINANCIAL OPTIMIZATION DASHBOARD:
• Revenue Realization: Complete labor revenue cycle analysis with optimization opportunity identification
• Margin Analysis: Profitability classification with pricing and cost optimization recommendations
• Efficiency Correlation: Billing efficiency vs operational efficiency with process improvement opportunities
• Cross-Fact Profitability: Complete labor cycle profitability from punch to job to invoice for total optimization

============================================================================

🏆 COMPLETE LABOR ANALYTICS INTEGRATION:

📊 WITH FACT_LABORPUNCHES:
• Complete Time Analysis: Punch detail combined with invoice-level billing efficiency and accuracy
• Efficiency Correlation: Individual punch efficiency vs billing efficiency for consistency validation
• Quality Integration: Punch-level quality indicators correlated with billing accuracy and revenue realization

💰 WITH FACT_LABORJOBS:
• Complete Cost-Revenue Cycle: Job-level costs combined with invoice-level revenue for total profitability
• Efficiency Validation: Job efficiency vs billing efficiency correlation for process optimization
• Margin Analysis: Job costs vs invoice revenue for complete labor profitability and pricing optimization

🔧 WITH FACT_WORKORDERHEADER:
• Complete Service Profitability: Invoice-level labor revenue within total work order financial analysis
• Customer Service Excellence: Billing efficiency and accuracy impact on customer satisfaction and retention
• Equipment Service Analysis: Invoice patterns by equipment type supporting service pricing and optimization

============================================================================
*/