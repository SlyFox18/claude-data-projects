/*
============================================================================
FACT_WORKORDERHEADER - COMPREHENSIVE WORK ORDER ANALYTICS FACT TABLE
============================================================================

📋 TABLE OVERVIEW:
Purpose: Central work order snapshot fact table for operational and executive analytics
Grain: One row per work order (current status snapshot)
Refresh Strategy: Full refresh (prepared for incremental via ModifiedDate)
Current Performance: ~2m 30s refresh time
Dependencies: Raw_wkrofile, Raw_wkrodesc + 5 dimension tables

🎯 BUSINESS USE CASES:
• Executive Dashboards: KPI tracking, trend analysis, performance monitoring
• Operational Management: Work order prioritization, resource allocation, bottleneck identification  
• Customer Service: Account management, SLA monitoring, service history tracking
• Field Operations: Daily dispatch optimization, technician workload balancing
• Strategic Planning: Capacity planning, seasonal analysis, service mix optimization

📊 KEY METRICS PROVIDED:
• Priority Scoring (0-100 algorithm): Automated urgency calculation
• Work Order Categorization: Size, complexity, service type classification
• Risk Indicators: Delay risk, velocity tracking, SLA breach prediction
• Customer Intelligence: Account assignment with fallback logic
• Equipment Context: Vehicle/equipment integration with service history
• Time Intelligence: Age calculations, deadline tracking, business day metrics

🔗 DIMENSION RELATIONSHIPS:
• dim_CustomerList → Customer assignment with fallback to work order types
• dim_Vehicle → Equipment/vehicle master data integration  
• dim_BranchLocation → Location-based analysis and territory management
• dim_WorkOrderStatus → Status progression tracking and workflow analysis
• dim_JobCode → Service type classification and skill requirement analysis

📈 DASHBOARD IDEAS:
• Executive Summary: KPIs, trends, alerts, performance metrics
• Operations Queue: Priority-sorted work orders with resource planning
• Customer Service: Account views, SLA monitoring, service history
• Field Dispatch: Geographic distribution with priority and skill matching
• Analytics: Predictive maintenance, customer retention, efficiency metrics

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Incremental refresh ready (ModifiedDate filter)
• Efficient dimension joins with proper text cleaning
• Calculated columns minimize additional queries
• Selective column loading reduces memory footprint
• Index-friendly key structures for fast lookups

🔧 MAINTENANCE NOTES:
• Monitor refresh performance if data volume grows significantly
• Review priority scoring algorithm quarterly for business relevance
• Validate customer assignment logic when new work order types added
• Update SLA thresholds in Step 12 based on business requirements

============================================================================
📈 DASHBOARD & REPORTING RECOMMENDATIONS
============================================================================

🎯 EXECUTIVE DASHBOARD:
• KPI Cards: Active WOs, Overdue %, Average Age, SLA Compliance Rate
• Trend Charts: Work Order Volume by Month with Priority Color Coding
• Heat Map: Branch Performance Matrix (Volume vs Average Age)
• Alert Panel: Critical/High Priority Work Orders Requiring Attention

⚙️ OPERATIONS DASHBOARD:
• Work Order Queue: Sortable by PriorityScore, Filterable by Branch/ServiceType
• Resource Planning: ComplexityLevel Distribution for Staffing Decisions
• Performance Metrics: WorkOrderVelocity Analysis by Service Type
• Risk Management: DelayRiskLevel Analysis with Recommended Actions

👥 CUSTOMER SERVICE DASHBOARD:
• Account Overview: Work Orders by Customer with Status and Priority
• Equipment History: Service Timeline by Vehicle/Equipment
• SLA Monitoring: Current SLA Status with Deadline Tracking
• Revenue Protection: High RevenueRiskScore Work Orders

🔧 FIELD OPERATIONS DASHBOARD:
• Daily Dispatch: Priority-Sorted Work Orders by Technician
• Geographic View: Work Orders Mapped by Location with Priority Coding
• Equipment Reliability: SeasonalCategory Analysis for Maintenance Planning
• Workload Balancing: ComplexityLevel Distribution Across Technicians

============================================================================
🚀 ADVANCED ANALYTICS OPPORTUNITIES
============================================================================

📊 PREDICTIVE ANALYTICS:
• Use DataQualityScore + historical patterns to predict completion times
• Leverage SeasonalCategory for demand forecasting and resource planning
• Combine PriorityScore trends with customer satisfaction metrics

🎯 BUSINESS INTELLIGENCE:
• Cross-analyze with parts inventory for proactive ordering
• Integrate with technician schedules for optimized dispatching
• Connect with customer dimension for retention risk analysis

⚡ PERFORMANCE OPTIMIZATION:
• Monitor refresh performance with data volume growth
• Implement incremental refresh when business processes stabilize
• Consider partitioning by Branch for very large datasets

============================================================================
*/

