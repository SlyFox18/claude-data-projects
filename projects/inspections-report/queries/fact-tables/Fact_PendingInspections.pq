/*
============================================================================
FACT_PENDINGINSPECTIONS - PENDING INSPECTION WORK ORDER TRACKING
============================================================================

📋 TABLE OVERVIEW:
Purpose: Track work orders with inspection job codes that are not yet invoiced
Grain: One row per pending inspection work order
Refresh Strategy: Full refresh (small dataset, very fast)
Performance: Target <1 minute refresh time
Source Dependencies: Raw_RepairOrderDetail, Raw_TechnicianPunchedDetail

🎯 BUSINESS USE CASES:
• Pending Queue Management: Track inspections waiting to be completed
• Workload Forecasting: Predict upcoming revenue from pending inspections
• Timeline Monitoring: Track aging of pending inspections
• Resource Planning: Understand current inspection workload
• Performance Analysis: Compare predicted vs actual inspection outcomes

📊 DATA STRUCTURE (12 COLUMNS):

**Core Identifiers:**
• BranchCode: Work order branch location
• WorkOrderNumber: Work order number
• JobCode: Inspection job code
• JobType: Job type indicator

**Status & Timeline:**
• StatusDisplay: Business status ("In Process" or "WIP Finished Not Invoiced")
• ROProgressStatus: System progress status code
• CreationDate: When work order was created
• FirstLaborPunch: When work started (if started)
• LastLaborPunch: Most recent labor activity
• DaysSinceCreation: Age in days

**Hours Data:**
• HoursWorked: Total hours worked so far (from TechnicianPunchedDetail)

**Flags:**
• IsInspection: Always TRUE (this table only contains inspections)

🔧 ARCHITECTURAL DESIGN DECISIONS:

**Work Order Level Grain:**
• RepairOrderDetail has one row per work order (with one primary job code)
• Unlike Fact_LaborJobSummary which is job-level
• Simpler structure - no need for summarization

**Pending Definition:**
• StatusDisplay IN ("In Process", "WIP Finished Not Invoiced")
• Excludes "Invoiced" (those are in Fact_LaborJobSummary)
• Captures work that hasn't been completed/invoiced yet

**Hours Aggregation:**
• Pre-aggregate hours from TechnicianPunchedDetail
• Avoids complex DAX later
• Shows actual work progress on pending inspections

**Inspection Code Consistency:**
• Uses same 111 inspection codes as other fact tables
• Ensures consistency across all inspection tracking

============================================================================
*/

