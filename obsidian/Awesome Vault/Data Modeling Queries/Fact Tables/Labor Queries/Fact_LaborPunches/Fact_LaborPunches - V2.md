/*
============================================================================
FACT_LABORPUNCHES - OPTIMIZED PUNCH TRACKING LEVERAGING RAW TABLE CALCULATIONS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Individual punch-level labor tracking leveraging comprehensive raw table business logic
Grain: One row per technician punch record (finest grain labor data available)
Refresh Strategy: Incremental refresh ready (WorkDate filtering via raw table)
Current Performance: Target 1-2 minutes refresh time (optimized by leveraging raw calculations)
Source Dependencies: Raw_TechnicianPunchedDetail + 5 dimension tables

🎯 BUSINESS USE CASES:
• Detailed Time Tracking: Individual punch analysis with complete work type hour classification
• Technician Performance: Individual productivity analysis with pre-calculated efficiency metrics
• Work Order Integration: Punch-level detail linked to work orders for complete service analysis
• Operational Analytics: Overtime detection, work complexity assessment, and efficiency categorization
• Quality Management: Time validation, rework identification, and performance consistency tracking
• Revenue Analysis: Customer vs Internal vs Warranty work classification with revenue impact
• Cross-Fact Foundation: Provides detailed labor foundation for aggregation into other labor fact tables

📊 KEY METRICS PROVIDED (PRE-CALCULATED IN RAW TABLE):
• Complete Time Intelligence: Work date, start time, end time, punch duration, hours worked, hours sold
• Work Type Hour Breakdown: 7 distinct work type categories with precise hour allocations
• Efficiency Metrics: Billing efficiency, time utilization, efficiency categorization
• Work Classifications: Primary work type, work type category, revenue classification
• Performance Scoring: Work complexity assessment, data quality scoring
• Operational Intelligence: Customer hours, total classified hours, business classifications

🔗 DIMENSION RELATIONSHIPS:
• dim_Technician_Code_Names → TechnicianKey (technician performance and identity analysis)
• dim_BranchLocation → BranchKey (territory and location-based labor analysis)
• dim_JobCode → JobCodeKey (service type and complexity analysis per punch)
• dim_WorkOrderMaster → WorkOrderKey (CRITICAL: work order context and cross-fact integration)
• dim_DateTable → WorkDateKey (time intelligence and trend analysis)

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Leverages ALL business logic pre-calculated in Raw_TechnicianPunchedDetail
• Minimal calculations needed - focuses on dimension lookups only
• Efficient memory usage by using existing calculated fields
• Sub-2 minute refresh time target achievable
• Optimal for incremental refresh implementation

🔧 MAINTENANCE NOTES:
• Business logic maintenance centralized in Raw_TechnicianPunchedDetail
• Fact table focuses purely on dimensional relationships
• Monitor dimension lookup success rates for data quality
• Validate that raw table calculations match business requirements

============================================================================
*/

