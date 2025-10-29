/*
============================================================================
DIM_WORKORDERSTATUS - COMPREHENSIVE WORK ORDER STATUS & WORKFLOW DIMENSION
============================================================================

📋 TABLE OVERVIEW:
Purpose: Central work order status dimension for workflow analysis and process optimization
Grain: One row per unique work order status with complete workflow intelligence
Refresh Strategy: Derived from Raw_WorkOrderFile distinct status values
Dependencies: Raw_WorkOrderFile (ProgressStatus field)
Key Integration: StatusKey enables fact table relationships, StatusCode matches operational data

🎯 BUSINESS USE CASES:
• Workflow Analysis: End-to-end work order progression tracking and bottleneck identification
• Process Optimization: Cycle time analysis and workflow efficiency measurement
• Operational Management: Real-time status monitoring and capacity planning
• Customer Communication: Professional status updates and service progress reporting
• Performance Metrics: Completion rates, cycle times, and workflow stage analysis
• Business Intelligence: Predictive analytics for service delivery and resource planning

📊 KEY FEATURES PROVIDED:
• Complete Workflow Mapping: All status codes with business-friendly descriptions
• Workflow Progression: Logical ordering and phase classification for process analysis
• Business Intelligence: Active/completed/billable flags for operational metrics
• Professional Communication: Display names ready for customer communications
• Process Categories: Administrative, Operational, Financial classification
• Workflow Phases: Intake → Service → Complete → Closed progression tracking

🔗 CRITICAL INTEGRATION POINTS:
• Fact_WorkOrderHeader: StatusKey enables workflow progression analysis
• Work Order Reports: Professional status names for customer communications
• Process Analytics: Workflow phase and category analysis for optimization
• Performance Dashboards: IsActive, IsCompleted, IsBillable flags for KPI tracking
• Customer Portals: StatusDisplayName provides professional status updates

📈 WORKFLOW ANALYTICS STRATEGY:
• Status Progression: bi → va → wip → wf → iv → ca → vp (7-stage workflow)
• Phase Classification: Intake (1) → Service (2) → Complete (3) → Closed (4)
• Type Classification: Administrative → Operational → Financial workflow types
• Business Flags: Active status monitoring, completion tracking, billing readiness
• Performance Analysis: Workflow efficiency and bottleneck identification

⚡ PERFORMANCE OPTIMIZATION:
• Surrogate keys optimize fact table joins and workflow analysis queries
• StatusOrder enables efficient workflow progression reporting
• Business flags eliminate complex status logic in reporting queries
• Professional display names reduce runtime string manipulation
• Category classifications support efficient filtered analysis

🔧 OPERATIONAL GUIDELINES:
• Monitor status code consistency when new workflow stages added
• Review StatusOrder sequence when business process changes occur
• Validate business flag logic alignment with operational requirements
• Update display names to maintain professional customer communications
• Audit workflow progression logic for process optimization opportunities

============================================================================
📈 WORKFLOW MANAGEMENT & ANALYTICS RECOMMENDATIONS
============================================================================

⚙️ WORKFLOW ANALYTICS DASHBOARDS:
• Process Flow: Visual workflow progression with cycle time analysis
• Bottleneck Analysis: Status duration and queue depth monitoring
• Completion Metrics: Workflow stage completion rates and efficiency tracking
• Performance Comparison: Branch and technician workflow performance analysis

📊 OPERATIONAL APPLICATIONS:
• Real-Time Monitoring: Active work order status tracking and alert management
• Capacity Planning: Workflow stage workload distribution and resource allocation
• Customer Communications: Professional status updates and delivery expectations
• Process Improvement: Workflow bottleneck identification and optimization strategies

🔍 BUSINESS INTELLIGENCE OPPORTUNITIES:
• Predictive Analytics: Completion time estimation based on current status
• Seasonal Analysis: Workflow patterns and capacity requirements by time period
• Customer Satisfaction: Status progression speed correlation with satisfaction scores
• Resource Optimization: Workflow efficiency improvement through data-driven insights

============================================================================
*/

