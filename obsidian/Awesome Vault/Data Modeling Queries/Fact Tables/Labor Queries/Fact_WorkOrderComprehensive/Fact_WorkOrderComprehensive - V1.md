/*

============================================================================

FACT_WORKORDERCOMPREHENSIVE - COMPLETE WORK ORDER ANALYTICS FOUNDATION

============================================================================

  

📋 TABLE OVERVIEW:

Purpose: Comprehensive work order analytics with complete lifecycle and cross-dimensional intelligence

Grain: One row per work order (complete historical and active work order coverage)

Refresh Strategy: Incremental refresh ready (ModifiedDate filtering - optimized approach)

Current Performance: Target 3-5 minutes refresh time (comprehensive data integration)

Source Dependencies: Raw_wkrofile + 3 raw tables + 7 dimensions

  

🎯 BUSINESS USE CASES:

• Complete Work Order Analytics: Comprehensive historical and active work order performance analysis

• Cross-Fact Integration Hub: Central work order context for all labor, parts, and warranty fact tables

• Customer Relationship Intelligence: Complete customer classification and service relationship analysis

• Equipment Service Intelligence: Manufacturer-specific service patterns and performance optimization

• Financial Work Order Analysis: Authorization values, job costing, and profitability assessment

• Service Mix Optimization: Field vs shop service patterns and resource allocation analysis

• Territory Performance: Geographic analysis with branch and regional performance comparison

• Executive Reporting: Complete work order intelligence for strategic decision making and KPI tracking

  

📊 KEY METRICS PROVIDED:

• Complete Work Order Intelligence: Enhanced work order data with equipment and customer context

• Financial Integration: Job-level financial summaries (Est/Act/Inv) with authorization values

• Service Classification: Field service, quotations, and service type intelligence

• Timeline Intelligence: Complete lifecycle from creation to completion with aging analysis

• Customer Intelligence: Account classification, payment methods, and relationship context

• Equipment Intelligence: Manufacturer, franchise, and vehicle-specific service analysis

• Geographic Intelligence: Tax region and territory-based performance analysis

• Cross-Fact Keys: Text composite keys enabling seamless integration with all labor fact tables

  

🔗 DIMENSION RELATIONSHIPS:

• dim_BranchLocation → BranchKey (territory and location-based work order analysis)

• dim_CustomerList → CustomerKey (customer classification and relationship analysis)  

• dim_Vehicle → VehicleKey (equipment and manufacturer-specific service analysis)

• dim_JobCode → JobCodeKey (service type and complexity analysis)

• dim_WorkOrderStatus → StatusKey (workflow and progress intelligence)

• dim_DateTable → CreatedDateKey, ExpectedDateKey, ClosedDateKey (complete time intelligence)

  

📈 DASHBOARD IDEAS:

• Executive Work Order Dashboard: Complete KPI tracking with cross-dimensional analysis capability

• Customer Service Excellence: Work order performance by customer classification and service type

• Equipment Service Analysis: Manufacturer-specific service patterns and warranty correlation

• Territory Performance: Geographic work order analysis with branch and regional benchmarking

• Service Mix Optimization: Field vs shop resource allocation and efficiency analysis

• Financial Work Order Intelligence: Authorization values and job costing with profitability analysis

• Cross-Fact Analytics Hub: Work order context supporting detailed labor, parts, and warranty analysis

  

⚡ PERFORMANCE OPTIMIZATION NOTES:

• Leverages enhanced Raw_wkrofile with comprehensive business intelligence

• Strategic raw table joins for maximum context with optimized performance

• Text composite work order keys for seamless cross-fact integration

• Incremental refresh ready with ModifiedDate filtering inheritance

• Essential column selection balancing comprehensive intelligence with refresh performance

• Pre-calculated business logic minimizes complex DAX requirements

  

🔧 MAINTENANCE NOTES:

• Monitor refresh performance as comprehensive data integration complexity increases

• Validate cross-fact integration with labor tables using text composite work order keys

• Review financial reconciliation between job summaries and labor fact tables quarterly

• Ensure dimension lookup success rates remain high for comprehensive analysis

• Update business classifications based on evolving operational requirements

  

============================================================================

*/

  

let

    // ========================================================================

    // INCREMENTAL REFRESH PARAMETERS - STANDARD PATTERN

    // ========================================================================

    /*

    PURPOSE: Consistent incremental refresh pattern across all fact tables

    APPROACH: Leverages raw table efficiency with optional independent control

    STANDARD: Use same date range as other fact tables for consistency

    */

    // Standard incremental refresh parameters (align with other fact tables)

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

    // ========================================================================

    // STEP 1: FOUNDATION - ENHANCED WORK ORDER DATA

    // ========================================================================

    /*

    PURPOSE: Load comprehensive work order foundation with enhanced intelligence

    APPROACH: Start with enhanced Raw_wkrofile providing 50K+ work orders with business intelligence

    BENEFIT: Complete historical coverage with comprehensive equipment and customer context

    */

    // Foundation: Enhanced work order data (already has WorkOrderKey as text composite)

    WorkOrderFoundation = Raw_wkrofile,

    // Create standardized composite key for all joins (ensure text format)

    AddBranchWorkOrder = Table.AddColumn(WorkOrderFoundation, "BranchWorkOrder", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    // ========================================================================

    // STEP 2: ENRICH WITH PRIMARY JOB DETAILS

    // ========================================================================

    /*

    PURPOSE: Add primary job information for service type and complexity analysis

    BUSINESS LOGIC: Join to Raw_wkrodesc for line_no = 1 (primary job) details

    BENEFIT: Service type classification and job-level context for work order analysis

    */

    // Prepare primary job data with matching key

    PrimaryJobsPrepped = Table.AddColumn(Raw_wkrodesc, "BranchWorkOrder", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    // Join primary job information

    JoinPrimaryJob = Table.NestedJoin(

        AddBranchWorkOrder, {"BranchWorkOrder"},

        PrimaryJobsPrepped, {"BranchWorkOrder"},

        "PrimaryJobMatch", JoinKind.LeftOuter),

    ExpandPrimaryJob = Table.ExpandTableColumn(JoinPrimaryJob, "PrimaryJobMatch",

        {"JobCode", "JobType", "JobValue"}, {"PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue"}),

    // ========================================================================

    // STEP 3: ENRICH WITH JOB FINANCIAL SUMMARIES

    // ========================================================================

    /*

    PURPOSE: Add job-level financial intelligence for comprehensive work order analysis

    BUSINESS LOGIC: Aggregate Raw_wkothsub by work order for Est/Act/Inv labor totals

    BENEFIT: Complete financial intelligence bridging individual jobs to work order totals

    */

    // Create job financial aggregations with proper null handling

    JobFinancialAggregations = Table.Group(Raw_wkothsub, {"Branch", "WorkOrder"}, {

        {"TotalEstLabor", each List.Sum(List.RemoveNulls(List.Transform([EstLabor], each try Number.From(_) otherwise 0))), Currency.Type},

        {"TotalActLabor", each List.Sum(List.RemoveNulls(List.Transform([ActLabor], each try Number.From(_) otherwise 0))), Currency.Type},

        {"TotalInvLabor", each List.Sum(List.RemoveNulls(List.Transform([InvLabor], each try Number.From(_) otherwise 0))), Currency.Type},

        {"TotalEstHours", each List.Sum(List.RemoveNulls(List.Transform([EstHours], each try Number.From(_) otherwise 0))), type number},

        {"JobCount", each Table.RowCount(_), Int64.Type},

        {"RevenueJobCount", each List.Count(List.Select([IsRevenueGenerating], each _ = true)), Int64.Type},

        {"FieldServiceJobCount", each List.Count(List.Select([IsFieldService], each _ = true)), Int64.Type}

    }),

    // Add composite key and join

    JobFinancialsWithKey = Table.AddColumn(JobFinancialAggregations, "BranchWorkOrder", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    JoinFinancialSummary = Table.NestedJoin(

        ExpandPrimaryJob, {"BranchWorkOrder"},

        JobFinancialsWithKey, {"BranchWorkOrder"},

        "FinancialSummary", JoinKind.LeftOuter),

    ExpandFinancialSummary = Table.ExpandTableColumn(JoinFinancialSummary, "FinancialSummary",

        {"TotalEstLabor", "TotalActLabor", "TotalInvLabor", "TotalEstHours",

         "JobCount", "RevenueJobCount", "FieldServiceJobCount"},

        {"TotalEstLabor", "TotalActLabor", "TotalInvLabor", "TotalEstHours",

         "JobCount", "RevenueJobCount", "FieldServiceJobCount"}),

    // ========================================================================

    // STEP 4: ENRICH WITH INVOICE CONTEXT (FIXED DUPLICATE COLUMN ISSUE)

    // ========================================================================

    /*

    PURPOSE: Add invoice linkage and billing context for financial analysis

    BUSINESS LOGIC: Join to Raw_WkInvReg for invoice numbers and billing information

    BENEFIT: Complete financial cycle from work order to invoice for revenue analysis

    FIX: Use different column names to avoid conflicts with Raw_wkrofile

    */

    // Prepare invoice data with composite key

    InvoiceDataPrepped = Table.AddColumn(Raw_WkInvReg, "BranchWorkOrder", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    JoinInvoiceContext = Table.NestedJoin(

        ExpandFinancialSummary, {"BranchWorkOrder"},

        InvoiceDataPrepped, {"BranchWorkOrder"},

        "InvoiceMatch", JoinKind.LeftOuter),

    // Use different names to avoid conflicts with Raw_wkrofile fields

    ExpandInvoiceContext = Table.ExpandTableColumn(JoinInvoiceContext, "InvoiceMatch",

        {"InvoiceNumber", "ROType", "LabourCost", "LabourCharged", "InvoiceTotal"},

        {"InvoiceDocumentNumber", "InvoiceROType", "InvoiceLabourCost", "InvoiceLabourCharged", "InvoiceTotal"}),

    // ========================================================================

    // STEP 5: DIMENSION LOOKUP - BRANCH LOCATION

    // ========================================================================

    /*

    PURPOSE: Link work orders to branch/territory information for geographic analysis

    BUSINESS LOGIC: Branch → BranchID for territory-based work order performance analysis

    BENEFIT: Enables geographic performance comparison and resource allocation optimization

    */

    BranchLookup = Table.NestedJoin(

        ExpandInvoiceContext, {"Branch"},

        dim_BranchLocation, {"BranchID"},

        "BranchDim", JoinKind.LeftOuter),

    ExpandBranch = Table.ExpandTableColumn(BranchLookup, "BranchDim",

        {"BranchKey"}, {"BranchDimKey"}),

    // ========================================================================

    // STEP 6: DIMENSION LOOKUP - CUSTOMER

    // ========================================================================

    /*

    PURPOSE: Link work orders to customer master data for relationship analysis

    BUSINESS LOGIC: AccountNumber → CustomerAccount for customer classification

    BENEFIT: Enables customer performance analysis and service relationship optimization

    */

    CustomerLookup = Table.NestedJoin(

        ExpandBranch, {"AccountNumber"},

        dim_CustomerList, {"AccountNumberText"},

        "CustomerDim", JoinKind.LeftOuter),

    ExpandCustomer = Table.ExpandTableColumn(CustomerLookup, "CustomerDim",

        {"CustomerKey"}, {"CustomerDimKey"}),

    // ========================================================================

    // STEP 7: DIMENSION LOOKUP - VEHICLE

    // ========================================================================

    /*

    PURPOSE: Link work orders to vehicle/equipment information for service analysis

    BUSINESS LOGIC: Registration or StockNumber → vehicle identification

    BENEFIT: Enables equipment-specific service analysis and manufacturer performance tracking

    */

    VehicleLookup = Table.NestedJoin(

        ExpandCustomer, {"Registration"},

        dim_Vehicle, {"Registration"},

        "VehicleDim", JoinKind.LeftOuter),

    ExpandVehicle = Table.ExpandTableColumn(VehicleLookup, "VehicleDim",

        {"VehicleKey"}, {"VehicleDimKey"}),

    // ========================================================================

    // STEP 8: DIMENSION LOOKUP - JOB CODE

    // ========================================================================

    /*

    PURPOSE: Link work orders to service type classification for service analysis

    BUSINESS LOGIC: PrimaryJobCode → JobCode for service type intelligence

    BENEFIT: Enables service type analysis and complexity assessment

    */

    JobCodeLookup = Table.NestedJoin(

        ExpandVehicle, {"PrimaryJobCode"},

        dim_JobCode, {"JobCode"},

        "JobCodeDim", JoinKind.LeftOuter),

    ExpandJobCode = Table.ExpandTableColumn(JobCodeLookup, "JobCodeDim",

        {"JobCodeKey"}, {"JobCodeDimKey"}),

    // ========================================================================

    // STEP 9: DIMENSION LOOKUP - WORK ORDER STATUS (FIXED CASE SENSITIVITY)

    // ========================================================================

    /*

    PURPOSE: Link work orders to status workflow intelligence

    BUSINESS LOGIC: ProgressStatus → StatusCode for workflow analysis (case-insensitive match)

    BENEFIT: Enables status-based performance analysis and workflow optimization

    FIX: Convert ProgressStatus to lowercase to match dim_WorkOrderStatus.StatusCode format

    */

    // Convert ProgressStatus to lowercase for proper dimension lookup

    AddProgressStatusLower = Table.AddColumn(ExpandJobCode, "ProgressStatusLower", each

        Text.Lower(Text.Trim([ProgressStatus] ?? "")), type text),

    StatusLookup = Table.NestedJoin(

        AddProgressStatusLower, {"ProgressStatusLower"},

        dim_WorkOrderStatus, {"StatusCode"},

        "StatusDim", JoinKind.LeftOuter),

    ExpandStatus = Table.ExpandTableColumn(StatusLookup, "StatusDim",

        {"StatusKey"}, {"StatusDimKey"}),

    // ========================================================================

    // STEP 10: CREATE DATE KEYS FOR TIME INTELLIGENCE

    // ========================================================================

    /*

    PURPOSE: Create multiple date keys for comprehensive time intelligence

    BUSINESS LOGIC: Generate date keys directly from datetime fields

    BENEFIT: Reliable time intelligence across work order lifecycle phases

    */

    CreateDateKeys = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(ExpandStatus,

                "CreatedDateKey", each

                    if [CreatedOn] <> null then

                        Date.Year([CreatedOn]) * 10000 +

                        Date.Month([CreatedOn]) * 100 +

                        Date.Day([CreatedOn])

                    else 99999999, Int64.Type),

            "ExpectedDateKey", each

                if [ExpectedDate] <> null then

                    Date.Year([ExpectedDate]) * 10000 +

                    Date.Month([ExpectedDate]) * 100 +

                    Date.Day([ExpectedDate])

                else 99999999, Int64.Type),

        "ClosedDateKey", each

            if [ClosedDate] <> null then

                Date.Year([ClosedDate]) * 10000 +

                Date.Month([ClosedDate]) * 100 +

                Date.Day([ClosedDate])

            else 99999999, Int64.Type),

    // ========================================================================

    // STEP 11: CREATE CLEAN DIMENSION KEYS WITH CROSS-FACT INTEGRATION

    // ========================================================================

    /*

    PURPOSE: Create clean dimension keys for comprehensive analytics relationships

    BUSINESS LOGIC: Use dimension lookup keys where available, appropriate defaults for missing

    BENEFIT: Clean fact table keys for optimal Power BI relationships

    CRITICAL: Use BranchWorkOrder (text composite) for cross-fact integration with labor tables

    */

    HandleDimensionKeys = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(

                Table.AddColumn(

                    Table.AddColumn(CreateDateKeys,

                        "BranchKey", each [BranchDimKey] ?? -1, Int64.Type),

                    "CustomerKey", each [CustomerDimKey] ?? -1, Int64.Type),

                "VehicleKey", each [VehicleDimKey] ?? -1, Int64.Type),

            "JobCodeKey", each [JobCodeDimKey] ?? -1, Int64.Type),

        "StatusKey", each [StatusDimKey] ?? -1, Int64.Type),

    // Use BranchWorkOrder for cross-fact integration (matches labor fact table pattern)

    AddWorkOrderDimKey = Table.AddColumn(HandleDimensionKeys, "DimWorkOrderKey", each

        [BranchWorkOrder] ?? "UNKNOWN", type text),

    // ========================================================================

    // STEP 12: BUSINESS INTELLIGENCE CALCULATIONS

    // ========================================================================

    /*

    PURPOSE: Calculate key business metrics using fields that actually exist

    BUSINESS LOGIC: Work order-level classifications and performance indicators

    BENEFIT: Enhanced analytical capability for strategic decision making

    */

    // Labor efficiency calculations (using available financial fields)

    AddLaborEfficiency = Table.AddColumn(AddWorkOrderDimKey, "LaborEfficiency", each

        if ([TotalEstLabor] ?? 0) > 0 then

            Number.Round(([TotalActLabor] ?? 0) / [TotalEstLabor], 4)

        else null, type number),

    // Work order value classification (using AuthorizationValue from Raw_wkrofile)

    AddWorkOrderValueCategory = Table.AddColumn(AddLaborEfficiency, "WorkOrderValueCategory", each

        let authValue = [AuthorizationValue] ?? 0 in

        if authValue >= 15000 then "Premium Value (15K+)"

        else if authValue >= 5000 then "High Value (5K-15K)"

        else if authValue >= 1500 then "Medium Value (1.5K-5K)"

        else if authValue >= 300 then "Low Value (300-1.5K)"

        else if authValue > 0 then "Minimal Value (<300)"

        else "No Authorization", type text),

    // Service complexity assessment (using available job data)

    AddServiceComplexity = Table.AddColumn(AddWorkOrderValueCategory, "ServiceComplexity", each

        let

            jobCount = [JobCount] ?? 0,

            estHours = [TotalEstHours] ?? 0,

            fieldJobs = [FieldServiceJobCount] ?? 0,

            hasFieldService = [IsFieldService] ?? false

        in

        if jobCount >= 5 or estHours >= 20 or fieldJobs >= 2 or hasFieldService then "High Complexity"

        else if jobCount >= 3 or estHours >= 8 then "Medium Complexity"

        else "Standard Complexity", type text),

    // Work order performance classification

    AddPerformanceCategory = Table.AddColumn(AddServiceComplexity, "PerformanceCategory", each

        let

            efficiency = [LaborEfficiency] ?? 999,

            isClosed = [IsClosed] ?? false,

            workOrderAge = [WorkOrderAgeInDays] ?? 0

        in

        if isClosed and efficiency <= 1.0 then "Excellent Performance"

        else if isClosed and efficiency <= 1.2 then "Good Performance"

        else if isClosed then "Completed"

        else if workOrderAge <= 7 then "On Track"

        else if workOrderAge <= 14 then "Monitor"

        else if workOrderAge <= 30 then "At Risk"

        else "Overdue", type text),

    // Financial performance indicator (using invoice data)

    AddFinancialPerformance = Table.AddColumn(AddPerformanceCategory, "FinancialPerformance", each

        let

            invLabor = [TotalInvLabor] ?? 0,

            actLabor = [TotalActLabor] ?? 0,

            invoiceTotal = [InvoiceTotal] ?? 0

        in

        if invLabor > 0 and actLabor > 0 then

            let billingEff = invLabor / actLabor in

            if billingEff >= 1.0 and invoiceTotal >= 5000 then "High Revenue"

            else if billingEff >= 0.95 then "Good Revenue"

            else if billingEff >= 0.80 then "Fair Revenue"

            else "Low Revenue"

        else if invoiceTotal > 0 then "Revenue Recorded"

        else "No Revenue", type text),

    // ========================================================================

    // STEP 13: OPERATIONAL FLAGS FOR COMPREHENSIVE ANALYSIS

    // ========================================================================

    /*

    PURPOSE: Add operational flags specific to comprehensive work order management

    BUSINESS LOGIC: Flags for comprehensive filtering and strategic decision making

    BENEFIT: Enhanced filtering and management capability for comprehensive work order analysis

    */

    // High value work order flag

    AddHighValueFlag = Table.AddColumn(AddFinancialPerformance, "IsHighValue", each

        Text.Contains([WorkOrderValueCategory], "Premium") or Text.Contains([WorkOrderValueCategory], "High"), type logical),

    // Complex service flag

    AddComplexServiceFlag = Table.AddColumn(AddHighValueFlag, "IsComplexService", each

        [ServiceComplexity] = "High Complexity", type logical),

    // Performance excellence flag

    AddPerformanceExcellenceFlag = Table.AddColumn(AddComplexServiceFlag, "IsPerformanceExcellence", each

        Text.Contains([PerformanceCategory], "Excellent"), type logical),

    // Revenue optimization flag

    AddRevenueOptimizationFlag = Table.AddColumn(AddPerformanceExcellenceFlag, "IsRevenueOptimization", each

        [FinancialPerformance] = "Low Revenue" and [IsHighValue], type logical),

    // Cross-fact analysis ready flag

    AddCrossFactReadyFlag = Table.AddColumn(AddRevenueOptimizationFlag, "IsCrossFactReady", each

        [DimWorkOrderKey] <> "UNKNOWN", type logical),

    // ========================================================================

    // STEP 14: FINAL COLUMN SELECTION AND OPTIMIZATION

    // ========================================================================

    /*

    PURPOSE: Select essential columns for comprehensive work order analytics performance

    BUSINESS LOGIC: Include all dimensional keys, comprehensive metrics, and essential business attributes

    BENEFIT: Optimal memory usage while maintaining comprehensive analytical capability

    */

    FinalColumns = Table.SelectColumns(AddCrossFactReadyFlag, {

        // ===== DIMENSION KEYS =====

        "BranchKey", "CustomerKey", "VehicleKey", "JobCodeKey", "StatusKey",

        "DimWorkOrderKey", "CreatedDateKey", "ExpectedDateKey", "ClosedDateKey",

        // ===== CORE IDENTIFIERS =====

        "Branch", "WorkOrder", "Registration", "StockNumber", "AccountNumber",

        "PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue",

        // ===== ENHANCED INTELLIGENCE FROM RAW_WKROFILE =====

        "Franchise", "Odometer", "AccountClass", "AuthorizationValue", "Salesperson",

        "PaymentMethod", "TaxRegion", "ServiceTypeClassification", "CustomerClassification",

        // ===== TIMELINE INTELLIGENCE =====

        "CreatedOn", "JobStartDate", "ExpectedDate", "ClosedDate", "WorkOrderAgeInDays",

        // ===== FINANCIAL INTELLIGENCE =====

        "TotalEstLabor", "TotalActLabor", "TotalInvLabor", "TotalEstHours", "EstimatedHours",

        "InvoiceDocumentNumber", "InvoiceTotal",

        // ===== JOB & SERVICE INTELLIGENCE =====

        "JobCount", "RevenueJobCount", "FieldServiceJobCount",

        // ===== STATUS & PROGRESS INTELLIGENCE =====

        "ProgressStatus", "IsQuotation", "IsFieldService", "IsClosed",

        // ===== COMPREHENSIVE ANALYTICS =====

        "LaborEfficiency", "WorkOrderValueCategory", "ServiceComplexity",

        "PerformanceCategory", "FinancialPerformance",

        // ===== OPERATIONAL FLAGS =====

        "IsHighValue", "IsComplexService", "IsPerformanceExcellence",

        "IsRevenueOptimization", "IsCrossFactReady",

        // ===== DATA QUALITY & AUDIT =====

        "DataQualityScore", "ModifiedDate", "CreatedBy"

    }),

    // ========================================================================

    // STEP 15: FINAL DATA TYPE OPTIMIZATION

    // ========================================================================

    /*

    PURPOSE: Ensure optimal data types for comprehensive analytics performance and memory efficiency

    BUSINESS LOGIC: Appropriate data types for each column based on comprehensive reporting needs

    BENEFIT: Optimal performance and minimal memory footprint for comprehensive work order analytics

    */

    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {

        // Dimension keys

        {"BranchKey", Int64.Type}, {"CustomerKey", Int64.Type}, {"VehicleKey", Int64.Type},

        {"JobCodeKey", Int64.Type}, {"StatusKey", Int64.Type},

        {"DimWorkOrderKey", type text}, {"CreatedDateKey", Int64.Type},

        {"ExpectedDateKey", Int64.Type}, {"ClosedDateKey", Int64.Type},

        // Core identifiers

        {"Branch", type text}, {"WorkOrder", type text}, {"Registration", type text},

        {"StockNumber", type text}, {"AccountNumber", type text}, {"PrimaryJobCode", type text},

        {"PrimaryJobType", type text}, {"PrimaryJobValue", type number},

        // Enhanced intelligence

        {"Franchise", type text}, {"Odometer", Int64.Type}, {"AccountClass", type text},

        {"AuthorizationValue", type number}, {"Salesperson", type text}, {"PaymentMethod", type text},

        {"TaxRegion", type text}, {"ServiceTypeClassification", type text}, {"CustomerClassification", type text},

        // Timeline intelligence

        {"CreatedOn", type datetime}, {"JobStartDate", type datetime}, {"ExpectedDate", type datetime},

        {"ClosedDate", type datetime}, {"WorkOrderAgeInDays", type number},

        // Financial intelligence

        {"TotalEstLabor", Currency.Type}, {"TotalActLabor", Currency.Type}, {"TotalInvLabor", Currency.Type},

        {"TotalEstHours", type number}, {"EstimatedHours", type number}, {"InvoiceDocumentNumber", type text},

        {"InvoiceTotal", Currency.Type},

        // Job & service intelligence

        {"JobCount", Int64.Type}, {"RevenueJobCount", Int64.Type}, {"FieldServiceJobCount", Int64.Type},

        // Status & progress

        {"ProgressStatus", type text}, {"IsQuotation", type logical},

        {"IsFieldService", type logical}, {"IsClosed", type logical},

        // Comprehensive analytics

        {"LaborEfficiency", type number}, {"WorkOrderValueCategory", type text}, {"ServiceComplexity", type text},

        {"PerformanceCategory", type text}, {"FinancialPerformance", type text},

        // Operational flags

        {"IsHighValue", type logical}, {"IsComplexService", type logical}, {"IsPerformanceExcellence", type logical},

        {"IsRevenueOptimization", type logical}, {"IsCrossFactReady", type logical},

        // Data quality and audit

        {"DataQualityScore", type number}, {"ModifiedDate", type datetime}, {"CreatedBy", type text}

    })

  

in

    FinalDataTypes