let
    // ========================================================================
    // STEP 1: SOURCE DATA WITH PRE-CALCULATED BUSINESS LOGIC
    // ========================================================================
    /*
    PURPOSE: Leverage comprehensive raw table with all business calculations complete
    BUSINESS LOGIC: Raw table already contains work type classifications and efficiency metrics
    BENEFIT: Minimal processing needed, focus on dimensional relationships
    */
    
    Source = Raw_TechnicianPunchedDetail,
    
    // ========================================================================
    // STEP 2: DIMENSION LOOKUP - TECHNICIAN
    // ========================================================================
    /*
    PURPOSE: Link punch records to technician master data
    BUSINESS LOGIC: TechCode → TechnicianCode for technician identity and performance analysis
    BENEFIT: Enables individual technician performance tracking and skill analysis
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
    PURPOSE: Link punch records to branch/territory information
    BUSINESS LOGIC: ROBranch → BranchID for territory-based labor analysis
    BENEFIT: Enables geographic performance analysis and resource allocation
    */
    
    BranchLookup = Table.NestedJoin(
        ExpandTechnician, {"ROBranch"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchDim", JoinKind.LeftOuter),
    
    ExpandBranch = Table.ExpandTableColumn(
        BranchLookup, "BranchDim", 
        {"BranchKey"}, {"BranchDimKey"}),
    
    // ========================================================================
    // STEP 4: DIMENSION LOOKUP - JOB CODE
    // ========================================================================
    /*
    PURPOSE: Link punch records to job type and service classification
    BUSINESS LOGIC: JobCode → JobCode for service type analysis per punch
    BENEFIT: Enables job type specialization and complexity analysis
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
    PURPOSE: Link punch records to work order master data
    BUSINESS LOGIC: WorkOrder → WorkOrder for work order context integration
    BENEFIT: CRITICAL - Enables cross-fact analysis and solves orphaned records issue
    */
    
    WorkOrderLookup = Table.NestedJoin(
        ExpandJobCode, {"WorkOrder"}, 
        dim_WorkOrderMaster, {"WorkOrder"}, 
        "WorkOrderDim", JoinKind.LeftOuter),
    
    ExpandWorkOrder = Table.ExpandTableColumn(
        WorkOrderLookup, "WorkOrderDim", 
        {"BranchWorkOrder"}, {"WorkOrderMasterKey"}),
    
    // ========================================================================
    // STEP 6: DIMENSION LOOKUP - DATE TABLE
    // ========================================================================
    /*
    PURPOSE: Link punch records to date dimension for time intelligence
    BUSINESS LOGIC: WorkDate → Date for comprehensive time analysis
    BENEFIT: Enables trend analysis, seasonality, and time-based performance metrics
    */
    
    DateLookup = Table.NestedJoin(
        ExpandWorkOrder, {"WorkDate"}, 
        dim_DateTable, {"Date"}, 
        "DateDim", JoinKind.LeftOuter),
    
    ExpandDate = Table.ExpandTableColumn(
        DateLookup, "DateDim", 
        {"DateKey"}, {"DateTableKey"}),
    
    // ========================================================================
    // STEP 7: HANDLE MISSING DIMENSION KEYS
    // ========================================================================
    /*
    PURPOSE: Create clean dimension keys for fact table relationships
    BUSINESS LOGIC: Use dimension lookup keys where available, default to -1 for missing relationships
    BENEFIT: Clean fact table keys for optimal Power BI relationships
    NOTE: WorkDateKey already exists from raw table, DimWorkOrderKey distinguishes from raw WorkOrderKey
    */
    
    HandleMissingKeys = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(ExpandDate,
                    "TechnicianKey", each [TechnicianDimKey] ?? -1, Int64.Type),
                "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),
            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),
        "DimWorkOrderKey", each [WorkOrderMasterKey] ?? "UNKNOWN", type text),
    
    // ========================================================================
    // STEP 8: ADD OPERATIONAL FLAGS FOR FACT TABLE ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Add additional operational flags specific to fact table needs
    BUSINESS LOGIC: Flags for dashboard filtering and operational management
    BENEFIT: Enhanced filtering and analysis capabilities
    */
    
    // Overtime identification based on punch duration
    AddOvertimeFlag = Table.AddColumn(HandleMissingKeys, "IsOvertime", each
        ([PunchDurationHours] ?? 0) > 8, type logical),
    
    // Mixed work detection based on work type complexity
    AddMixedWorkFlag = Table.AddColumn(AddOvertimeFlag, "IsMixedWork", each
        [WorkComplexity] = "Complex" or [WorkTypeCategory] = "Mixed Work", type logical),
    
    // High efficiency flag for performance tracking
    AddHighEfficiencyFlag = Table.AddColumn(AddMixedWorkFlag, "IsHighEfficiency", each
        [EfficiencyCategory] = "Excellent", type logical),
    
    // Revenue generating work flag
    AddRevenueFlag = Table.AddColumn(AddHighEfficiencyFlag, "IsRevenueGenerating", each
        [RevenueClassification] = "Revenue Generating", type logical),
    
    // Time validation flag (comparing worked hours to punch duration)
    AddTimeValidFlag = Table.AddColumn(AddRevenueFlag, "IsTimeValid", each
        let
            punchHours = [PunchDurationHours] ?? 0,
            workedHours = [HoursWorked] ?? 0
        in
        if punchHours > 0 and workedHours > 0 then
            workedHours <= (punchHours * 1.1) and workedHours >= (punchHours * 0.5)
        else if workedHours > 0 then true
        else false, type logical),
    
    // ========================================================================
    // STEP 9: FINAL COLUMN SELECTION AND OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Select essential columns for optimal performance and memory usage
    BUSINESS LOGIC: Include all dimensional keys, existing metrics, and essential attributes
    BENEFIT: Minimizes memory footprint while maintaining comprehensive analytical capability
    */
    
    FinalColumns = Table.SelectColumns(AddTimeValidFlag, {
        // ===== DIMENSION KEYS =====
        "TechnicianKey", "BranchKey", "JobCodeKey", "DimWorkOrderKey",
        
        // ===== TIME INTELLIGENCE KEY (FROM RAW TABLE) =====
        "WorkDateKey",
        
        // ===== CORE IDENTIFIERS =====
        "Branch", "WorkOrder", "TechCode", "SequenceID", "JobCode", "JobType", "ROBranch",
        
        // ===== TIME TRACKING (FROM RAW TABLE) =====
        "WorkDate", "StartTime", "EndTime", "PunchDurationHours",
        
        // ===== CORE LABOR HOURS (FROM RAW TABLE) =====
        "HoursWorked", "HoursSold",
        
        // ===== WORK ORDER TYPE HOUR BREAKDOWNS (CRITICAL - FROM RAW TABLE) =====
        "HoursInternal", "HoursWarranty", "HoursRetail", "HoursSundry", 
        "HoursFleet", "HoursAgreement", "HoursOther",
        
        // ===== CALCULATED HOURS (FROM RAW TABLE) =====
        "TotalClassifiedHours", "CustomerHours",
        
        // ===== PERFORMANCE METRICS (FROM RAW TABLE) =====
        "BillingEfficiency", "TimeUtilization",
        
        // ===== BUSINESS CLASSIFICATIONS (FROM RAW TABLE) =====
        "PrimaryWorkType", "WorkTypeCategory", "RevenueClassification",
        "EfficiencyCategory", "WorkComplexity",
        
        // ===== OPERATIONAL FLAGS (COMBINATION OF RAW AND FACT TABLE) =====
        "IsOvertime", "IsMixedWork", "IsHighEfficiency", "IsRevenueGenerating", "IsTimeValid",
        
        // ===== CONTEXT INFORMATION =====
        "CustomerName", "EquipmentModel",
        
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
    BUSINESS LOGIC: Appropriate data types maintained from raw table
    BENEFIT: Optimal query performance and minimal memory footprint
    */
    
    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {
        // Dimension keys
        {"TechnicianKey", Int64.Type}, {"BranchKey", Int64.Type}, 
        {"JobCodeKey", Int64.Type}, {"DimWorkOrderKey", type text},
        
        // Time intelligence key
        {"WorkDateKey", Int64.Type},
        
        // Identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"TechCode", type text}, 
        {"SequenceID", Int64.Type}, {"JobCode", type text}, {"JobType", type text}, {"ROBranch", type text},
        
        // Time tracking
        {"WorkDate", type datetime}, {"StartTime", type datetime}, {"EndTime", type datetime},
        {"PunchDurationHours", type number},
        
        // Core hours
        {"HoursWorked", type number}, {"HoursSold", type number},
        
        // Work type hours
        {"HoursInternal", type number}, {"HoursWarranty", type number}, {"HoursRetail", type number},
        {"HoursSundry", type number}, {"HoursFleet", type number}, {"HoursAgreement", type number}, 
        {"HoursOther", type number},
        
        // Calculated hours
        {"TotalClassifiedHours", type number}, {"CustomerHours", type number},
        
        // Performance metrics
        {"BillingEfficiency", type number}, {"TimeUtilization", type number},
        
        // Classifications
        {"PrimaryWorkType", type text}, {"WorkTypeCategory", type text}, 
        {"RevenueClassification", type text}, {"EfficiencyCategory", type text}, {"WorkComplexity", type text},
        
        // Flags
        {"IsOvertime", type logical}, {"IsMixedWork", type logical}, {"IsHighEfficiency", type logical},
        {"IsRevenueGenerating", type logical}, {"IsTimeValid", type logical},
        
        // Context
        {"CustomerName", type text}, {"EquipmentModel", type text},
        
        // Quality and reference
        {"DataQualityScore", type number}, {"WorkOrderKey", type text}
    })

in
    FinalDataTypes

/*
============================================================================
✅ FACT_LABORPUNCHES - OPTIMIZED LEVERAGING RAW TABLE EXCELLENCE
============================================================================

🎯 ARCHITECTURAL EXCELLENCE:
• Leverages ALL pre-calculated business logic from Raw_TechnicianPunchedDetail
• Focuses purely on dimensional relationships and fact table optimization
• Minimal processing overhead - maximum performance efficiency
• Maintains complete analytical capability with optimized refresh performance

⚡ PERFORMANCE BENEFITS:
• Target Refresh: 1-2 minutes (reduced from 2-3 minutes by leveraging raw calculations)
• Memory Efficient: Uses existing calculated fields, minimal additional processing
• CU Optimized: Leverages raw table investment, minimal computational overhead
• Incremental Ready: Inherits incremental refresh capability from raw table

🔗 DIMENSIONAL INTEGRATION SUCCESS:
• TechnicianKey → Individual technician performance and skill analysis
• BranchKey → Territory-based labor analysis and resource allocation  
• JobCodeKey → Service type analysis and complexity assessment
• WorkOrderKey → CRITICAL cross-fact integration solving orphaned records
• WorkDateKey → Complete time intelligence and trend analysis

📊 BUSINESS VALUE PRESERVED AND ENHANCED:
• Complete Work Type Analysis: All 7 work type hour classifications preserved
• Efficiency Metrics: Billing efficiency, time utilization, performance categorization
• Quality Intelligence: Data quality scoring and time validation
• Operational Flags: Overtime, mixed work, high efficiency, revenue generation
• Cross-Fact Foundation: Perfect foundation for other labor fact tables

🚀 CROSS-FACT ANALYSIS ENABLEMENT:
• Work Order Integration: Enables analysis across work orders, labor, parts, and financial data
• Customer Analysis: Links punch detail to customer performance across all fact tables
• Equipment Analysis: Equipment-based labor analysis supporting maintenance and reliability
• Territory Management: Branch-based performance analysis across all business dimensions

============================================================================

📈 DASHBOARD IMPLEMENTATION RECOMMENDATIONS:

🎯 EXECUTIVE LABOR INTELLIGENCE:
• KPI Matrix: Total hours by work type with efficiency and revenue impact
• Performance Trends: Daily/weekly labor productivity with quality indicators
• Territory Analysis: Branch labor performance with complexity and efficiency metrics
• Revenue Analytics: Customer vs Internal vs Warranty work distribution and profitability

⚙️ OPERATIONAL MANAGEMENT:
• Real-time Punch Monitoring: Current punch status with quality validation alerts
• Technician Performance: Individual efficiency, utilization, and specialization tracking
• Work Type Optimization: Customer vs Internal vs Warranty work pattern analysis
• Quality Management: Time validation monitoring and data quality trending

👥 TECHNICIAN DEVELOPMENT:
• Individual Scorecards: Comprehensive performance metrics per technician
• Skill Specialization: Work type expertise and development opportunity identification
• Efficiency Coaching: Punch-level efficiency analysis with improvement recommendations
• Performance Benchmarking: Peer comparison and best practice identification

🔧 CROSS-FACT ANALYTICS:
• Complete Service Analysis: Punch detail combined with work order profitability
• Customer Service Excellence: Labor quality impact on customer satisfaction
• Equipment Reliability: Labor patterns supporting predictive maintenance
• Financial Optimization: Labor cost analysis supporting pricing and margin improvement

============================================================================
*/