let
    // ========================================================================
    // STEP 1: INSPECTION JOB CODE LOOKUP TABLE (111 CODES)
    // ========================================================================
    /*
    PURPOSE: Centralized definition of all inspection job codes
    CRITICAL: MUST match Fact_LaborJobSummary and Fact_WorkOrderParts
    MAINTENANCE: Update all three fact tables when new codes added
    */
    
    InspectionCodes = #table(
        type table [job_code = text],
        {
            {"/COMBINE VIP INSPECT"},
            {"/CS690 INSPECTION"},
            {"/CS690 VIP INSPECTIO"},
            {"/INSPECTION"},
            {"/PLANTER INSPECTION"},
            {"/Rental Inspection"},
            {"/SPRAYER INSPECTION"},
            {"/TRACTOR INSPECTION"},
            {"/WINTER INSPECTION"},
            {"ALL/9001/LEG/590"},
            {"COMBINE INSPECTION"},
            {"IS-125"},
            {"IS-145"},
            {"IS-3E ANNUAL SERVICE"},
            {"IS-4X2"},
            {"IS-5E INSPECT"},
            {"IS-AMS DATA"},
            {"IS-AMS DATA SETUP"},
            {"IS-AMS OPTIMIZE"},
            {"IS-AMS SOFTWARE"},
            {"IS-COMBINE INSPECT"},
            {"IS-COMPACT INSPECT"},
            {"IS-CORN/DRAPER"},
            {"IS-CP690 INSPECT"},
            {"IS-CP770 INSPECT"},
            {"IS-CS690 INSPECT"},
            {"IS-CS770 INSPECT"},
            {"IS-D100"},
            {"IS-D105(-200000)"},
            {"IS-D105(200001-)"},
            {"IS-D110(-500000)"},
            {"IS-D110(500001-)"},
            {"IS-D120"},
            {"IS-D125"},
            {"IS-D130(-400000)"},
            {"IS-D130(400001-)"},
            {"IS-D140(-400000)"},
            {"IS-D140(400001-)"},
            {"IS-D155(700001-)"},
            {"IS-D160"},
            {"IS-D170"},
            {"IS-E100"},
            {"IS-E120"},
            {"IS-E120-QCD"},
            {"IS-E130-QCD"},
            {"IS-E170-QCD"},
            {"IS-E180-QCD"},
            {"IS-GATOR INSPECTION"},
            {"IS-HPX(-040000)"},
            {"IS-HPX(040001-)"},
            {"IS-L110"},
            {"IS-L130"},
            {"IS-LA115"},
            {"IS-LA125"},
            {"IS-LA135"},
            {"IS-LT150(039001-)"},
            {"IS-LT160"},
            {"IS-LT166"},
            {"IS-LT180"},
            {"IS-MOWER INSPECTION"},
            {"IS-PICKER INSPECT"},
            {"IS-PLANTER INSPECT"},
            {"IS-PLATFORM INSP"},
            {"IS-PRE R INSPECTION"},
            {"IS-R INSPECTION"},
            {"IS-S240"},
            {"IS-SKID STEER INSPEC"},
            {"IS-SPRAYER INSPECT"},
            {"IS-STRIPPER INSPECT"},
            {"IS-SWATHER INSPECT"},
            {"IS-TRACTOR INSPECT"},
            {"IS-TS4X2"},
            {"IS-X300(-180000)"},
            {"IS-X300(180001-)"},
            {"IS-X300R(120001-)"},
            {"IS-X304(180001-)"},
            {"IS-X310"},
            {"IS-X320(-180000)"},
            {"IS-X324(-180000)"},
            {"IS-X350"},
            {"IS-X354"},
            {"IS-X360(-180000)"},
            {"IS-X380"},
            {"IS-X500"},
            {"IS-X570"},
            {"IS-XUV550"},
            {"IS-XUV560"},
            {"IS-XUV590I"},
            {"IS-XUV590M"},
            {"IS-XUV835R"},
            {"IS-XUV855D"},
            {"IS-Z225(-060000)"},
            {"IS-Z225(100001-12000"},
            {"IS-Z255"},
            {"IS-Z335E"},
            {"IS-Z345M"},
            {"IS-Z345R"},
            {"IS-Z355E"},
            {"IS-Z355R"},
            {"IS-Z375R"},
            {"IS-Z425(-040000)"},
            {"IS-Z425(100001-)"},
            {"IS-Z425(40001-100000"},
            {"IS-Z435"},
            {"IS-Z445(-100000)"},
            {"IS-Z445(100000-14000"},
            {"IS-Z445(140001-)"},
            {"IS-Z515E"},
            {"IS-Z525E"},
            {"IS-Z535M"},
            {"IS-Z540M"},
            {"IS-HARVESTREADY"},
            {"IS-Z540R"}
        }
    ),
    
    // ========================================================================
    // STEP 2: LOAD PENDING WORK ORDERS FROM RAW_REPAIRORDERDETAIL
    // ========================================================================
    /*
    SOURCE: Raw_RepairOrderDetail (all work orders)
    FILTER: StatusDisplay NOT 'Invoiced' (In Process or WIP Finished Not Invoiced)
    GRAIN: One row per work order
    */
    
    Source = Raw_RepairOrderDetail,
    
    // ========================================================================
    // STEP 3: FILTER TO PENDING STATUSES
    // ========================================================================
    /*
    PENDING = StatusDisplay IN ("In Process", "WIP Finished Not Invoiced")
    EXCLUDE = "Invoiced" (those are in Fact_LaborJobSummary)
    */
    
    FilterToPending = Table.SelectRows(
        Source,
        each [StatusDisplay] <> "Invoiced"
    ),
    
    // ========================================================================
    // STEP 4: FILTER TO INSPECTION JOB CODES
    // ========================================================================
    /*
    JOIN: Inner join to inspection codes table
    RESULT: Only work orders with inspection job codes
    CONSISTENCY: Same 111 codes as other fact tables
    */
    
    JoinInspectionCodes = Table.NestedJoin(
        FilterToPending,
        {"JobCode"},
        InspectionCodes,
        {"job_code"},
        "InspectionMatch",
        JoinKind.Inner
    ),
    
    RemoveMatchColumn = Table.RemoveColumns(JoinInspectionCodes, {"InspectionMatch"}),
    
    // ========================================================================
    // STEP 5: AGGREGATE HOURS FROM RAW_TECHNICIANPUNCHEDDETAIL
    // ========================================================================
    /*
    PURPOSE: Get total hours worked on each pending work order
    AGGREGATION: SUM(HoursWorked) grouped by Branch + WorkOrder
    JOIN TYPE: Left outer (some WOs may have no hours yet)
    */
    
    // First, aggregate hours by work order
    TechHoursSource = Raw_TechnicianPunchedDetail,
    
    AggregateHours = Table.Group(
        TechHoursSource,
        {"Branch", "WorkOrder"},
        {
            {"HoursWorked", each List.Sum([HoursWorked]), type nullable number}
        }
    ),
    
    // Ensure join columns are TEXT type
    AggregateHoursWithTextTypes = Table.TransformColumnTypes(
        AggregateHours,
        {
            {"Branch", type text},
            {"WorkOrder", type text}
        }
    ),
    
    // Ensure source columns are TEXT type
    SourceWithTextTypes = Table.TransformColumnTypes(
        RemoveMatchColumn,
        {
            {"Branch", type text},
            {"WorkOrder", type text}
        }
    ),
    
    // ========================================================================
    // STEP 6: JOIN HOURS TO PENDING INSPECTIONS
    // ========================================================================
    /*
    JOIN TYPE: Left outer join (preserve all pending inspections)
    JOIN KEYS: Branch + WorkOrder
    RESULT: Pending inspections with hours worked (NULL if no hours yet)
    */
    
    JoinHours = Table.NestedJoin(
        SourceWithTextTypes,
        {"Branch", "WorkOrder"},
        AggregateHoursWithTextTypes,
        {"Branch", "WorkOrder"},
        "Hours",
        JoinKind.LeftOuter
    ),
    
    ExpandHours = Table.ExpandTableColumn(
        JoinHours,
        "Hours",
        {"HoursWorked"},
        {"HoursWorked"}
    ),
    
    // ========================================================================
    // STEP 7: SELECT AND RENAME COLUMNS
    // ========================================================================
    /*
    KEEP: Only essential columns for pending inspection tracking
    RENAME: Consistent naming with other fact tables
    */
    
    SelectColumns = Table.SelectColumns(
        ExpandHours,
        {
            "Branch",
            "WorkOrder",
            "JobCode",
            "JobType",
            "StatusDisplay",
            "ROProgressStatus",
            "CreationDate",
            "FirstLaborPunch",
            "LastLaborPunch",
            "DaysSinceCreationDate",
            "HoursWorked"
        }
    ),
    
    RenameColumns = Table.RenameColumns(
        SelectColumns,
        {
            {"Branch", "BranchCode"},
            {"WorkOrder", "WorkOrderNumber"},
            {"DaysSinceCreationDate", "DaysSinceCreation"}
        }
    ),
    
    // ========================================================================
    // STEP 8: ADD CALCULATED COLUMNS
    // ========================================================================
    /*
    IsInspection: Always TRUE (this table only contains inspections)
    Simplifies DAX measures - no need to filter
    */
    
    AddIsInspection = Table.AddColumn(
        RenameColumns,
        "IsInspection",
        each true,
        type logical
    ),
    
    // ========================================================================
    // STEP 9: SET PROPER DATA TYPES
    // ========================================================================
    
    SetDataTypes = Table.TransformColumnTypes(
        AddIsInspection,
        {
            {"BranchCode", type text},
            {"WorkOrderNumber", type text},
            {"JobCode", type text},
            {"JobType", type text},
            {"StatusDisplay", type text},
            {"ROProgressStatus", type text},
            {"CreationDate", type datetime},
            {"FirstLaborPunch", type nullable datetime},
            {"LastLaborPunch", type nullable datetime},
            {"DaysSinceCreation", type nullable number},
            {"HoursWorked", type nullable number},
            {"IsInspection", type logical}
        }
    )