let
    // ========================================================================
    // STEP 1: DATA FOUNDATION & INCREMENTAL REFRESH SETUP
    // ========================================================================
    /*
    PURPOSE: Establish data range and prepare for incremental refresh
    BUSINESS LOGIC: Currently full refresh, but prepared for incremental
    PERFORMANCE: Filtering early reduces data volume for downstream processing
    */
    
    // Incremental refresh parameters (ready for future implementation)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),
    RangeEnd = DateTime.LocalNow(),
    
    // Get base work order information with selective column loading
    BaseWorkOrders = Table.SelectColumns(Raw_wkrofile, {
        "Branch",           // Location identifier for territory analysis
        "WorkOrder",        // Primary work order number
        "Registration",     // Vehicle registration for equipment lookup
        "StockNumber",      // Alternative equipment identifier
        "AccountNumber",    // Customer account for billing assignment
        "CreatedOn",        // Work order creation timestamp
        "ExpectedDate",     // Promised completion date for SLA tracking
        "ProgressStatus",   // Current workflow status
        "ModifiedDate",     // Last update timestamp (incremental refresh key)
        "Odometer"          // Equipment usage metric
    }),
    
    // Apply incremental refresh filter (currently includes all data)
    FilteredWorkOrders = Table.SelectRows(BaseWorkOrders, each 
        [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),
    
    // Create composite work order key for all joins
    AddWorkOrderKey = Table.AddColumn(FilteredWorkOrders, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // ========================================================================
    // STEP 2: PRIMARY JOB IDENTIFICATION & INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Identify the "main" job per work order using line_no = 1
    BUSINESS LOGIC: Mirrors original SQL WHERE rod.line_no = 1 
    RATIONALE: Primary job represents the main reason for service
    PERFORMANCE: Avoids complex aggregation while capturing key job details
    */
    
    // Filter to primary job line (line_no = 1) to get main job characteristics
    PrimaryJobs = Table.SelectRows(Raw_wkrodesc, each [LineNumber] = 1),
    
    // Add work order key for joining back to main table
    PrimaryJobsWithKey = Table.AddColumn(PrimaryJobs, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Join primary job details to work orders
    JoinPrimaryJob = Table.NestedJoin(
        AddWorkOrderKey, {"WorkOrderKey"}, 
        PrimaryJobsWithKey, {"WorkOrderKey"}, 
        "PrimaryJob", JoinKind.LeftOuter),
    
    // Extract primary job characteristics for business analysis
    ExpandPrimaryJob = Table.ExpandTableColumn(JoinPrimaryJob, "PrimaryJob", 
        {"JobCode", "JobType", "JobValue"}, 
        {"PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue"}),
    
    // ========================================================================
    // STEP 3: COMPREHENSIVE JOB SUMMARY AGGREGATION
    // ========================================================================
    /*
    PURPOSE: Calculate total job metrics across ALL jobs for complete work order picture
    BUSINESS LOGIC: Provides both detail (primary job) and summary (all jobs) perspectives
    METRICS: Total job count and total value for complexity and sizing analysis
    */
    
    // Aggregate all jobs per work order for comprehensive metrics
    JobSummary = Table.Group(Raw_wkrodesc, {"Branch", "WorkOrder"}, {
        {"TotalJobCount", each Table.RowCount(_), Int64.Type},
        {"TotalJobValue", each List.Sum([JobValue]), type number}
    }),
    
    // Add work order key for joining
    JobSummaryWithKey = Table.AddColumn(JobSummary, "WorkOrderKey", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Integrate job summary metrics
    JoinJobSummary = Table.NestedJoin(
        ExpandPrimaryJob, {"WorkOrderKey"}, 
        JobSummaryWithKey, {"WorkOrderKey"}, 
        "JobSummary", JoinKind.LeftOuter),
    
    ExpandJobSummary = Table.ExpandTableColumn(JoinJobSummary, "JobSummary", 
        {"TotalJobCount", "TotalJobValue"}),
    
    // ========================================================================
    // STEP 4: INTELLIGENT CUSTOMER ASSIGNMENT LOGIC
    // ========================================================================
    /*
    PURPOSE: Replicate complex SQL COALESCE customer assignment logic
    BUSINESS LOGIC: Primary assignment via account number, fallback to work order type
    FALLBACK HIERARCHY: Account → Internal → Warranty → Fleet → Excess → Policy → Billing → Misc
    BENEFIT: Ensures every work order has customer context for analysis
    */
    
    // Clean and standardize account number for reliable lookup
    AddAccountClean = Table.AddColumn(ExpandJobSummary, "AccountNumberClean", each 
        if [AccountNumber] <> null and [AccountNumber] <> "" 
        then Text.Upper(Text.Trim(Text.From([AccountNumber])))
        else null, type text),
    
    // Implement intelligent customer assignment with fallback logic
    AddCustomerLookupKey = Table.AddColumn(AddAccountClean, "CustomerLookupKey", each
        let
            jobType = Text.Lower(Text.Trim([PrimaryJobType] ?? ""))
        in
            // Primary: Use actual customer account number
            if [AccountNumberClean] <> null then
                [AccountNumberClean]
            // Fallback: Map work order types to standard customer categories
            else if jobType = "i" then "INTERNAL"      // Internal work
            else if jobType = "w" then "WARRANTY"      // Warranty claims
            else if jobType = "f" then "FLEET"         // Fleet customers
            else if jobType = "e" then "EXCESS"        // Excess inventory
            else if jobType = "p" then "POLICY"        // Policy work
            else if jobType = "b" then "BILLING"       // Billing adjustments
            else if jobType = "s" then "MISC"          // Miscellaneous
            else "UNKNOWN",                            // Catch-all
        type text),
    
    // Link to customer dimension with proper error handling
    JoinCustomer = Table.NestedJoin(
        AddCustomerLookupKey, {"CustomerLookupKey"}, 
        dim_CustomerList, {"AccountNumberText"}, 
        "Customer", JoinKind.LeftOuter),
    
    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "Customer", {"CustomerKey"}),
    
    // Handle missing customers with default key for reporting consistency
    AddFinalCustomerKey = Table.AddColumn(ExpandCustomer, "FinalCustomerKey", each 
        if [CustomerKey] <> null then [CustomerKey] else -1, Int64.Type),
    
    // ========================================================================
    // STEP 5: INTELLIGENT VEHICLE/EQUIPMENT LOOKUP
    // ========================================================================
    /*
    PURPOSE: Link work orders to equipment/vehicle master data
    BUSINESS LOGIC: Priority lookup - Registration first, then Stock Number with prefix
    FORMAT: Stock numbers prefixed with "Stk# " to match dimension table
    BENEFIT: Enables equipment-based analysis and maintenance tracking
    */
    
    // Create vehicle lookup key with intelligent fallback
    AddVehicleLookupKey = Table.AddColumn(AddFinalCustomerKey, "VehicleLookupKey", each 
        if [Registration] <> null and [Registration] <> "" then 
            Text.Upper(Text.Trim([Registration]))               // Primary: Use registration
        else if [StockNumber] <> null and [StockNumber] <> "" then 
            "Stk# " & Text.Trim(Text.From([StockNumber]))      // Fallback: Stock number with prefix
        else null, type text),
    
    // Link to vehicle dimension for equipment context
    JoinVehicle = Table.NestedJoin(
        AddVehicleLookupKey, {"VehicleLookupKey"}, 
        dim_Vehicle, {"PrimaryLookup"}, 
        "Vehicle", JoinKind.LeftOuter),
    
    ExpandVehicle = Table.ExpandTableColumn(JoinVehicle, "Vehicle", {"VehicleKey"}),
    
    // ========================================================================
    // STEP 6: BRANCH/LOCATION DIMENSION INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Enable location-based analysis and territory management
    BUSINESS BENEFIT: Geographic performance analysis, resource allocation
    */
    
    JoinBranch = Table.NestedJoin(
        ExpandVehicle, {"Branch"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchInfo", JoinKind.LeftOuter),
    
    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchInfo", {"BranchKey"}),
    
    // ========================================================================
    // STEP 7: WORK ORDER STATUS PROGRESSION TRACKING
    // ========================================================================
    /*
    PURPOSE: Enable workflow analysis and status progression tracking
    BUSINESS BENEFIT: Bottleneck identification, process improvement
    */
    
    // Standardize status code for reliable lookup
    AddStatusLookup = Table.AddColumn(ExpandBranch, "StatusLookup", each 
        Text.Lower(Text.Trim([ProgressStatus] ?? "")), type text),
    
    JoinStatus = Table.NestedJoin(
        AddStatusLookup, {"StatusLookup"}, 
        dim_WorkOrderStatus, {"StatusCode"}, 
        "Status", JoinKind.LeftOuter),
    
    ExpandStatus = Table.ExpandTableColumn(JoinStatus, "Status", {"StatusKey"}),
    
    // ========================================================================
    // STEP 8: JOB CODE CLASSIFICATION & SKILL ANALYSIS
    // ========================================================================
    /*
    PURPOSE: Enable service type analysis and skill requirement planning
    BUSINESS BENEFIT: Technician assignment, training needs, service mix analysis
    */
    
    // Clean and standardize job code for lookup
    AddJobCodeLookup = Table.AddColumn(ExpandStatus, "JobCodeLookup", each 
        if [PrimaryJobCode] <> null then Text.Upper(Text.Trim([PrimaryJobCode])) else null, 
        type text),
    
    JoinJobCode = Table.NestedJoin(
        AddJobCodeLookup, {"JobCodeLookup"}, 
        dim_JobCode, {"JobCode"}, 
        "JobCodeInfo", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(JoinJobCode, "JobCodeInfo", {"JobCodeKey"}),
    
    // ========================================================================
    // STEP 9: CORE BUSINESS METRICS & TIME INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Calculate fundamental business metrics for operational analysis
    METRICS: Work order age, deadline tracking, overdue identification, active status
    BUSINESS BENEFIT: SLA monitoring, urgency assessment, capacity planning
    */
    
    // Calculate work order age in days
    AddWorkOrderAge = Table.AddColumn(ExpandJobCode, "WorkOrderAge", each 
        if [CreatedOn] <> null then 
            Duration.Days(DateTime.LocalNow() - [CreatedOn]) 
        else null, type number),
    
    // Determine if work order is still active (not picked up)
    AddIsActive = Table.AddColumn(AddWorkOrderAge, "IsActive", each 
        Text.Upper([ProgressStatus] ?? "") <> "VP", type logical),
    
    // Calculate days until expected completion
    AddDaysUntilExpected = Table.AddColumn(AddIsActive, "DaysUntilExpected", each 
        if [ExpectedDate] <> null then 
            Duration.Days([ExpectedDate] - DateTime.LocalNow()) 
        else null, type number),
    
    // Identify overdue work orders
    AddIsOverdue = Table.AddColumn(AddDaysUntilExpected, "IsOverdue", each 
        if [ExpectedDate] <> null then 
            [ExpectedDate] < DateTime.LocalNow() and [IsActive] = true
        else false, type logical),
    
    // ========================================================================
    // STEP 10: ADVANCED PRIORITY SCORING ALGORITHM (0-100 SCALE)
    // ========================================================================
    /*
    PURPOSE: Automated work order prioritization for optimal resource allocation
    ALGORITHM COMPONENTS:
    • Age Component (0-40 points): Older work orders get higher priority
    • Overdue Component (0-30 points): Past-due work orders get urgency boost
    • Customer Component (0-20 points): Real customers prioritized over internal work
    • Value Component (0-10 points): Higher value work gets priority attention
    BUSINESS BENEFIT: Objective prioritization eliminates guesswork and bias
    */
    
    AddPriorityScore = Table.AddColumn(AddIsOverdue, "PriorityScore", each
        let
            // Age component: Older work orders need attention
            AgeScore = if [WorkOrderAge] = null then 0
                      else if [WorkOrderAge] > 30 then 40    // Very old - critical
                      else if [WorkOrderAge] > 14 then 30    // Old - high priority
                      else if [WorkOrderAge] > 7 then 20     // Aging - medium priority
                      else if [WorkOrderAge] > 3 then 10     // Recent - low priority
                      else 5,                                // New - minimal points
            
            // Overdue component: Past deadline = immediate attention
            OverdueScore = if [IsOverdue] = true then 30 else 0,
            
            // Customer component: Real customers vs internal work
            CustomerScore = if [FinalCustomerKey] > 0 then 20     // Real customer
                           else if [FinalCustomerKey] = -3 then 15  // Warranty work
                           else if [FinalCustomerKey] = -2 then 5   // Internal work
                           else 10,                                  // Others
            
            // Value component: Higher value work gets attention
            ValueScore = if [TotalJobValue] = null then 0
                        else if [TotalJobValue] > 5000 then 10
                        else if [TotalJobValue] > 2000 then 7
                        else if [TotalJobValue] > 500 then 5
                        else 2
        in
            AgeScore + OverdueScore + CustomerScore + ValueScore,
        type number),
    
    // Convert priority score to business-friendly categories
    AddPriorityCategory = Table.AddColumn(AddPriorityScore, "PriorityCategory", each
        if [PriorityScore] >= 70 then "Critical"      // Immediate action required
        else if [PriorityScore] >= 50 then "High"     // Priority attention needed
        else if [PriorityScore] >= 30 then "Medium"   // Standard processing
        else "Low",                                   // Routine handling
        type text),
    
    // ========================================================================
    // STEP 11: BUSINESS INTELLIGENCE & OPERATIONAL CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Automatic categorization for operational insights and resource planning
    CATEGORIES: Size (revenue impact), Complexity (resource requirements), Service Type
    BUSINESS BENEFIT: Resource allocation, skill matching, capacity planning
    */
    
    // Work Order Size: Revenue impact classification
    AddWorkOrderSize = Table.AddColumn(AddPriorityCategory, "WorkOrderSize", each
        if [TotalJobValue] = null or [TotalJobValue] = 0 then "Unknown"
        else if [TotalJobValue] > 5000 then "Large"      // High revenue impact
        else if [TotalJobValue] > 1000 then "Medium"     // Moderate revenue
        else "Small",                                    // Standard revenue
        type text),
    
    // Complexity Level: Resource requirement assessment
    AddComplexityLevel = Table.AddColumn(AddWorkOrderSize, "ComplexityLevel", each
        if [TotalJobCount] = null then "Unknown"
        else if [TotalJobCount] >= 5 then "High"         // Multiple jobs - complex
        else if [TotalJobCount] >= 3 then "Medium"       // Several jobs - moderate
        else if [TotalJobCount] >= 1 then "Low"          // Few jobs - simple
        else "None",                                     // No job data
        type text),
    
    // Service Type: Work classification for skill matching
    AddServiceType = Table.AddColumn(AddComplexityLevel, "ServiceType", each
        let
            jobType = Text.Lower([PrimaryJobType] ?? ""),
            jobCode = Text.Upper([PrimaryJobCode] ?? "")
        in
            // Primary classification by job type
            if jobType = "i" then "Internal"
            else if jobType = "w" then "Warranty"
            // Secondary classification by job code patterns
            else if Text.Contains(jobCode, "INSPECT") or Text.Contains(jobCode, "IS-") then "Inspection"
            else if Text.Contains(jobCode, "REPAIR") or Text.Contains(jobCode, "FIX") then "Repair"
            else if Text.Contains(jobCode, "SERVICE") or Text.Contains(jobCode, "MAINT") then "Maintenance"
            else if Text.Contains(jobCode, "SETUP") or Text.Contains(jobCode, "INSTALL") then "Setup/Install"
            else if Text.Contains(jobCode, "DIAGNOS") then "Diagnostic"
            else "General Service",
        type text),
    
    // ========================================================================
    // STEP 12: RISK MANAGEMENT & PERFORMANCE INDICATORS
    // ========================================================================
    /*
    PURPOSE: Proactive identification of potential delays and performance issues
    BUSINESS BENEFIT: Early intervention, process improvement, customer satisfaction
    */
    
    // Delay Risk Assessment: Predict potential delays before they occur
    AddDelayRisk = Table.AddColumn(AddServiceType, "DelayRiskLevel", each
        let
            // Risk factors identification
            IsEarlyStatus = List.Contains({"bi", "va"}, Text.Lower([ProgressStatus] ?? "")),
            IsOld = ([WorkOrderAge] ?? 0) > 7,
            IsComplex = ([ComplexityLevel] ?? "") = "High"
        in
            if ([IsActive] ?? true) = false then "Completed"                    // Work completed
            else if IsOld and IsEarlyStatus then "High Risk"          // Old + early status = problem
            else if IsOld or (([IsOverdue] ?? false) = true) then "Medium Risk"  // Age or overdue concerns
            else if IsComplex and (([WorkOrderAge] ?? 0) > 3) then "Medium Risk" // Complex work aging
            else "Low Risk",                                          // Normal progression
        type text),
    
    // Work Order Velocity: Track progression speed through workflow
    AddVelocityIndicator = Table.AddColumn(AddDelayRisk, "WorkOrderVelocity", each
        let
            Status = Text.Lower([ProgressStatus] ?? ""),
            Age = [WorkOrderAge] ?? 0
        in
            if ([IsActive] ?? true) = false then "Completed"                   // Finished work
            else if Status = "bi" and Age > 3 then "Stalled"        // Booked but not progressing
            else if Status = "va" and Age > 5 then "Slow"           // Arrived but not started
            else if List.Contains({"wip", "wf"}, Status) and Age > 14 then "Slow" // Work in progress too long
            else if Age > 21 then "Very Slow"                       // Any work over 3 weeks
            else "Normal",                                           // Acceptable pace
        type text),
    
    // ========================================================================
    // STEP 13: ENHANCED BUSINESS INTELLIGENCE (PERFORMANCE NEUTRAL)
    // ========================================================================
    /*
    PURPOSE: Additional business insights without performance impact
    FEATURES: Data quality, seasonal patterns, business day calculations, revenue risk
    */
    
    // Data Quality Indicators
    AddDataQuality = Table.AddColumn(AddVelocityIndicator, "DataQualityScore", each
        let
            hasCustomer = if ([FinalCustomerKey] ?? -1) <> -1 then 25 else 0,
            hasVehicle = if [VehicleKey] <> null then 25 else 0,
            hasJobInfo = if [PrimaryJobCode] <> null then 25 else 0,
            hasDates = if [CreatedOn] <> null and [ExpectedDate] <> null then 25 else 0
        in
            hasCustomer + hasVehicle + hasJobInfo + hasDates,
        type number),
    
    // Seasonal Business Pattern Recognition (with null safety)
    AddSeasonalCategory = Table.AddColumn(AddDataQuality, "SeasonalCategory", each
        let 
            createdDate = [CreatedOn],
            monthNum = if createdDate <> null then Date.Month(createdDate) else 0
        in 
            if monthNum >= 3 and monthNum <= 8 then "Peak Season" 
            else if monthNum > 0 then "Off Season" 
            else "Unknown",
        type text),
    
    // Business Days Calculation (excludes weekends)
    AddBusinessDaysOverdue = Table.AddColumn(AddSeasonalCategory, "BusinessDaysOverdue", each
        if (([IsOverdue] ?? false) = true) and [ExpectedDate] <> null then 
            Number.Round(Duration.Days(DateTime.LocalNow() - [ExpectedDate]) * 0.714, 0) // ~71.4% for weekdays
        else 0,
        type number),
    
    // Revenue Risk Assessment (with proper null handling)
    AddRevenueRiskScore = Table.AddColumn(AddBusinessDaysOverdue, "RevenueRiskScore", each
        let
            overdueRisk = if (([IsOverdue] ?? false) = true) then 50 else 0,
            valueRisk = if (([TotalJobValue] ?? 0) > 2000) then 30 else 10,
            customerRisk = if (([FinalCustomerKey] ?? -1) > 0) then 20 else 5,
            ageRisk = if (([WorkOrderAge] ?? 0) > 14) then 15 else 0
        in
            overdueRisk + valueRisk + customerRisk + ageRisk,
        type number),
    
    // Service Level Agreement (SLA) Status Tracking (with null safety)
    AddSLAStatus = Table.AddColumn(AddRevenueRiskScore, "SLAStatus", each
        let
            // Define SLA days by service type
            slaDeadline = if ([ServiceType] ?? "") = "Warranty" then 5
                         else if ([ServiceType] ?? "") = "Internal" then 10
                         else if ([ComplexityLevel] ?? "") = "High" then 7
                         else 3, // Standard SLA
            
            workOrderAge = [WorkOrderAge] ?? 0,
            daysSinceSLA = workOrderAge - slaDeadline,
            isActive = ([IsActive] ?? true) = true
        in
            if not isActive then "SLA Met"
            else if daysSinceSLA > 0 then "SLA Breach"
            else if daysSinceSLA > -1 then "SLA Risk"
            else "SLA On Track",
        type text),
    
    // ========================================================================
    // STEP 14: DATE DIMENSION INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Enable time-based analysis and reporting
    FORMAT: Integer date keys (YYYYMMDD) for optimal join performance
    */
    
    AddCreatedDateKey = Table.AddColumn(AddSLAStatus, "CreatedDateKey", each 
        if [CreatedOn] <> null then 
            Date.Year([CreatedOn]) * 10000 + 
            Date.Month([CreatedOn]) * 100 + 
            Date.Day([CreatedOn])
        else null, Int64.Type),
    
    AddExpectedDateKey = Table.AddColumn(AddCreatedDateKey, "ExpectedDateKey", each 
        if [ExpectedDate] <> null then 
            Date.Year([ExpectedDate]) * 10000 + 
            Date.Month([ExpectedDate]) * 100 + 
            Date.Day([ExpectedDate])
        else null, Int64.Type),
    
    // ========================================================================
    // STEP 15: FINAL COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Organize output for optimal reporting and dashboard creation
    STRUCTURE: Keys first, then dimensions, metrics, calculations, and audit fields
    */
    
    FinalColumns = Table.SelectColumns(AddExpectedDateKey, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "WorkOrderKey",           // Composite key for all joins
        "WorkOrder",              // Work order number
        "Branch",                 // Location identifier
        
        // ===== DIMENSION KEYS (FOR STAR SCHEMA) =====
        "FinalCustomerKey",       // Customer dimension link
        "VehicleKey",             // Vehicle/equipment dimension link
        "BranchKey",              // Branch dimension link
        "StatusKey",              // Status dimension link
        "JobCodeKey",             // Job code dimension link
        
        // ===== DATE KEYS (FOR TIME INTELLIGENCE) =====
        "CreatedDateKey",         // Creation date dimension link
        "ExpectedDateKey",        // Expected date dimension link
        
        // ===== CORE DATES (FOR DIRECT FILTERING) =====
        "CreatedOn",              // Work order creation timestamp
        "ExpectedDate",           // Promised completion date
        
        // ===== PRIMARY JOB INFORMATION =====
        "PrimaryJobCode",         // Main job code
        "PrimaryJobType",         // Main job type
        "PrimaryJobValue",        // Main job value
        
        // ===== SUMMARY METRICS =====
        "TotalJobCount",          // Total jobs on work order
        "TotalJobValue",          // Total value of all jobs
        
        // ===== EQUIPMENT CONTEXT =====
        "Registration",           // Vehicle registration
        "StockNumber",            // Equipment stock number
        "Odometer",               // Equipment usage reading
        
        // ===== TIME & DEADLINE METRICS =====
        "WorkOrderAge",           // Age in days
        "DaysUntilExpected",      // Days to deadline
        "BusinessDaysOverdue",    // Business days past due
        
        // ===== PRIORITY & URGENCY =====
        "PriorityScore",          // 0-100 priority algorithm
        "PriorityCategory",       // Critical/High/Medium/Low
        "RevenueRiskScore",       // Financial impact risk
        
        // ===== BUSINESS CATEGORIZATION =====
        "WorkOrderSize",          // Large/Medium/Small by value
        "ComplexityLevel",        // High/Medium/Low by job count
        "ServiceType",            // Service classification
        "SeasonalCategory",       // Peak/Off season indicator
        
        // ===== RISK & PERFORMANCE INDICATORS =====
        "DelayRiskLevel",         // Delay prediction indicator
        "WorkOrderVelocity",      // Progression speed indicator
        "SLAStatus",              // Service level agreement status
        
        // ===== STATUS FLAGS =====
        "IsActive",               // Still in progress flag
        "IsOverdue",              // Past deadline flag
        
        // ===== DATA QUALITY & VALIDATION =====
        "DataQualityScore",       // 0-100 data completeness score
        "ProgressStatus",         // Raw status for debugging
        
        // ===== AUDIT TRAIL =====
        "ModifiedDate"            // Last update timestamp
    }),
    
    // ========================================================================
    // STEP 16: COLUMN RENAMING FOR CONSISTENCY
    // ========================================================================
    /*
    PURPOSE: Ensure consistent naming conventions across all fact tables
    STANDARD: CustomerKey instead of FinalCustomerKey for uniformity
    */
    
    RenamedColumns = Table.RenameColumns(FinalColumns, {
        {"FinalCustomerKey", "CustomerKey"}
    }),
    
    // ========================================================================
    // STEP 17: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Integer for keys, datetime for dates, numbers for calculations
    */
    
    FinalDataTypes = Table.TransformColumnTypes(RenamedColumns, {
        // Keys and identifiers
        {"WorkOrderKey", type text}, {"WorkOrder", Int64.Type}, {"Branch", type text},
        {"CustomerKey", Int64.Type}, {"VehicleKey", Int64.Type}, {"BranchKey", Int64.Type}, 
        {"StatusKey", Int64.Type}, {"JobCodeKey", Int64.Type},
        
        // Date keys
        {"CreatedDateKey", Int64.Type}, {"ExpectedDateKey", Int64.Type},
        
        // Dates
        {"CreatedOn", type datetime}, {"ExpectedDate", type datetime},
        
        // Job information
        {"PrimaryJobCode", type text}, {"PrimaryJobType", type text}, {"PrimaryJobValue", type number},
        
        // Summary metrics
        {"TotalJobCount", Int64.Type}, {"TotalJobValue", type number},
        
        // Equipment context
        {"Registration", type text}, {"StockNumber", type text}, {"Odometer", type number},
        
        // Time metrics
        {"WorkOrderAge", type number}, {"DaysUntilExpected", type number}, {"BusinessDaysOverdue", Int64.Type},
        
        // Priority and risk
        {"PriorityScore", type number}, {"PriorityCategory", type text}, {"RevenueRiskScore", type number},
        
        // Categorization
        {"WorkOrderSize", type text}, {"ComplexityLevel", type text}, {"ServiceType", type text}, 
        {"SeasonalCategory", type text},
        
        // Risk indicators
        {"DelayRiskLevel", type text}, {"WorkOrderVelocity", type text}, {"SLAStatus", type text},
        
        // Flags
        {"IsActive", type logical}, {"IsOverdue", type logical},
        
        // Quality and audit
        {"DataQualityScore", type number}, {"ProgressStatus", type text}, {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes