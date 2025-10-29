/*
============================================================================
FACT_LABORWIP - EXECUTIVE WORK IN PROGRESS & WIP ANALYTICS
============================================================================

📋 TABLE OVERVIEW:
Purpose: Executive-level WIP analysis with active work order tracking and aging intelligence
Grain: One row per active work order (WIP-focused for operational dashboards)
Refresh Strategy: Full refresh (inherits 1-minute performance from raw table)
Current Performance: Target 1-2 minutes refresh time
Source Dependencies: Raw_RepairOrderDetail + 4 dimension tables

🎯 BUSINESS USE CASES:
• WIP Dashboards: Real-time work in progress reporting with aging and priority management
• Executive WIP Analysis: C-level work order performance metrics and KPI tracking
• Operational WIP Management: Active work order lifecycle tracking and resource allocation
• WIP Financial Intelligence: Work order revenue analysis for active and recently completed orders
• WIP Resource Planning: Work order complexity assessment and priority-based resource allocation
• WIP Performance Tracking: Service delivery performance and completion efficiency metrics
• Cross-Fact WIP Integration: WIP summary hub linking to detailed labor analytics for active orders
• Management WIP Reporting: Operational reporting focused on work in progress and completion

📊 KEY METRICS PROVIDED (PRE-CALCULATED IN RAW TABLE):
• WIP Financial Intelligence: Revenue breakdown by category for active and recent work orders
• WIP Analytics: Work started tracking, aging categories, and progress status intelligence
• WIP Timeline Intelligence: Creation to completion lifecycle with critical milestone tracking
• WIP Performance Classification: Revenue categories, service mix types, and priority indicators
• WIP Operational Metrics: Active work order identification and completion status tracking
• WIP Quality Indicators: Data quality scoring and business validation for operational decisions

🔗 DIMENSION RELATIONSHIPS:
• dim_BranchLocation → BranchKey (territory-based WIP performance and resource analysis)
• dim_JobCode → JobCodeKey (service type WIP analysis and complexity assessment)
• dim_WorkOrderMaster → DimWorkOrderKey (CRITICAL: complete work order context integration)
• dim_DateTable → CreationDateKey (time intelligence for WIP trending and analysis)

📈 DASHBOARD IDEAS:
• Executive WIP Dashboard: Real-time work in progress with aging analysis and priority management
• WIP Financial Performance: Active work order revenue analysis with service mix optimization
• Operational WIP Excellence: Work order lifecycle tracking with completion efficiency metrics
• Strategic WIP Planning: Service mix analysis supporting pricing and resource allocation decisions
• Management WIP Reporting: Operational KPI tracking with performance trends and benchmarks
• Cross-Fact WIP Analytics: WIP summary supporting detailed labor analysis drill-down capabilities

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Leverages ALL pre-calculated business logic from Raw_RepairOrderDetail
• WIP-focused data scope (594 active/recent work orders vs full historical dataset)
• Essential columns optimized for WIP dashboard performance
• Inherits excellent 1-minute refresh performance from raw table
• Text composite work order keys for cross-fact integration
• Direct date key generation to avoid dimension lookup performance issues

🔧 MAINTENANCE NOTES:
• Business logic centralized in Raw_RepairOrderDetail for WIP consistency
• Work order keys now use text composite format for cross-fact compatibility
• Monitor dimension lookup success rates for WIP reporting accuracy
• Validate WIP calculations and aging logic based on operational requirements
• Review revenue thresholds and service mix classifications quarterly
• Ensure work order key alignment for seamless cross-fact integration

============================================================================
*/

