// Fact_LaborCosts - Track estimates and costs separately

// This avoids the many-to-many join issue

  

let

    // Start with labor cost data

    Source = Raw_wkothsub,

    // Filter to recent data

    FilteredData = Table.SelectRows(Source, each

        [ModifiedDate] >= #datetime(2024, 1, 1, 0, 0, 0)),

    // Select essential columns

    EssentialColumns = Table.SelectColumns(FilteredData, {

        "Branch", "WorkOrder", "JobCode", "JobType",

        "EstHours", "EstLabor", "ActLabor", "InvLabor",

        "FieldRepair", "IsStandardLabor",

        "InvoiceNumber", "InvoiceDate"

    }),

    // Add unique identifier

    AddRowId = Table.AddIndexColumn(EssentialColumns, "CostFactKey", 1, 1, Int64.Type),

    // Add keys

    AddKeys = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(AddRowId,

                "WorkOrderKey", each [Branch] & "-" & Text.From([WorkOrder]), type text),

            "JobKey", each

                [Branch] & "-" & Text.From([WorkOrder]) & "-" &

                Text.Trim([JobCode] ?? "") & "-" & Text.Trim([JobType] ?? ""),

                type text),

        "JobCodeClean", each

            if [JobCode] <> null then Text.Upper(Text.Trim([JobCode])) else "UNKNOWN",

            type text),

    // Add field repair flags

    AddFieldFlags = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(AddKeys,

                "IsFieldRepair", each Text.Upper([FieldRepair] ?? "N") = "Y", type logical),

            "WorkLocation", each

                if Text.Upper([FieldRepair] ?? "N") = "Y" then "Field" else "Shop",

                type text),

        "IsStandardLaborFlag", each

            Text.Upper([IsStandardLabor] ?? "N") = "Y", type logical),

    // Add cost calculations

    AddCalcs = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(AddFieldFlags,

                "LaborCostVariance", each ([ActLabor] ?? 0) - ([EstLabor] ?? 0), type number),

            "LaborMargin", each ([InvLabor] ?? 0) - ([ActLabor] ?? 0), type number),

        "CostEfficiency", each

            if ([EstLabor] ?? 0) > 0 then

                Number.Round(([ActLabor] ?? 0) / [EstLabor], 2)

            else null, type number),

    // Add invoice date key

    AddDateKey = Table.AddColumn(AddCalcs, "InvoiceDateKey", each

        if [InvoiceDate] <> null then

            Date.Year([InvoiceDate]) * 10000 +

            Date.Month([InvoiceDate]) * 100 +

            Date.Day([InvoiceDate])

        else 99999999, Int64.Type),

    // Join with job code dimension

    JoinJobCode = Table.NestedJoin(

        AddDateKey, {"JobCodeClean"},

        dim_JobCode, {"JobCode"},

        "Job", JoinKind.LeftOuter),

    ExpandJob = Table.ExpandTableColumn(JoinJobCode, "Job", {"JobCodeKey"}),

    // Final columns

    FinalColumns = Table.SelectColumns(ExpandJob, {

        "CostFactKey",

        "WorkOrderKey",

        "JobKey",

        "JobCodeKey",

        "InvoiceDateKey",

        "Branch",

        "WorkOrder",

        "JobCode",

        "JobType",

        "EstHours",

        "EstLabor",

        "ActLabor",

        "InvLabor",

        "LaborCostVariance",

        "LaborMargin",

        "CostEfficiency",

        "WorkLocation",

        "IsFieldRepair",

        "IsStandardLaborFlag",

        "InvoiceNumber",

        "InvoiceDate"

    }),

    // Rename for consistency

    RenamedColumns = Table.RenameColumns(FinalColumns, {

        {"IsStandardLaborFlag", "IsStandardLabor"}

    }),

    // Set data types

    FinalTypes = Table.TransformColumnTypes(RenamedColumns, {

        {"CostFactKey", Int64.Type},

        {"WorkOrderKey", type text},

        {"JobKey", type text},

        {"JobCodeKey", Int64.Type},

        {"InvoiceDateKey", Int64.Type},

        {"Branch", type text},

        {"WorkOrder", Int64.Type},

        {"JobCode", type text},

        {"JobType", type text},

        {"EstHours", type number},

        {"EstLabor", type number},

        {"ActLabor", type number},

        {"InvLabor", type number},

        {"LaborCostVariance", type number},

        {"LaborMargin", type number},

        {"CostEfficiency", type number},

        {"WorkLocation", type text},

        {"IsFieldRepair", type logical},

        {"IsStandardLabor", type logical},

        {"InvoiceNumber", type text},

        {"InvoiceDate", type date}

    })

in

    FinalTypes

  

/*

FACT_LABORCOSTS:

- Separate table for cost tracking

- One row per job/work order combination

- Avoids complex joins with mechanic work

- Includes field repair tracking

- Converts Y/N text fields to boolean

  

Key Metrics:

- LaborCostVariance: Actual - Estimated cost

- LaborMargin: Invoiced - Actual (profit)

- CostEfficiency: Actual / Estimated ratio

  

In Power BI:

- Connect to Fact_WorkOrderHeader via WorkOrderKey

- Analyze costs independently from hours

- Combine insights through DAX measures

  

Benefits:

- Fast refresh (no complex joins)

- Clear grain (one row per job)

- Independent analysis possible

- Can aggregate to work order level easily

*/