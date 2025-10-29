// Fact_WorkOrderHeader - Work Order Snapshot Fact Table

// Grain: One row per work order (current status snapshot)

// Purpose: Core work order metrics and current status tracking

  

let

    // Incremental refresh parameters

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

    // STEP 1: Get base work order information

    BaseWorkOrders = Table.SelectColumns(Raw_wkrofile, {

        "Branch", "WorkOrder", "Registration", "StockNumber", "AccountNumber",

        "CreatedOn", "ExpectedDate", "ProgressStatus", "ModifiedDate", "Odometer"

    }),

    // Filter for incremental refresh

    FilteredWorkOrders = Table.SelectRows(BaseWorkOrders, each

        [ModifiedDate] >= RangeStart and [ModifiedDate] < RangeEnd),

    // Create composite key for work order

    AddWorkOrderKey = Table.AddColumn(FilteredWorkOrders, "WorkOrderKey", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    // STEP 2: Get primary job information from first job line

    // (Using line_no = 1 as you showed in your SQL)

    PrimaryJobs = Table.SelectRows(Raw_wkrodesc, each [LineNumber] = 1),

    PrimaryJobsWithKey = Table.AddColumn(PrimaryJobs, "WorkOrderKey", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    // Join primary job to work orders

    JoinPrimaryJob = Table.NestedJoin(

        AddWorkOrderKey, {"WorkOrderKey"},

        PrimaryJobsWithKey, {"WorkOrderKey"},

        "PrimaryJob", JoinKind.LeftOuter),

    ExpandPrimaryJob = Table.ExpandTableColumn(JoinPrimaryJob, "PrimaryJob",

        {"JobCode", "JobType", "JobValue"},

        {"PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue"}),

    // STEP 3: Aggregate job summary metrics (all jobs, not just primary)

    JobSummary = Table.Group(Raw_wkrodesc, {"Branch", "WorkOrder"}, {

        {"TotalJobCount", each Table.RowCount(_), Int64.Type},

        {"TotalJobValue", each List.Sum([JobValue]), type number}

    }),

    JobSummaryWithKey = Table.AddColumn(JobSummary, "WorkOrderKey", each

        [Branch] & "-" & Text.From([WorkOrder]), type text),

    JoinJobSummary = Table.NestedJoin(

        ExpandPrimaryJob, {"WorkOrderKey"},

        JobSummaryWithKey, {"WorkOrderKey"},

        "JobSummary", JoinKind.LeftOuter),

    ExpandJobSummary = Table.ExpandTableColumn(JoinJobSummary, "JobSummary",

        {"TotalJobCount", "TotalJobValue"}),

    // STEP 4: Customer Assignment Logic

    // Clean the account number

    AddAccountClean = Table.AddColumn(ExpandJobSummary, "AccountNumberClean", each

        if [AccountNumber] <> null and [AccountNumber] <> ""

        then Text.Upper(Text.Trim(Text.From([AccountNumber])))

        else null, type text),

    // Determine customer lookup key based on account and job type

    AddCustomerLookupKey = Table.AddColumn(AddAccountClean, "CustomerLookupKey", each

        let

            jobType = Text.Lower(Text.Trim([PrimaryJobType] ?? ""))

        in

            if [AccountNumberClean] <> null then

                [AccountNumberClean]

            else if jobType = "i" then "INTERNAL"

            else if jobType = "w" then "WARRANTY"

            else if jobType = "f" then "FLEET"

            else if jobType = "e" then "EXCESS"

            else if jobType = "p" then "POLICY"

            else if jobType = "b" then "BILLING"

            else if jobType = "s" then "MISC"

            else "UNKNOWN",

        type text),

    // Join with Customer dimension

    JoinCustomer = Table.NestedJoin(

        AddCustomerLookupKey, {"CustomerLookupKey"},

        dim_CustomerList, {"AccountNumberText"},

        "Customer", JoinKind.LeftOuter),

    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "Customer", {"CustomerKey"}),

    // Handle missing customers

    AddFinalCustomerKey = Table.AddColumn(ExpandCustomer, "FinalCustomerKey", each

        if [CustomerKey] <> null then [CustomerKey] else -1, Int64.Type),

    // STEP 5: Vehicle/Equipment Lookup

    AddVehicleLookupKey = Table.AddColumn(AddFinalCustomerKey, "VehicleLookupKey", each

        if [Registration] <> null and [Registration] <> "" then

            Text.Upper(Text.Trim([Registration]))

        else if [StockNumber] <> null and [StockNumber] <> "" then

            "Stk# " & Text.Trim(Text.From([StockNumber]))  // Note: "Stk# " not "STK#" based on your dim

        else null, type text),

    JoinVehicle = Table.NestedJoin(

        AddVehicleLookupKey, {"VehicleLookupKey"},

        dim_Vehicle, {"PrimaryLookup"},  // Correct field name from your dim_Vehicle

        "Vehicle", JoinKind.LeftOuter),

    ExpandVehicle = Table.ExpandTableColumn(JoinVehicle, "Vehicle", {"VehicleKey"}),

    // STEP 6: Branch Lookup

    JoinBranch = Table.NestedJoin(

        ExpandVehicle, {"Branch"},

        dim_Branch, {"BranchID"},  // Correct field name from your dim_Branch

        "BranchInfo", JoinKind.LeftOuter),

    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchInfo", {"BranchKey"}),

    // STEP 7: Status Lookup

    AddStatusLookup = Table.AddColumn(ExpandBranch, "StatusLookup", each

        Text.Lower(Text.Trim([ProgressStatus] ?? "")), type text),

    JoinStatus = Table.NestedJoin(

        AddStatusLookup, {"StatusLookup"},

        dim_WorkOrderStatus, {"StatusCode"},  // Correct - StatusCode is already lowercase in dim

        "Status", JoinKind.LeftOuter),

    ExpandStatus = Table.ExpandTableColumn(JoinStatus, "Status", {"StatusKey"}),

    // STEP 8: Job Code Lookup (for primary job)

    AddJobCodeLookup = Table.AddColumn(ExpandStatus, "JobCodeLookup", each

        if [PrimaryJobCode] <> null then Text.Upper(Text.Trim([PrimaryJobCode])) else null,

        type text),

    JoinJobCode = Table.NestedJoin(

        AddJobCodeLookup, {"JobCodeLookup"},

        dim_JobCode, {"JobCode"},  // Correct - JobCode is already uppercase in dim

        "JobCodeInfo", JoinKind.LeftOuter),

    ExpandJobCode = Table.ExpandTableColumn(JoinJobCode, "JobCodeInfo", {"JobCodeKey"}),

    // STEP 9: Add calculated fields

    AddCalculatedFields = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(

                Table.AddColumn(ExpandJobCode,

                    "WorkOrderAge", each

                        if [CreatedOn] <> null then

                            Duration.Days(DateTime.LocalNow() - [CreatedOn])

                        else null, type number),

                "IsActive", each

                    Text.Upper([ProgressStatus] ?? "") <> "VP", type logical),

            "DaysUntilExpected", each

                if [ExpectedDate] <> null then

                    Duration.Days([ExpectedDate] - DateTime.LocalNow())

                else null, type number),

        "IsOverdue", each

            if [ExpectedDate] <> null then

                [ExpectedDate] < DateTime.LocalNow() and [IsActive] = true

            else false, type logical),

    // STEP 9A: Add Work Order Priority Score (0-100, higher = more urgent)

    AddPriorityScore = Table.AddColumn(AddCalculatedFields, "PriorityScore", each

        let

            // Age component (0-40 points): older = higher priority

            AgeScore = if [WorkOrderAge] = null then 0

                      else if [WorkOrderAge] > 30 then 40

                      else if [WorkOrderAge] > 14 then 30

                      else if [WorkOrderAge] > 7 then 20

                      else if [WorkOrderAge] > 3 then 10

                      else 5,

            // Overdue component (0-30 points)

            OverdueScore = if [IsOverdue] = true then 30 else 0,

            // Customer type component (0-20 points)

            CustomerScore = if [FinalCustomerKey] > 0 then 20  // Real customer

                           else if [FinalCustomerKey] = -3 then 15  // Warranty

                           else if [FinalCustomerKey] = -2 then 5   // Internal

                           else 10,  // Others

            // Value component (0-10 points)

            ValueScore = if [TotalJobValue] = null then 0

                        else if [TotalJobValue] > 5000 then 10

                        else if [TotalJobValue] > 2000 then 7

                        else if [TotalJobValue] > 500 then 5

                        else 2

        in

            AgeScore + OverdueScore + CustomerScore + ValueScore,

        type number),

    // Add Priority Category based on score

    AddPriorityCategory = Table.AddColumn(AddPriorityScore, "PriorityCategory", each

        if [PriorityScore] >= 70 then "Critical"

        else if [PriorityScore] >= 50 then "High"

        else if [PriorityScore] >= 30 then "Medium"

        else "Low",

        type text),

    // STEP 9B: Add Work Order Grouping Categories

    // Work Order Size based on job value

    AddWorkOrderSize = Table.AddColumn(AddPriorityCategory, "WorkOrderSize", each

        if [TotalJobValue] = null or [TotalJobValue] = 0 then "Unknown"

        else if [TotalJobValue] > 5000 then "Large"

        else if [TotalJobValue] > 1000 then "Medium"

        else "Small",

        type text),

    // Complexity Level based on job count

    AddComplexityLevel = Table.AddColumn(AddWorkOrderSize, "ComplexityLevel", each

        if [TotalJobCount] = null then "Unknown"

        else if [TotalJobCount] >= 5 then "High"

        else if [TotalJobCount] >= 3 then "Medium"

        else if [TotalJobCount] >= 1 then "Low"

        else "None",

        type text),

    // Service Type based on primary job code category (from dim_JobCode)

    AddServiceType = Table.AddColumn(AddComplexityLevel, "ServiceType", each

        let

            jobType = Text.Lower([PrimaryJobType] ?? ""),

            jobCode = Text.Upper([PrimaryJobCode] ?? "")

        in

            // Check job type first

            if jobType = "i" then "Internal"

            else if jobType = "w" then "Warranty"

            // Then check job code patterns

            else if Text.Contains(jobCode, "INSPECT") or Text.Contains(jobCode, "IS-") then "Inspection"

            else if Text.Contains(jobCode, "REPAIR") or Text.Contains(jobCode, "FIX") then "Repair"

            else if Text.Contains(jobCode, "SERVICE") or Text.Contains(jobCode, "MAINT") then "Maintenance"

            else if Text.Contains(jobCode, "SETUP") or Text.Contains(jobCode, "INSTALL") then "Setup/Install"

            else if Text.Contains(jobCode, "DIAGNOS") then "Diagnostic"

            else "General Service",

        type text),

    // STEP 9C: Add Risk and Performance Indicators

    // Risk of Delay indicator

    AddDelayRisk = Table.AddColumn(AddServiceType, "DelayRiskLevel", each

        let

            // High risk if: old + still early status + complex

            IsEarlyStatus = List.Contains({"bi", "va"}, Text.Lower([ProgressStatus] ?? "")),

            IsOld = [WorkOrderAge] > 7,

            IsComplex = [ComplexityLevel] = "High"

        in

            if [IsActive] = false then "Completed"

            else if IsOld and IsEarlyStatus then "High Risk"

            else if IsOld or ([IsOverdue] = true) then "Medium Risk"

            else if IsComplex and [WorkOrderAge] > 3 then "Medium Risk"

            else "Low Risk",

        type text),

    // Add work order velocity indicator (how fast it's moving through statuses)

    AddVelocityIndicator = Table.AddColumn(AddDelayRisk, "WorkOrderVelocity", each

        let

            Status = Text.Lower([ProgressStatus] ?? ""),

            Age = [WorkOrderAge] ?? 0

        in

            if [IsActive] = false then "Completed"

            else if Status = "bi" and Age > 3 then "Stalled"

            else if Status = "va" and Age > 5 then "Slow"

            else if List.Contains({"wip", "wf"}, Status) and Age > 14 then "Slow"

            else if Age > 21 then "Very Slow"

            else "Normal",

        type text),

    // STEP 10: Add date keys for date dimension relationships

    AddDateKeys = Table.AddColumn(

        Table.AddColumn(AddVelocityIndicator,

            "CreatedDateKey", each

                if [CreatedOn] <> null then

                    Date.Year([CreatedOn]) * 10000 +

                    Date.Month([CreatedOn]) * 100 +

                    Date.Day([CreatedOn])

                else null, Int64.Type),

        "ExpectedDateKey", each

            if [ExpectedDate] <> null then

                Date.Year([ExpectedDate]) * 10000 +

                Date.Month([ExpectedDate]) * 100 +

                Date.Day([ExpectedDate])

            else null, Int64.Type),

    // STEP 11: Final column selection

    FinalColumns = Table.SelectColumns(AddDateKeys, {

        // Keys

        "WorkOrderKey", "WorkOrder", "Branch",

        // Dimension Keys

        "FinalCustomerKey", "VehicleKey", "BranchKey", "StatusKey", "JobCodeKey",

        // Date Keys

        "CreatedDateKey", "ExpectedDateKey",

        // Dates (for direct filtering if needed)

        "CreatedOn", "ExpectedDate",

        // Primary Job Information

        "PrimaryJobCode", "PrimaryJobType", "PrimaryJobValue",

        // Summary Metrics

        "TotalJobCount", "TotalJobValue",

        // Vehicle/Equipment Context

        "Registration", "StockNumber", "Odometer",

        // Calculated Metrics

        "WorkOrderAge", "DaysUntilExpected",

        // Priority Fields (NEW)

        "PriorityScore", "PriorityCategory",

        // Grouping Categories (NEW)

        "WorkOrderSize", "ComplexityLevel", "ServiceType",

        // Risk Indicators (NEW)

        "DelayRiskLevel", "WorkOrderVelocity",

        // Status Flags

        "IsActive", "IsOverdue",

        // Progress Status (for debugging/validation)

        "ProgressStatus",

        // Audit

        "ModifiedDate"

    }),

    // Rename FinalCustomerKey to CustomerKey

    RenamedColumns = Table.RenameColumns(FinalColumns, {{"FinalCustomerKey", "CustomerKey"}}),

    // Set data types

    FinalDataTypes = Table.TransformColumnTypes(RenamedColumns, {

        {"WorkOrderKey", type text}, {"WorkOrder", Int64.Type}, {"Branch", type text},

        {"CustomerKey", Int64.Type}, {"VehicleKey", Int64.Type}, {"BranchKey", Int64.Type},

        {"StatusKey", Int64.Type}, {"JobCodeKey", Int64.Type},

        {"CreatedDateKey", Int64.Type}, {"ExpectedDateKey", Int64.Type},

        {"CreatedOn", type datetime}, {"ExpectedDate", type datetime},

        {"PrimaryJobCode", type text}, {"PrimaryJobType", type text}, {"PrimaryJobValue", type number},

        {"TotalJobCount", Int64.Type}, {"TotalJobValue", type number},

        {"Registration", type text}, {"StockNumber", type text}, {"Odometer", type number},

        {"WorkOrderAge", type number}, {"DaysUntilExpected", type number},

        {"PriorityScore", type number}, {"PriorityCategory", type text},

        {"WorkOrderSize", type text}, {"ComplexityLevel", type text}, {"ServiceType", type text},

        {"DelayRiskLevel", type text}, {"WorkOrderVelocity", type text},

        {"IsActive", type logical}, {"IsOverdue", type logical},

        {"ProgressStatus", type text}, {"ModifiedDate", type datetime}

    })