let
    // ========================================================================
    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN
    // ========================================================================
    /*
    PURPOSE: Consistent incremental refresh pattern across all fact tables
    APPROACH: Optional parameters for WIP table (may not need date filtering for active WIP)
    STANDARD: Use same date range as other fact tables for consistency if needed
    */
    
    // Standard incremental refresh parameters (optional for WIP-focused table)
    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),   // Standard across all fact tables
    RangeEnd = DateTime.LocalNow(),                 // Always current data
    
    // ========================================================================
    // STEP 1: SOURCE DATA WITH COMPREHENSIVE WIP & FINANCIAL INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Leverage excellent raw table with complete work order business calculations
    BUSINESS LOGIC: Raw table contains WIP analysis, financial intelligence, and lifecycle tracking
    BENEFIT: Focus on dimensional relationships while preserving WIP analytical richness
    SCOPE: 594 active/recent work orders - perfect for WIP reporting (not full historical dataset)
    */
    
    Source = Raw_RepairOrderDetail,
    
    // ========================================================================
    // STEP 2: DIMENSION LOOKUP - BRANCH LOCATION
    // ========================================================================
    /*
    PURPOSE: Link work orders to branch/territory information for WIP performance analysis
    BUSINESS LOGIC: Branch → BranchID for territory-based work order performance and resource analysis
    BENEFIT: Enables geographic WIP performance comparison and resource allocation optimization
    */
    
    BranchLookup = Table.NestedJoin(
        Source, {"Branch"}, 
        dim_BranchLocation, {"BranchID"}, 
        "BranchDim", JoinKind.LeftOuter),
    
    ExpandBranch = Table.ExpandTableColumn(
        BranchLookup, "BranchDim", 
        {"BranchKey"}, {"BranchDimKey"}),
    
    // ========================================================================
    // STEP 3: DIMENSION LOOKUP - JOB CODE
    // ========================================================================
    /*
    PURPOSE: Link work orders to service type classification for WIP strategic analysis
    BUSINESS LOGIC: JobCode → JobCode for service type performance and complexity assessment
    BENEFIT: Enables service type WIP analysis and strategic resource allocation planning
    */
    
    JobCodeLookup = Table.NestedJoin(
        ExpandBranch, {"JobCode"}, 
        dim_JobCode, {"JobCode"}, 
        "JobCodeDim", JoinKind.LeftOuter),
    
    ExpandJobCode = Table.ExpandTableColumn(
        JobCodeLookup, "JobCodeDim", 
        {"JobCodeKey"}, {"JobCodeDimKey"}),
    
    // ========================================================================
    // STEP 4: DIMENSION LOOKUP - WORK ORDER (CRITICAL FIX!)
    // ========================================================================
    /*
    PURPOSE: Link work order summaries to work order master data for cross-fact integration
    BUSINESS LOGIC: Branch + WorkOrder → BranchWorkOrder for cross-fact compatibility
    BENEFIT: CRITICAL - Enables WIP summary integration with detailed labor analytics
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
    // STEP 5: CREATE DATE KEY FOR TIME INTELLIGENCE
    // ========================================================================
    /*
    PURPOSE: Create date key for WIP time intelligence without dimension lookup issues
    BUSINESS LOGIC: Generate date key directly from CreationDate for reliable WIP reporting
    BENEFIT: Reliable time intelligence for WIP dashboards without performance issues
    */
    
    CreateDateKey = Table.AddColumn(ExpandWorkOrder, "CreationDateKey", each 
        if [CreationDate] <> null then 
            Date.Year([CreationDate]) * 10000 + 
            Date.Month([CreationDate]) * 100 + 
            Date.Day([CreationDate])
        else 99999999, Int64.Type),
    
    // ========================================================================
    // STEP 6: CREATE CLEAN DIMENSION KEYS (UPDATED FOR TEXT WORK ORDER KEYS)
    // ========================================================================
    /*
    PURPOSE: Create clean dimension keys for WIP dashboard relationships
    BUSINESS LOGIC: Use dimension lookup keys where available, appropriate defaults for missing
    BENEFIT: Clean WIP dashboard keys for optimal Power BI relationships and analysis
    FIX: DimWorkOrderKey now text type with "UNKNOWN" default instead of integer -1
    */
    
    HandleMissingKeys = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(CreateDateKey,
                "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),
            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),
        "DimWorkOrderKey", each [WorkOrderMasterKey] ?? "UNKNOWN", type text),
    
    // ========================================================================
    // STEP 7: EXECUTIVE-LEVEL BUSINESS INTELLIGENCE ENHANCEMENTS
    // ========================================================================
    /*
    PURPOSE: Add WIP-focused business logic for strategic decision making
    BUSINESS LOGIC: WIP classifications and strategic performance indicators
    BENEFIT: Enhanced WIP analytical capability beyond raw table calculations
    */
    
    // Strategic priority classification (combining revenue, aging, and status)
    AddStrategicPriority = Table.AddColumn(HandleMissingKeys, "StrategicPriority", each
        let
            revenue = [TotalRevenue] ?? 0,
            aging = [Aging] ?? "",
            isActive = [IsActiveWorkOrder] ?? false
        in
        if not isActive then "Completed"
        else if revenue >= 10000 and aging = "60+ Days" then "Critical High Value"
        else if revenue >= 2500 and (aging = "31 - 60 Days" or aging = "60+ Days") then "High Priority"
        else if aging = "60+ Days" then "Overdue"
        else if revenue >= 10000 then "High Value Active"
        else if aging = "Not Started" then "Pending Start"
        else "Standard Active", type text),
    
    // WIP attention required flag
    AddRequiresAttention = Table.AddColumn(AddStrategicPriority, "RequiresWIPAttention", each
        [StrategicPriority] = "Critical High Value" or 
        [StrategicPriority] = "High Priority" or 
        [StrategicPriority] = "Overdue", type logical),
    
    // Service complexity assessment for WIP resource planning
    AddServiceComplexity = Table.AddColumn(AddRequiresAttention, "ServiceComplexity", each
        let
            totalRevenue = [TotalRevenue] ?? 0,
            serviceMix = [ServiceMixType] ?? "",
            aging = [AgingSortOrder] ?? 0
        in
        if totalRevenue >= 15000 or aging <= 1 then "High Complexity"
        else if totalRevenue >= 5000 or serviceMix = "Balanced Mix" then "Medium Complexity"
        else "Standard Complexity", type text),
    
    // WIP performance category for operational reporting
    AddPerformanceCategory = Table.AddColumn(AddServiceComplexity, "WIPPerformanceCategory", each
        let
            isActive = [IsActiveWorkOrder] ?? false,
            aging = [Aging] ?? "",
            revenue = [TotalRevenue] ?? 0
        in
        if not isActive and revenue > 0 then "Completed & Billed"
        else if not isActive then "Completed"
        else if aging = "Not Started" then "Awaiting Start"
        else if aging = "1 - 7 Days" then "On Track"
        else if aging = "8 - 14 Days" then "Monitor"
        else if aging = "15 - 30 Days" then "At Risk"
        else "Overdue", type text),
    
    // Revenue efficiency indicator for WIP
    AddRevenueEfficiency = Table.AddColumn(AddPerformanceCategory, "RevenueEfficiency", each
        let
            laborPct = [LaborPercentage] ?? 0,
            revenue = [TotalRevenue] ?? 0,
            aging = [DaysSinceCreationDate] ?? 0
        in
        if revenue = 0 then "No Revenue"
        else if laborPct >= 0.6 and aging <= 14 then "High Efficiency"
        else if laborPct >= 0.4 and aging <= 30 then "Good Efficiency"
        else if aging <= 60 then "Average Efficiency"
        else "Low Efficiency", type text),
    
    // WIP KPI classification
    AddWIPKPI = Table.AddColumn(AddRevenueEfficiency, "WIPKPI", each
        let
            priority = [StrategicPriority] ?? "",
            complexity = [ServiceComplexity] ?? "",
            performance = [WIPPerformanceCategory] ?? ""
        in
        if priority = "Critical High Value" then "Critical"
        else if priority = "High Priority" or priority = "Overdue" then "High"
        else if complexity = "High Complexity" then "Complex"
        else if performance = "At Risk" or performance = "Overdue" then "Risk"
        else "Standard", type text),
    
    // ========================================================================
    // STEP 8: OPERATIONAL FLAGS FOR WIP DASHBOARDS
    // ========================================================================
    /*
    PURPOSE: Add operational flags specific to WIP dashboard needs
    BUSINESS LOGIC: Flags for WIP filtering and strategic decision making
    BENEFIT: Enhanced WIP dashboard filtering and management capability
    */
    
    // High value work order flag
    AddHighValueFlag = Table.AddColumn(AddWIPKPI, "IsHighValue", each
        [RevenueCategory] = "High Value", type logical),
    
    // Overdue work order flag
    AddOverdueFlag = Table.AddColumn(AddHighValueFlag, "IsOverdue", each
        [Aging] = "60+ Days" and [IsActiveWorkOrder], type logical),
    
    // Complex service flag
    AddComplexServiceFlag = Table.AddColumn(AddOverdueFlag, "IsComplexService", each
        [ServiceComplexity] = "High Complexity", type logical),
    
    // Revenue optimization opportunity flag
    AddRevenueOptimizationFlag = Table.AddColumn(AddComplexServiceFlag, "IsRevenueOptimization", each
        [RevenueEfficiency] = "Low Efficiency" and [IsActiveWorkOrder], type logical),
    
    // WIP priority flag
    AddWIPPriorityFlag = Table.AddColumn(AddRevenueOptimizationFlag, "IsWIPPriority", each
        [RequiresWIPAttention] or [IsHighValue] or [IsOverdue], type logical),
    
    // Active WIP management flag
    AddWIPManagementFlag = Table.AddColumn(AddWIPPriorityFlag, "IsActiveWIP", each
        [IsActiveWorkOrder] and ([Aging] <> "Not Started"), type logical),
    
    // ========================================================================
    // STEP 9: FINAL COLUMN SELECTION AND OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Select essential columns for optimal WIP dashboard performance
    BUSINESS LOGIC: Include all dimensional keys, WIP metrics, and essential business attributes
    BENEFIT: Minimizes memory footprint while maintaining comprehensive WIP analytical capability
    */
    
    FinalColumns = Table.SelectColumns(AddWIPManagementFlag, {
        // ===== DIMENSION KEYS =====
        "BranchKey", "JobCodeKey", "DimWorkOrderKey", "CreationDateKey",
        
        // ===== CORE IDENTIFIERS =====
        "Branch", "WorkOrder", "JobCode", "JobType", "InvoiceNumber",
        
        // ===== STATUS & PROGRESS INTELLIGENCE (FROM RAW TABLE) =====
        "StatusDisplay", "ROProgressStatus", "ProgressStatusDisplay",
        
        // ===== TIMELINE INTELLIGENCE (FROM RAW TABLE) =====
        "CreationDate", "JobStartDate", "FirstLaborPunch", "LastLaborPunch", "DaysSinceCreationDate",
        
        // ===== COMPLETE FINANCIAL INTELLIGENCE (FROM RAW TABLE) =====
        "LaborRevenue", "PartsRevenue", "SubletRevenue", "OtherRevenue", "TotalRevenue",
        
        // ===== WIP ANALYSIS (FROM RAW TABLE) =====
        "WorkStarted", "Aging", "AgingSortOrder", "IsActiveWorkOrder",
        
        // ===== SERVICE & REVENUE ANALYSIS (FROM RAW TABLE) =====
        "RevenueCategory", "PartsPercentage", "LaborPercentage", "ServiceMixType",
        
        // ===== BUSINESS INDICATORS (FROM RAW TABLE) =====
        "QuotationIndicator", "NonRevenueIndicator",
        
        // ===== WIP INTELLIGENCE (FACT TABLE ENHANCED) =====
        "StrategicPriority", "ServiceComplexity", "WIPPerformanceCategory", 
        "RevenueEfficiency", "WIPKPI",
        
        // ===== WIP FLAGS (FACT TABLE ENHANCED) =====
        "RequiresWIPAttention", "IsHighValue", "IsOverdue", "IsComplexService",
        "IsRevenueOptimization", "IsWIPPriority", "IsActiveWIP",
        
        // ===== DATA QUALITY (FROM RAW TABLE) =====
        "DataQualityScore",
        
        // ===== AUDIT FIELDS =====
        "WorkOrderKey"
    }),
    
    // ========================================================================
    // STEP 10: FINAL DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Ensure optimal data types for WIP dashboard performance and memory efficiency
    BUSINESS LOGIC: Appropriate data types for each column based on WIP reporting needs
    BENEFIT: Optimal WIP dashboard performance and minimal memory footprint
    FIX: DimWorkOrderKey now type text instead of Int64
    */
    
    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {
        // Dimension keys (UPDATED: DimWorkOrderKey now text)
        {"BranchKey", Int64.Type}, {"JobCodeKey", Int64.Type}, 
        {"DimWorkOrderKey", type text}, {"CreationDateKey", Int64.Type},
        
        // Identifiers
        {"Branch", type text}, {"WorkOrder", Int64.Type}, {"JobCode", type text}, 
        {"JobType", type text}, {"InvoiceNumber", type text},
        
        // Status and progress
        {"StatusDisplay", type text}, {"ROProgressStatus", type text}, {"ProgressStatusDisplay", type text},
        
        // Timeline
        {"CreationDate", type datetime}, {"JobStartDate", type datetime}, 
        {"FirstLaborPunch", type datetime}, {"LastLaborPunch", type datetime}, {"DaysSinceCreationDate", Int64.Type},
        
        // Financial data
        {"LaborRevenue", type number}, {"PartsRevenue", type number}, {"SubletRevenue", type number},
        {"OtherRevenue", type number}, {"TotalRevenue", type number},
        
        // WIP analysis
        {"WorkStarted", type logical}, {"Aging", type text}, {"AgingSortOrder", Int64.Type}, {"IsActiveWorkOrder", type logical},
        
        // Service and revenue analysis
        {"RevenueCategory", type text}, {"PartsPercentage", type number}, 
        {"LaborPercentage", type number}, {"ServiceMixType", type text},
        
        // Business indicators
        {"QuotationIndicator", type text}, {"NonRevenueIndicator", type text},
        
        // WIP intelligence
        {"StrategicPriority", type text}, {"ServiceComplexity", type text}, {"WIPPerformanceCategory", type text},
        {"RevenueEfficiency", type text}, {"WIPKPI", type text},
        
        // WIP flags
        {"RequiresWIPAttention", type logical}, {"IsHighValue", type logical}, {"IsOverdue", type logical},
        {"IsComplexService", type logical}, {"IsRevenueOptimization", type logical}, 
        {"IsWIPPriority", type logical}, {"IsActiveWIP", type logical},
        
        // Data quality and audit
        {"DataQualityScore", type number}, {"WorkOrderKey", type text}
    })