let
    // ========================================================================
    // STEP 1: FOUNDATION DATA EXTRACTION & STATUS DISCOVERY
    // ========================================================================
    /*
    PURPOSE: Extract unique work order status values from operational data
    BUSINESS LOGIC: Discover all status codes currently in use for comprehensive coverage
    DATA SOURCE: Raw_WorkOrderFile contains all work order status progressions
    */
    
    // Extract unique status values from work order operational data
    Source = Raw_WorkOrderFile,
    
    // Sort by status for consistent processing and logical grouping
    SortByStatus = Table.Sort(Source, {{"ProgressStatus", Order.Ascending}}),
    
    // ========================================================================
    // STEP 2: SURROGATE KEY GENERATION & UNIQUE IDENTIFICATION
    // ========================================================================
    /*
    PURPOSE: Create artificial primary key for optimal fact table relationships
    BUSINESS BENEFIT: Enables efficient star schema joins and workflow analysis
    */
    
    // Add surrogate key for optimal database performance and fact table joins
    AddSurrogateKey = Table.AddIndexColumn(SortByStatus, "StatusKey", 1, 1, Int64.Type),
    
    // Organize columns for logical business flow
    ReorderColumns = Table.ReorderColumns(AddSurrogateKey, {"StatusKey", "ProgressStatus"}),
    
    // ========================================================================
    // STEP 3: STATUS CODE STANDARDIZATION & LOOKUP KEY PREPARATION
    // ========================================================================
    /*
    PURPOSE: Create standardized status codes for reliable fact table lookups
    BUSINESS LOGIC: Lowercase, trimmed codes ensure consistent matching
    INTEGRATION: StatusCode field matches Fact_WorkOrderHeader StatusLookup logic
    */
    
    // Create standardized status code for reliable fact table joins
    AddStatusCode = Table.AddColumn(ReorderColumns, "StatusCode", each 
        Text.Lower(Text.Trim([ProgressStatus] ?? "")), type text),
    
    // ========================================================================
    // STEP 4: COMPREHENSIVE STATUS NAME MAPPING & BUSINESS DESCRIPTIONS
    // ========================================================================
    /*
    PURPOSE: Map technical status codes to professional business descriptions
    BUSINESS LOGIC: Matches exact mapping from complex SQL query for consistency
    CUSTOMER BENEFIT: Professional status names suitable for customer communications
    */
    
    // Professional status name mapping (matches original SQL query logic)
    AddStatusName = Table.AddColumn(AddStatusCode, "StatusName", each 
        let statusCode = [StatusCode] ?? ""
        in if statusCode = "bi" then "Booked-In"              // Initial work order creation
        else if statusCode = "va" then "Equipment Arrived"    // Equipment received for service
        else if statusCode = "wip" then "Work Commenced"      // Active service work started
        else if statusCode = "wf" then "Work Finished"        // Service work completed
        else if statusCode = "iv" then "Equipment Invoiced"   // Billing completed
        else if statusCode = "ca" then "Customer Advised"     // Customer notification sent
        else if statusCode = "vp" then "Equipment Picked-up"  // Work order closed
        else if statusCode = "wp" then "Work in Progress"     // Alternative work in progress code
        else if statusCode = "" then "Unknown"                // Handle missing status
        else Text.Proper(statusCode),                         // Fallback for new status codes
        type text),
    
    // ========================================================================
    // STEP 5: WORKFLOW CATEGORY CLASSIFICATION & PROCESS GROUPING
    // ========================================================================
    /*
    PURPOSE: Group status codes into logical workflow categories
    BUSINESS LOGIC: Intake → In Progress → Billing → Closed workflow progression
    ANALYTICS BENEFIT: Enables high-level workflow analysis and process optimization
    */
    
    // Workflow category classification for process analysis
    AddStatusCategory = Table.AddColumn(AddStatusName, "StatusCategory", each 
        let statusCode = [StatusCode] ?? ""
        in if statusCode = "bi" then "Intake"                      // Initial customer interaction
        else if List.Contains({"va", "wip", "wp", "wf"}, statusCode) then "In Progress"  // Active service delivery
        else if List.Contains({"iv", "ca"}, statusCode) then "Billing"      // Financial processing
        else if statusCode = "vp" then "Closed"                    // Completed service delivery
        else "Other",                                               // Unclassified status codes
        type text),
    
    // ========================================================================
    // STEP 6: WORKFLOW PROGRESSION ORDERING & SEQUENCE LOGIC
    // ========================================================================
    /*
    PURPOSE: Establish logical workflow sequence for progression analysis
    BUSINESS LOGIC: Numerical ordering enables workflow stage analysis and reporting
    ANALYTICS BENEFIT: Cycle time calculation and workflow efficiency measurement
    */
    
    // Logical workflow ordering for progression analysis and reporting
    AddStatusOrder = Table.AddColumn(AddStatusCategory, "StatusOrder", each 
        let statusCode = [StatusCode] ?? ""
        in if statusCode = "bi" then 1         // Stage 1: Booked-In
        else if statusCode = "va" then 2       // Stage 2: Equipment Arrived
        else if statusCode = "wip" then 3      // Stage 3: Work Commenced
        else if statusCode = "wp" then 3       // Stage 3: Work in Progress (equivalent to wip)
        else if statusCode = "wf" then 4       // Stage 4: Work Finished
        else if statusCode = "iv" then 5       // Stage 5: Equipment Invoiced
        else if statusCode = "ca" then 6       // Stage 6: Customer Advised
        else if statusCode = "vp" then 7       // Stage 7: Equipment Picked-up (Final)
        else 99,                               // Unordered: Other status codes
        type number),
    
    // ========================================================================
    // STEP 7: PROFESSIONAL DISPLAY NAME GENERATION FOR COMMUNICATIONS
    // ========================================================================
    /*
    PURPOSE: Create professional display names for customer-facing communications
    BUSINESS BENEFIT: Consistent, professional appearance in all customer reports
    FORMAT: "CODE - Description" provides both technical and business context
    */
    
    // Professional display name for customer communications and reports
    AddStatusDisplayName = Table.AddColumn(AddStatusOrder, "StatusDisplayName", each 
        Text.Upper([StatusCode] ?? "") & " - " & ([StatusName] ?? ""), type text),
    
    // ========================================================================
    // STEP 8: BUSINESS INTELLIGENCE FLAGS & OPERATIONAL INDICATORS
    // ========================================================================
    /*
    PURPOSE: Add sophisticated business flags for operational analytics
    BUSINESS LOGIC: Active, completed, billable flags enable advanced reporting
    PERFORMANCE BENEFIT: Eliminates complex status logic in fact table queries
    */
    
    // Active status indicator (work order still in progress)
    AddIsActive = Table.AddColumn(AddStatusDisplayName, "IsActive", each 
        ([StatusCode] ?? "") <> "vp",  // Only "Equipment Picked-up" is inactive
        type logical),
    
    // Completion status indicator (work is finished, may need billing/pickup)
    AddIsCompleted = Table.AddColumn(AddIsActive, "IsCompleted", each 
        List.Contains({"iv", "ca", "vp"}, [StatusCode] ?? ""),  // Billing and closure stages
        type logical),
    
    // Billable status indicator (ready for or completed billing)
    AddIsBillable = Table.AddColumn(AddIsCompleted, "IsBillable", each 
        List.Contains({"iv", "ca", "vp"}, [StatusCode] ?? ""),  // Financial processing stages
        type logical),
    
    // ========================================================================
    // STEP 9: ADVANCED WORKFLOW PHASE CLASSIFICATION
    // ========================================================================
    /*
    PURPOSE: Higher-level workflow phase grouping for strategic analysis
    BUSINESS LOGIC: 4-phase workflow model for executive reporting
    STRATEGIC BENEFIT: Enables high-level process analysis and resource planning
    */
    
    // High-level workflow phase classification for strategic analysis
    AddWorkflowPhase = Table.AddColumn(AddIsBillable, "WorkflowPhase", each 
        let statusCode = [StatusCode] ?? ""
        in if statusCode = "bi" then "1-Intake"                    // Customer onboarding
        else if List.Contains({"va", "wip", "wp"}, statusCode) then "2-Service"     // Active service delivery
        else if statusCode = "wf" then "3-Complete"                // Service completion
        else if List.Contains({"iv", "ca", "vp"}, statusCode) then "4-Closed"      // Administrative closure
        else "5-Other",                                             // Unclassified workflow
        type text),
    
    // ========================================================================
    // STEP 10: STATUS TYPE CLASSIFICATION & OPERATIONAL CATEGORIZATION
    // ========================================================================
    /*
    PURPOSE: Classify status types by operational responsibility
    BUSINESS LOGIC: Administrative, Operational, Financial responsibility areas
    ORGANIZATIONAL BENEFIT: Enables department-specific performance analysis
    */
    
    // Status type classification by operational responsibility
    AddStatusType = Table.AddColumn(AddWorkflowPhase, "StatusType", each 
        let statusCode = [StatusCode] ?? ""
        in if List.Contains({"bi", "va"}, statusCode) then "Administrative"    // Front office responsibility
        else if List.Contains({"wip", "wp", "wf"}, statusCode) then "Operational"      // Service team responsibility
        else if List.Contains({"iv", "ca", "vp"}, statusCode) then "Financial"         // Billing team responsibility
        else "Other",                                                           // Unclassified responsibility
        type text),
    
    // ========================================================================
    // STEP 11: ADVANCED WORKFLOW INTELLIGENCE & ANALYTICS
    // ========================================================================
    /*
    PURPOSE: Add sophisticated workflow analytics for business intelligence
    BUSINESS BENEFIT: Advanced process optimization and predictive analytics
    */
    
    // Workflow progression indicator (early, middle, late stage)
    AddWorkflowProgression = Table.AddColumn(AddStatusType, "WorkflowProgression", each 
        let statusOrder = [StatusOrder] ?? 99
        in if statusOrder <= 2 then "Early Stage"           // Intake and arrival
        else if statusOrder <= 4 then "Active Stage"        // Service delivery
        else if statusOrder <= 7 then "Completion Stage"    // Closure activities
        else "Unclassified",                                 // Other statuses
        type text),
    
    // Customer interaction requirement indicator
    AddCustomerInteraction = Table.AddColumn(AddWorkflowProgression, "CustomerInteraction", each 
        let statusCode = [StatusCode] ?? ""
        in if List.Contains({"bi", "ca", "vp"}, statusCode) then "Required"    // Direct customer interaction
        else if List.Contains({"va", "iv"}, statusCode) then "Optional"        // Possible customer interaction
        else "Not Required",                                                    // Internal process only
        type text),
    
    // Service delivery phase indicator
    AddServicePhase = Table.AddColumn(AddCustomerInteraction, "ServicePhase", each 
        let statusCode = [StatusCode] ?? ""
        in if statusCode = "bi" then "Scheduling"           // Appointment scheduling
        else if statusCode = "va" then "Preparation"        // Service preparation
        else if List.Contains({"wip", "wp"}, statusCode) then "Execution"      // Active service
        else if statusCode = "wf" then "Quality Check"      // Service verification
        else if List.Contains({"iv", "ca", "vp"}, statusCode) then "Delivery"  // Service delivery
        else "Other",                                        // Unclassified phase
        type text),
    
    // Workflow risk indicator (based on typical bottleneck points)
    AddWorkflowRisk = Table.AddColumn(AddServicePhase, "WorkflowRisk", each 
        let statusCode = [StatusCode] ?? ""
        in if List.Contains({"wip", "wp"}, statusCode) then "High"     // Active work can have delays
        else if List.Contains({"va", "wf"}, statusCode) then "Medium"  // Transition points
        else "Low",                                                     // Administrative stages
        type text),
    
    // ========================================================================
    // STEP 12: DATA QUALITY ASSESSMENT & COMPLETENESS SCORING
    // ========================================================================
    /*
    PURPOSE: Evaluate status record completeness for operational readiness
    SCORING: 0-100 scale based on workflow intelligence completeness
    BUSINESS BENEFIT: Identify status codes needing enhanced business logic
    */
    
    AddDataQualityScore = Table.AddColumn(AddWorkflowRisk, "DataQualityScore", each
        let
            // Core identification (30 points max)
            hasStatusCode = if ([StatusCode] ?? "") <> "" then 15 else 0,
            hasStatusName = if ([StatusName] ?? "") <> "" and ([StatusName] ?? "") <> "Unknown" then 15 else 0,
            
            // Workflow classification (40 points max)
            hasCategory = if ([StatusCategory] ?? "") <> "Other" then 10 else 0,
            hasValidOrder = if ([StatusOrder] ?? 99) < 99 then 10 else 0,
            hasWorkflowPhase = if not Text.Contains([WorkflowPhase] ?? "", "Other") then 10 else 0,
            hasStatusType = if ([StatusType] ?? "") <> "Other" then 10 else 0,
            
            // Business intelligence (30 points max)
            hasProgression = if ([WorkflowProgression] ?? "") <> "Unclassified" then 10 else 0,
            hasServicePhase = if ([ServicePhase] ?? "") <> "Other" then 10 else 0,
            hasBusinessFlags = if [IsActive] <> null and [IsCompleted] <> null and [IsBillable] <> null then 10 else 0
        in
            hasStatusCode + hasStatusName + hasCategory + hasValidOrder + 
            hasWorkflowPhase + hasStatusType + hasProgression + hasServicePhase + hasBusinessFlags,
        type number),
    
    // ========================================================================
    // STEP 13: FINAL COLUMN SELECTION & ORGANIZATION
    // ========================================================================
    /*
    PURPOSE: Select and organize final columns for optimal reporting and analytics
    STRUCTURE: Keys, core data, workflow intelligence, business flags, analytics
    */
    
    SelectFinalColumns = Table.SelectColumns(AddDataQualityScore, {
        // ===== PRIMARY KEYS & CORE IDENTIFICATION =====
        "StatusKey",                    // Surrogate key for fact table joins
        "StatusCode",                   // Standardized status code for lookups
        "StatusName",                   // Professional business description
        "StatusDisplayName",            // Customer-facing display name
        
        // ===== WORKFLOW CLASSIFICATION =====
        "StatusCategory",               // High-level workflow grouping
        "WorkflowPhase",                // Strategic workflow phases
        "StatusType",                   // Operational responsibility classification
        "StatusOrder",                  // Logical workflow sequence
        
        // ===== BUSINESS INTELLIGENCE FLAGS =====
        "IsActive",                     // Work order activity indicator
        "IsCompleted",                  // Work completion indicator
        "IsBillable",                   // Billing readiness indicator
        
        // ===== ADVANCED WORKFLOW ANALYTICS =====
        "WorkflowProgression",          // Early/Active/Completion stage
        "CustomerInteraction",          // Customer interaction requirements
        "ServicePhase",                 // Detailed service delivery phase
        "WorkflowRisk",                 // Bottleneck risk assessment
        
        // ===== DATA QUALITY =====
        "DataQualityScore"              // Data completeness score (0-100)
    }),
    
    // ========================================================================
    // STEP 14: DATA TYPE OPTIMIZATION
    // ========================================================================
    /*
    PURPOSE: Optimize storage and query performance with appropriate data types
    STRATEGY: Consistent types for reliable joins and efficient analytics
    */
    
    SetDataTypes = Table.TransformColumnTypes(SelectFinalColumns, {
        // Keys and identification
        {"StatusKey", Int64.Type}, {"StatusCode", type text}, {"StatusName", type text}, 
        {"StatusDisplayName", type text},
        
        // Workflow classification
        {"StatusCategory", type text}, {"WorkflowPhase", type text}, {"StatusType", type text}, 
        {"StatusOrder", Int64.Type},
        
        // Business flags
        {"IsActive", type logical}, {"IsCompleted", type logical}, {"IsBillable", type logical},
        
        // Advanced analytics
        {"WorkflowProgression", type text}, {"CustomerInteraction", type text}, 
        {"ServicePhase", type text}, {"WorkflowRisk", type text},
        
        // Data quality
        {"DataQualityScore", type number}
    }),
    
    // ========================================================================
    // STEP 15: FINAL SORTING FOR CONSISTENT WORKFLOW ORDER
    // ========================================================================
    /*
    PURPOSE: Ensure consistent record ordering for reliable workflow analysis
    STRATEGY: Sort by StatusOrder for logical workflow progression display
    */
    
    FinalSort = Table.Sort(SetDataTypes, {{"StatusOrder", Order.Ascending}})

in
    FinalSort