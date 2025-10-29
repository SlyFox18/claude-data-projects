/*
============================================================================
DIM_WORKORDERMASTER - COMPREHENSIVE WORK ORDER REFERENCE DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Clean work order master reference for all fact table relationships
Grain: One row per work order (unique by Branch + WorkOrder)
Refresh Strategy: Full refresh (lightweight - under 2 minutes expected)
Current Performance: Optimized for fast fact table joins
Dependencies: Raw_WKROFILE, Raw_wkrodesc, Raw_WkInvReg, Raw_wkothsub

🎯 BUSINESS USE CASES:
• Work Order Identification: Consistent work order reference across all fact tables
• Customer Assignment: Intelligent customer linking with fallback logic
• Job Context: Primary job information for service type classification
• Labor Planning: Estimated vs actual hours for resource optimization
• Priority Management: Automatic priority scoring for resource allocation
• Field vs Shop Analysis: Service location distinction for operational planning
• Invoice Integration: Financial context and billing reference
• Equipment Context: Vehicle/equipment identification and tracking

📊 KEY INFORMATION PROVIDED:
• Work Order Identity: Branch, work order number, and composite keys
• Job Intelligence: Job counts, values, complexity scoring
• Labor Context: Estimated and actual hours/costs for primary job
• Priority Analytics: 0-100 priority scoring with business categories
• Customer Context: Dual approach - real customers + complete coverage
• Service Context: Field vs shop service with enhanced classification
• Financial Flags: High value identification and invoice status
• Timeline Intelligence: Age, overdue status, deadline tracking

🔗 FACT TABLE RELATIONSHIPS:
• Fact_WorkOrderParts → WorkOrderKey (parts transactions on work orders)
• Fact_WorkOrderLabor → WorkOrderKey (technician hours and labor costs)
• Fact_WorkOrderHeader → WorkOrderKey (comprehensive work order analytics)
• Fact_WarrantyClaims → WorkOrderKey (warranty claim integration)

📈 DASHBOARD IDEAS:
• Work Queue Dashboard: Priority-sorted work orders with resource allocation
• Operational Planning: Field vs shop resource optimization
• Customer Service: Account-based work order tracking and SLA monitoring
• Financial Analysis: High-value work order identification and management
• Performance Metrics: Labor planning accuracy and efficiency tracking

⚡ PERFORMANCE OPTIMIZATION NOTES:
• Expected refresh time: 1:45 to 2:15 minutes (enhanced from 1:24 base)
• Optimized joins using existing loaded data
• Calculated fields for intelligence without additional data loading
• Clean variable chain for reliable processing

============================================================================
*/

let
    // ========================================================================
    // STEP 1: WORK ORDER FOUNDATION FROM HEADER TABLE
    // ========================================================================
    /*
    PURPOSE: Establish core work order identification and context
    SOURCE: Raw_WKROFILE (work order header table)
    BUSINESS LOGIC: One work order per branch-workorder combination
    */
    
    // Get essential work order header information
    WorkOrderBase = Table.SelectColumns(Raw_WKROFILE, {
        "Branch",           // Location identifier for territory analysis
        "WorkOrder",        // Work order number (primary identifier)
        "CreatedOn",        // Work order creation timestamp
        "ExpectedDate",     // Promised completion date
        "ProgressStatus",   // Current workflow status (bi, va, wip, wf, etc.)
        "Registration",     // Vehicle registration for equipment lookup
        "StockNumber",      // Equipment stock number (alternative identifier)
        "AccountNumber",    // Customer account for billing and analysis
        "ModifiedDate"      // Last update timestamp for audit trail
    }),
    
    // Create standardized composite keys for reliable fact table relationships
    AddWorkOrderKeys = Table.AddColumn(
        Table.AddColumn(WorkOrderBase,
            "BranchWorkOrder", each [Branch] & "-" & Text.From([WorkOrder]), type text),
        "RONumber", each Text.From([WorkOrder]), type text),
    
    // ========================================================================
    // STEP 2: PRIMARY JOB CONTEXT INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Get main job information using line_no = 1 logic
    SOURCE: Raw_wkrodesc (job descriptions)
    BUSINESS LOGIC: Primary job represents the main reason for service
    */
    
    // Filter to primary job line only (line_no = 1)
    PrimaryJobs = Table.SelectRows(Raw_wkrodesc, each [LineNumber] = 1),
    
    // Prepare primary jobs for joining
    PrimaryJobsPrep = Table.AddColumn(
        Table.SelectColumns(PrimaryJobs, {
            "Branch", "WorkOrder", "JobCode", "JobType", "JobValue"
        }),
        "BranchWorkOrder", each [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Join primary job information to work order base
    JoinPrimaryJob = Table.NestedJoin(
        AddWorkOrderKeys, {"BranchWorkOrder"}, 
        PrimaryJobsPrep, {"BranchWorkOrder"}, 
        "PrimaryJob", JoinKind.LeftOuter),
    
    // Extract primary job details
    ExpandPrimaryJob = Table.ExpandTableColumn(JoinPrimaryJob, "PrimaryJob", 
        {"JobCode", "JobType", "JobValue"}, 
        {"PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue"}),
    
    // ========================================================================
    // STEP 3: JOB SUMMARY AGGREGATION (HIGH VALUE, LOW COST)
    // ========================================================================
    /*
    PURPOSE: Calculate total job metrics for work order complexity analysis
    SOURCE: Raw_wkrodesc (already loaded - minimal performance impact)
    BUSINESS VALUE: Work order complexity, resource planning, service classification
    */
    
    // Aggregate all jobs per work order for comprehensive metrics
    JobSummaryMetrics = Table.Group(Raw_wkrodesc, {"Branch", "WorkOrder"}, {
        {"TotalJobCount", each Table.RowCount(_), Int64.Type},
        {"TotalJobValue", each List.Sum([JobValue]), type number},
        {"JobTypeList", each Text.Combine(List.Distinct([JobType]), ", "), type text}
    }),
    
    // Add work order key for joining
    JobSummaryWithKey = Table.AddColumn(JobSummaryMetrics, "BranchWorkOrder", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Join job summary metrics to main dimension
    JoinJobSummary = Table.NestedJoin(
        ExpandPrimaryJob, {"BranchWorkOrder"}, 
        JobSummaryWithKey, {"BranchWorkOrder"}, 
        "JobSummary", JoinKind.LeftOuter),
    
    // Extract job summary information
    ExpandJobSummary = Table.ExpandTableColumn(JoinJobSummary, "JobSummary", 
        {"TotalJobCount", "TotalJobValue", "JobTypeList"}),
    
    // ========================================================================
    // STEP 4: LABOR CONTEXT FROM PRIMARY JOB
    // ========================================================================
    /*
    PURPOSE: Add labor context for resource planning and efficiency analysis
    SOURCE: Raw_wkothsub (already loaded - minimal performance impact)
    BUSINESS VALUE: Planning accuracy, efficiency tracking, resource allocation
    */
    
    // Get labor information for primary job only
    PrimaryJobLabor = Table.SelectColumns(Raw_wkothsub, {
        "Branch", "WorkOrder", "JobCode", "JobType", "EstHours", "EstLabor", "ActLabor", "FieldRepair"
    }),
    
    // Add work order key for joining
    PrimaryJobLaborWithKey = Table.AddColumn(PrimaryJobLabor, "BranchWorkOrder", each 
        [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Join labor context for primary job
    JoinPrimaryLabor = Table.NestedJoin(
        ExpandJobSummary, {"BranchWorkOrder", "PrimaryJobCode", "PrimaryJobType"}, 
        PrimaryJobLaborWithKey, {"BranchWorkOrder", "JobCode", "JobType"}, 
        "PrimaryJobLabor", JoinKind.LeftOuter),
    
    // Extract primary job labor information including field repair
    ExpandPrimaryLabor = Table.ExpandTableColumn(JoinPrimaryLabor, "PrimaryJobLabor", 
        {"EstHours", "EstLabor", "ActLabor", "FieldRepair"}, 
        {"PrimaryEstHours", "PrimaryEstLabor", "PrimaryActLabor", "FieldRepair"}),
    
    // ========================================================================
    // STEP 5: INVOICE CONTEXT FOR FINANCIAL INTEGRATION
    // ========================================================================
    /*
    PURPOSE: Add invoice context for financial analysis and parts linkage
    SOURCE: Raw_WkInvReg (invoice register)
    BUSINESS LOGIC: Get latest invoice information per work order
    */
    
    // Prepare invoice data with work order key
    InvoicePrep = Table.AddColumn(
        Table.SelectColumns(Raw_WkInvReg, {
            "Branch", "WorkOrder", "InvoiceNumber", "WorkDate"
        }),
        "BranchWorkOrder", each [Branch] & "-" & Text.From([WorkOrder]), type text),
    
    // Get latest invoice per work order
    LatestInvoices = Table.Group(InvoicePrep, {"BranchWorkOrder"}, {
        {"LatestInvoiceNumber", each List.Last(List.Sort([InvoiceNumber])), type text},
        {"LatestInvoiceDate", each List.Max([WorkDate]), type datetime}
    }),
    
    // Join invoice context
    JoinInvoice = Table.NestedJoin(
        ExpandPrimaryLabor, {"BranchWorkOrder"}, 
        LatestInvoices, {"BranchWorkOrder"}, 
        "InvoiceInfo", JoinKind.LeftOuter),
    
    // Extract invoice information
    ExpandInvoice = Table.ExpandTableColumn(JoinInvoice, "InvoiceInfo", 
        {"LatestInvoiceNumber", "LatestInvoiceDate"}, 
        {"InvoiceNumber", "InvoiceDate"}),
    
    // ========================================================================
    // STEP 6: CUSTOMER DATA CLEANING AND ASSIGNMENT
    // ========================================================================
    /*
    PURPOSE: Clean account numbers and implement intelligent customer assignment
    BUSINESS LOGIC: Dual approach - real customers + complete coverage
    */
    
    // Clean the existing AccountNumber field to remove decimal formatting
    CleanAccountNumber = Table.TransformColumns(ExpandInvoice, {
        {"AccountNumber", each 
            if _ <> null and _ <> "" then
                let
                    // Convert to text and handle decimal format (54946.000000 → 54946)
                    accountText = Text.From(_),
                    // Remove trailing decimal zeros
                    cleanedText = Text.Replace(Text.Replace(Text.Replace(Text.Replace(
                        accountText, ".000000", ""), ".00000", ""), ".0000", ""), ".000", "")
                in
                    Text.Upper(Text.Trim(cleanedText))
            else null, type text}
    }),
    
    // Create comprehensive customer identifier with fallback logic
    AddCustomerIdentifier = Table.AddColumn(CleanAccountNumber, "CustomerIdentifier", each
        let
            // Use cleaned account number
            cleanAccount = [AccountNumber],
            // Get job type for fallback logic
            jobType = Text.Lower(Text.Trim([PrimaryJobType] ?? ""))
        in
            // Primary assignment: Use actual customer account number
            if cleanAccount <> null then cleanAccount
            // Fallback assignment: Map job types to standard categories
            else if jobType = "i" then "INTERNAL"      // Internal work
            else if jobType = "w" then "WARRANTY"      // Warranty claims
            else if jobType = "f" then "FLEET"         // Fleet customers
            else if jobType = "e" then "EXCESS"        // Excess inventory
            else if jobType = "p" then "POLICY"        // Policy work
            else if jobType = "b" then "BILLING"       // Billing adjustments
            else if jobType = "s" then "MISC"          // Miscellaneous
            else "UNKNOWN",                            // Catch-all
        type text),
    
    // ========================================================================
    // STEP 7: SERVICE LOCATION AND EQUIPMENT LOGIC
    // ========================================================================
    /*
    PURPOSE: Add service location context and equipment identification
    BUSINESS VALUE: Field vs shop analysis and asset tracking
    */
    
    // Convert field repair flag to business-friendly format
    AddServiceLocation = Table.AddColumn(AddCustomerIdentifier, "ServiceLocation", each
        if Text.Upper([FieldRepair] ?? "N") = "Y" then "Field Service"
        else "Shop Service", type text),
    
    // Add field repair boolean flag
    AddIsFieldRepair = Table.AddColumn(AddServiceLocation, "IsFieldRepair", each
        Text.Upper([FieldRepair] ?? "N") = "Y", type logical),
    
    // Create standardized equipment identifier
    AddEquipmentIdentifier = Table.AddColumn(AddIsFieldRepair, "EquipmentIdentifier", each
        if [Registration] <> null and [Registration] <> "" then 
            Text.Upper(Text.Trim([Registration]))
        else if [StockNumber] <> null and [StockNumber] <> "" then 
            "Stk# " & Text.Trim(Text.From([StockNumber]))
        else null, type text),
    
    // ========================================================================
    // STEP 8: WORK ORDER INTELLIGENCE (CALCULATED FIELDS)
    // ========================================================================
    /*
    PURPOSE: Add automatic work order intelligence and priority scoring
    PERFORMANCE: Zero cost - pure calculations on existing data
    */
    
    // Calculate work order age in days
    AddWorkOrderAge = Table.AddColumn(AddEquipmentIdentifier, "WorkOrderAge", each 
        if [CreatedOn] <> null then 
            Duration.Days(DateTime.LocalNow() - [CreatedOn]) 
        else null, type number),
    
    // Calculate days until expected completion
    AddDaysUntilExpected = Table.AddColumn(AddWorkOrderAge, "DaysUntilExpected", each 
        if [ExpectedDate] <> null then 
            Duration.Days([ExpectedDate] - DateTime.LocalNow()) 
        else null, type number),
    
    // Add completion status flag
    AddIsCompleted = Table.AddColumn(AddDaysUntilExpected, "IsCompleted", each
        Text.Upper([ProgressStatus] ?? "") = "VP", type logical),
    
    // Identify overdue work orders
    AddIsOverdue = Table.AddColumn(AddIsCompleted, "IsOverdue", each 
        if [ExpectedDate] <> null then 
            [ExpectedDate] < DateTime.LocalNow() and [IsCompleted] = false
        else false, type logical),
    
    // Calculate work order complexity score
    AddComplexityScore = Table.AddColumn(AddIsOverdue, "ComplexityScore", each
        let
            jobCount = [TotalJobCount] ?? 1,
            jobValue = [TotalJobValue] ?? 0,
            isField = [IsFieldRepair] = true
        in
            if jobCount >= 5 or jobValue > 5000 or isField then "High"
            else if jobCount >= 3 or jobValue > 1000 then "Medium"  
            else "Low", type text),
    
    // Calculate priority score (0-100 algorithm)
    AddPriorityScore = Table.AddColumn(AddComplexityScore, "PriorityScore", each
        let
            // Age component (0-40 points)
            AgeScore = if ([WorkOrderAge] ?? 0) > 30 then 40
                      else if ([WorkOrderAge] ?? 0) > 14 then 30
                      else if ([WorkOrderAge] ?? 0) > 7 then 20
                      else if ([WorkOrderAge] ?? 0) > 3 then 10
                      else 5,
            
            // Overdue component (0-30 points)
            OverdueScore = if ([IsOverdue] ?? false) = true then 30 else 0,
            
            // Customer component (0-20 points)
            CustomerScore = if [AccountNumber] <> null then 20
                           else if [CustomerIdentifier] = "WARRANTY" then 15
                           else if [CustomerIdentifier] = "INTERNAL" then 5
                           else 10,
            
            // Value component (0-10 points)
            ValueScore = if ([TotalJobValue] ?? 0) > 5000 then 10
                        else if ([TotalJobValue] ?? 0) > 2000 then 7
                        else if ([TotalJobValue] ?? 0) > 500 then 5
                        else 2
        in
            AgeScore + OverdueScore + CustomerScore + ValueScore,
        type number),
    
    // Convert priority score to business-friendly categories
    AddPriorityCategory = Table.AddColumn(AddPriorityScore, "PriorityCategory", each
        if ([PriorityScore] ?? 0) >= 70 then "Critical"
        else if ([PriorityScore] ?? 0) >= 50 then "High"
        else if ([PriorityScore] ?? 0) >= 30 then "Medium"
        else "Low", type text),
    
    // ========================================================================
    // STEP 9: BUSINESS INTELLIGENCE CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Add comprehensive business intelligence categorization
    SCOPE: Enhanced categorization leveraging all available data
    */
    
    // Work order status categorization
    AddStatusCategory = Table.AddColumn(AddPriorityCategory, "StatusCategory", each
        let status = Text.Lower([ProgressStatus] ?? "")
        in if List.Contains({"bi", "va"}, status) then "In Queue"
           else if List.Contains({"wip", "wf"}, status) then "In Progress"
           else if List.Contains({"iv", "ca", "vp"}, status) then "Completed"
           else "Other", type text),
    
    // Enhanced work order classification
    AddWorkOrderClass = Table.AddColumn(AddStatusCategory, "WorkOrderClass", each
        let 
            jobType = Text.Lower([PrimaryJobType] ?? ""),
            isField = [IsFieldRepair] = true,
            complexity = [ComplexityScore] ?? "Low"
        in 
            if jobType = "w" and isField and complexity = "High" then "Complex Field Warranty"
            else if jobType = "w" and isField then "Field Warranty"
            else if jobType = "w" then "Shop Warranty"
            else if jobType = "i" then "Internal"
            else if jobType = "r" and isField and complexity = "High" then "Complex Field Retail"
            else if jobType = "r" and isField then "Field Retail"
            else if jobType = "r" then "Shop Retail"
            else if jobType = "f" and isField then "Field Fleet"
            else if jobType = "f" then "Shop Fleet"
            else if isField then "Field General"
            else "Shop General", type text),
    
    // Financial intelligence flags
    AddHasInvoice = Table.AddColumn(AddWorkOrderClass, "HasInvoice", each 
        [InvoiceNumber] <> null and [InvoiceNumber] <> "", type logical),
    
    AddIsHighValue = Table.AddColumn(AddHasInvoice, "IsHighValue", each 
        ([TotalJobValue] ?? 0) >= 2000, type logical),
    
    // ========================================================================
    // STEP 10: SURROGATE KEY AND DISPLAY NAME
    // ========================================================================
    /*
    PURPOSE: Add surrogate key and create enhanced display name
    STRUCTURE: Keys first, then organize columns for optimal usage
    */
    
    // Add surrogate key for dimension relationships
    AddSurrogateKey = Table.AddIndexColumn(AddIsHighValue, "WorkOrderKey", 1, 1, Int64.Type),
    
    // Create enhanced display name with intelligence indicators
    AddDisplayName = Table.AddColumn(AddSurrogateKey, "WorkOrderDisplayName", each
        let
            baseDisplay = [Branch] & " - " & [RONumber],
            equipmentInfo = if [EquipmentIdentifier] <> null then " (" & [EquipmentIdentifier] & ")" else "",
            serviceInfo = if [IsFieldRepair] = true then " [Field]" else " [Shop]",
            priorityInfo = if ([PriorityCategory] ?? "") = "Critical" then " ⚠️" 
                          else if ([PriorityCategory] ?? "") = "High" then " ❗" 
                          else ""
        in
            baseDisplay & equipmentInfo & serviceInfo & priorityInfo, type text),
    
    // ========================================================================
    // STEP 11: DEDUPLICATION AND FINAL COLUMN SELECTION
    // ========================================================================
    /*
    PURPOSE: Ensure dimension integrity and organize final output
    QUALITY: Critical for reliable fact table relationships
    */
    
    // Ensure one record per work order
    Deduplicated = Table.Distinct(AddDisplayName, {"BranchWorkOrder"}),
    
    // Select final columns in logical order
    FinalColumns = Table.SelectColumns(Deduplicated, {
        // ===== PRIMARY KEYS & IDENTIFIERS =====
        "WorkOrderKey",             // Surrogate key for fact table relationships
        "BranchWorkOrder",          // Composite natural key
        "Branch",                   // Location identifier
        "WorkOrder",                // Work order number
        "RONumber",                 // Work order as text (for InTrans linkage)
        "WorkOrderDisplayName",     // Human-readable identifier with intelligence
        
        // ===== TIMELINE INFORMATION =====
        "CreatedOn",                // Work order creation date
        "ExpectedDate",             // Promised completion date
        "ProgressStatus",           // Current workflow status
        "StatusCategory",           // Business-friendly status grouping
        
        // ===== PRIMARY JOB CONTEXT =====
        "PrimaryJobCode",           // Main job code
        "PrimaryJobType",           // Main job type
        "PrimaryJobValue",          // Main job value
        "WorkOrderClass",           // Enhanced job-based classification
        
        // ===== JOB SUMMARY INTELLIGENCE =====
        "TotalJobCount",            // Total jobs on work order
        "TotalJobValue",            // Total value of all jobs
        "JobTypeList",              // List of all job types on work order
        "ComplexityScore",          // High/Medium/Low complexity
        
        // ===== LABOR CONTEXT =====
        "PrimaryEstHours",          // Estimated hours for primary job
        "PrimaryEstLabor",          // Estimated labor cost for primary job
        "PrimaryActLabor",          // Actual labor cost for primary job
        
        // ===== SERVICE CONTEXT =====
        "ServiceLocation",          // Field Service vs Shop Service
        "IsFieldRepair",            // Field repair flag for filtering
        
        // ===== WORK ORDER INTELLIGENCE =====
        "WorkOrderAge",             // Age in days
        "DaysUntilExpected",        // Days to deadline
        "IsOverdue",                // Past deadline flag
        "PriorityScore",            // 0-100 priority algorithm
        "PriorityCategory",         // Critical/High/Medium/Low
        
        // ===== CUSTOMER CONTEXT (DUAL APPROACH) =====
        "AccountNumber",            // Clean customer account number (real customers only)
        "CustomerIdentifier",       // Account + fallback categories (complete analysis)
        "Registration",             // Vehicle registration
        "StockNumber",              // Equipment stock number
        "EquipmentIdentifier",      // Standardized equipment ID
        
        // ===== FINANCIAL CONTEXT =====
        "InvoiceNumber",            // Latest invoice number
        "InvoiceDate",              // Latest invoice date
        "HasInvoice",               // Invoice availability flag
        "IsHighValue",              // High value work order flag
        
        // ===== BUSINESS FLAGS =====
        "IsCompleted",              // Completion status flag
        
        // ===== AUDIT INFORMATION =====
        "ModifiedDate"              // Last update timestamp
    }),
    
    // ========================================================================
    // STEP 12: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    */
    
    FinalDataTypes = Table.TransformColumnTypes(FinalColumns, {
        // Keys and identifiers
        {"WorkOrderKey", Int64.Type}, {"BranchWorkOrder", type text}, {"Branch", type text},
        {"WorkOrder", Int64.Type}, {"RONumber", type text}, {"WorkOrderDisplayName", type text},
        
        // Timeline information
        {"CreatedOn", type datetime}, {"ExpectedDate", type datetime}, 
        {"ProgressStatus", type text}, {"StatusCategory", type text},
        
        // Primary job context
        {"PrimaryJobCode", type text}, {"PrimaryJobType", type text}, {"PrimaryJobValue", type number},
        {"WorkOrderClass", type text},
        
        // Job summary intelligence
        {"TotalJobCount", Int64.Type}, {"TotalJobValue", type number}, {"JobTypeList", type text},
        {"ComplexityScore", type text},
        
        // Labor context
        {"PrimaryEstHours", type number}, {"PrimaryEstLabor", type number}, 
        {"PrimaryActLabor", type number},
        
        // Service context
        {"ServiceLocation", type text}, {"IsFieldRepair", type logical},
        
        // Work order intelligence
        {"WorkOrderAge", type number}, {"DaysUntilExpected", type number}, {"IsOverdue", type logical},
        {"PriorityScore", type number}, {"PriorityCategory", type text},
        
        // Customer context (dual approach)
        {"AccountNumber", type text}, {"CustomerIdentifier", type text},
        {"Registration", type text}, {"StockNumber", type text}, {"EquipmentIdentifier", type text},
        
        // Financial context
        {"InvoiceNumber", type text}, {"InvoiceDate", type datetime}, 
        {"HasInvoice", type logical}, {"IsHighValue", type logical},
        
        // Flags and audit
        {"IsCompleted", type logical}, {"ModifiedDate", type datetime}
    })

in
    FinalDataTypes

/*
============================================================================
✅ ENHANCED DIM_WORKORDERMASTER - IMPLEMENTATION COMPLETE
============================================================================

🎯 IMMEDIATE BUSINESS VALUE:
• Priority-driven work queue management (0-100 scoring algorithm)
• Field vs Shop operational optimization
• Customer-focused service delivery (dual customer approach)
• Resource planning with labor estimates and complexity scoring
• Financial intelligence (high-value work order identification)
• Equipment tracking and asset management integration

📊 KEY INTELLIGENCE FEATURES:
• Automatic priority scoring considering age, customer, value, and overdue status
• Work order complexity classification (High/Medium/Low)
• Service location distinction (Field vs Shop) with enhanced categorization
• Job summary intelligence (counts, values, type distribution)
• Labor planning context (estimated vs actual for primary job)
• Customer assignment with fallback logic (real customers + operational categories)

🔗 FACT TABLE INTEGRATION READY:
• WorkOrderKey: Primary relationship for all fact tables
• BranchWorkOrder: Text-based lookups when needed
• AccountNumber: Real customer analysis (excludes internal/warranty)
• CustomerIdentifier: Complete operational analysis (includes all work types)
• Priority fields: Resource allocation and scheduling optimization

⚡ PERFORMANCE OPTIMIZED:
• Expected refresh time: 1:45 to 2:15 minutes
• Clean variable chain with no circular references
• Efficient use of already-loaded data
• Calculated intelligence fields with zero additional data loading

🚀 DASHBOARD OPPORTUNITIES:
• Work Queue: Sort by PriorityScore, filter by IsOverdue
• Operations: Group by ComplexityScore and ServiceLocation
• Customer Service: Filter by AccountNumber IS NOT NULL
• Financial: Filter by IsHighValue for premium work orders
• Planning: Use labor estimates for resource allocation

============================================================================
*/