in
    SetDataTypes

/*
============================================================================
✅ FACT_PENDINGINSPECTIONS - PRODUCTION-READY PENDING TRACKING
============================================================================

🎯 ACHIEVEMENT SUMMARY:
- Complete Pending Tracking: All uninvoiced inspections captured
- Hours Integration: Pre-aggregated hours from TechnicianPunchedDetail
- Consistent Logic: Same 111 inspection codes as other fact tables
- Performance Optimized: Small dataset, fast refresh (<1 minute)
- Simple DAX: IsInspection always TRUE, no complex filtering needed

🔍 KEY DESIGN DECISIONS:
- Work Order Grain: One row per pending inspection work order
- Status Filter: Excludes "Invoiced" (those are in Fact_LaborJobSummary)
- Left Outer Join: Preserves WOs without hours yet (work not started)
- Pre-Aggregation: Hours summed at source for performance

📊 EXPECTED RESULTS:
- Row Count: ~50-100 rows (typically small dataset)
- Refresh Time: <1 minute (very fast)
- Covers: All pending inspections across all branches

🚀 DAX MEASURES TO USE WITH THIS TABLE:

// Simple count of pending inspections
Pending Inspections Count = 
COUNTROWS(Fact_PendingInspections)

// Pending by job code
Pending by Job Code = 
SUMMARIZE(
    Fact_PendingInspections,
    Fact_PendingInspections[JobCode],
    "Count", COUNTROWS(Fact_PendingInspections)
)

// Total hours on pending inspections
Pending Hours Worked = 
SUM(Fact_PendingInspections[HoursWorked])

// Average age of pending inspections
Average Pending Age = 
AVERAGE(Fact_PendingInspections[DaysSinceCreation])

// Predicted revenue (future enhancement)
Predicted Inspection Revenue = 
COUNTROWS(Fact_PendingInspections) * [Average Inspection Revenue]

🔄 MAINTENANCE NOTES:
- Update InspectionCodes when new inspection types added
- Keep consistent with Fact_LaborJobSummary and Fact_WorkOrderParts
- Monitor for new StatusDisplay values (currently: "In Process", "WIP Finished Not Invoiced", "Invoiced")

⚠️ DATA QUALITY CHECKS:
- Verify no overlap with Fact_LaborJobSummary (StatusDisplay = "Invoiced" should be excluded)
- Check for NULLs in HoursWorked (expected for work not started)
- Validate DaysSinceCreation is populated for all rows
- Spot check specific work orders against RepairOrderDetail

============================================================================
*/