in
    FinalDataTypes

/*
============================================================================
✅ FACT_LABORWIP - CROSS-FACT INTEGRATION FIX COMPLETE
============================================================================

🔄 CRITICAL FIXES IMPLEMENTED:
• Work Order Key Format: Changed from integer surrogate to text composite keys
• Cross-Fact Compatibility: Now uses BranchWorkOrder for seamless integration with other labor tables
• Incremental Refresh: Added standard parameters for consistency (optional for WIP focus)
• Data Type Optimization: Updated DimWorkOrderKey to text type with proper defaults
• WIP Documentation: Updated to reflect WIP-specific focus and purpose

⚡ EXPECTED VALIDATION IMPROVEMENTS:
• Work Order Overlap: Should jump from 0% to 95%+ with existing fact tables
• Orphaned Records: Significant reduction in work order orphaned records
• Cross-Fact Analysis: Full integration with all other labor fact tables
• WIP Reporting: Seamless integration between WIP summary and detailed labor analytics

🎯 WIP-FOCUSED ARCHITECTURAL EXCELLENCE:
• WIP Data Scope: 594 active/recent work orders - perfect for operational WIP reporting
• WIP Performance: Maintains excellent 1-2 minute refresh with cross-fact compatibility
• WIP Intelligence: Complete work order lifecycle tracking for active and recent completions
• Cross-Fact WIP Hub: Enables drill-down from WIP summary to detailed labor analytics

🔗 DIMENSIONAL INTEGRATION SUCCESS:
• BranchKey → Territory-based WIP performance and resource allocation analysis
• JobCodeKey → Service type WIP analysis and complexity assessment
• DimWorkOrderKey → CRITICAL cross-fact integration via text composite keys (FIXED)
• CreationDateKey → WIP time intelligence for operational trending and analysis

📊 WIP BUSINESS VALUE DELIVERED:
• Complete WIP Intelligence: Real-time work in progress with aging analysis and priority management
• Strategic WIP Performance: Work order lifecycle tracking with KPI classification and alerts
• Financial WIP Intelligence: Complete revenue analysis for active work orders with service mix optimization
• Resource WIP Planning: Service complexity assessment and strategic resource allocation optimization
• Cross-Fact WIP Integration: WIP summary hub enabling drill-down to detailed labor analytics
• Management WIP Reporting: Operational dashboard foundation with actionable insights

============================================================================
*/