in

    FinalDataTypes

  

/*

Key Features:

1. One row per work order (snapshot of current state)

2. Handles customer assignment with fallback to job type

3. Links to all dimension tables

4. Includes key business metrics

5. Supports incremental refresh via ModifiedDate

6. Much simpler than the complex SQL query

  

NEW ENHANCEMENTS:

- Priority scoring system (0-100) for work order urgency

- Automatic categorization (size, complexity, service type)

- Risk indicators for delays and velocity tracking

- No performance impact - all calculated columns

  

Priority Score Components:

- Age: 0-40 points (older = higher priority)

- Overdue: 0-30 points

- Customer Type: 0-20 points (retail > warranty > internal)

- Job Value: 0-10 points

  

Use Cases for New Fields:

- PriorityCategory: Filter dashboards for "Critical" and "High" priority work

- WorkOrderSize: Resource allocation (Large jobs need senior techs)

- ComplexityLevel: Scheduling (High complexity needs more time)

- ServiceType: Department routing and specialization

- DelayRiskLevel: Proactive management intervention

- WorkOrderVelocity: Identify bottlenecks in workflow

  

Next Steps:

1. Test the new calculated fields with your data

2. Consider adding these to your reports/dashboards

3. Build Fact_WorkOrderLabor for technician detail

4. Consider a separate historical averages table for predictive metrics

*/