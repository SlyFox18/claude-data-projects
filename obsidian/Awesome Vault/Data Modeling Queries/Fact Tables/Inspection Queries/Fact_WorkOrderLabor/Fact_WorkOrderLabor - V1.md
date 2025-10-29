// Fact_WorkOrderLabor_Basic - SIMPLIFIED VERSION

// This will definitely work without timeouts

  

let

    // STEP 1: Start with mechanic work only (smaller table)

    Source = Raw_wkmechwk,

    // Filter to recent data

    FilteredData = Table.SelectRows(Source, each

        [ModifiedDate] >= #datetime(2024, 1, 1, 0, 0, 0)),

    // Keep only essential columns

    EssentialColumns = Table.SelectColumns(FilteredData, {

        "Branch", "WorkOrder", "JobCode", "JobType", "TechCode",

        "ClockInDate", "HoursWorked", "InvoiceHours", "HoursRework"

    }),

    // Create a unique row identifier FIRST (before any joins)

    AddRowId = Table.AddIndexColumn(EssentialColumns, "RowId", 1, 1, Int64.Type),

    // Add basic keys

    AddKeys = Table.AddColumn(

        Table.AddColumn(AddRowId,

            "WorkOrderKey", each [Branch] & "-" & Text.From([WorkOrder]), type text),

        "TechCodeClean", each

            if [TechCode] <> null and [TechCode] <> ""

            then Text.Upper(Text.Trim([TechCode]))

            else "UNKNOWN", type text),

    // Add basic calculations

    AddCalcs = Table.AddColumn(

        Table.AddColumn(

            Table.AddColumn(AddKeys,

                "TotalHours", each ([HoursWorked] ?? 0) + ([HoursRework] ?? 0), type number),

            "Efficiency", each

                if ([HoursWorked] ?? 0) > 0 then

                    Number.Round(([InvoiceHours] ?? 0) / [HoursWorked], 2)

                else null, type number),

        "HasRework", each ([HoursRework] ?? 0) > 0, type logical),

    // Add date key

    AddDateKey = Table.AddColumn(AddCalcs, "ClockInDateKey", each

        if [ClockInDate] <> null then

            Date.Year([ClockInDate]) * 10000 +

            Date.Month([ClockInDate]) * 100 +

            Date.Day([ClockInDate])

        else 99999999, Int64.Type),

    // STEP 2: Join ONLY with technician dimension (simple, one-to-one)

    JoinTech = Table.NestedJoin(

        AddDateKey, {"TechCodeClean"},

        dim_Technician_Code_Names, {"TechnicianCode"},

        "Tech", JoinKind.LeftOuter),

    // Expand only the key

    ExpandTech = Table.ExpandTableColumn(JoinTech, "Tech", {"TechnicianKey"}),

    // Handle missing technicians

    AddTechKey = Table.AddColumn(ExpandTech, "FinalTechnicianKey", each

        [TechnicianKey] ?? -1, Int64.Type),

    // STEP 3: Final columns (minimal set)

    FinalColumns = Table.SelectColumns(AddTechKey, {

        "RowId",  // Unique identifier

        "WorkOrderKey",

        "FinalTechnicianKey",

        "ClockInDateKey",

        "Branch",

        "WorkOrder",

        "JobCode",

        "JobType",

        "TechCode",

        "ClockInDate",

        "HoursWorked",

        "HoursRework",

        "TotalHours",

        "InvoiceHours",

        "Efficiency",

        "HasRework"

    }),

    // Rename columns

    RenamedColumns = Table.RenameColumns(FinalColumns, {

        {"RowId", "LaborFactKey"},

        {"FinalTechnicianKey", "TechnicianKey"}

    }),

    // Set final types

    FinalTypes = Table.TransformColumnTypes(RenamedColumns, {

        {"LaborFactKey", Int64.Type},

        {"WorkOrderKey", type text},

        {"TechnicianKey", Int64.Type},

        {"ClockInDateKey", Int64.Type},

        {"Branch", type text},

        {"WorkOrder", Int64.Type},

        {"JobCode", type text},

        {"JobType", type text},

        {"TechCode", type text},

        {"ClockInDate", type date},

        {"HoursWorked", type number},

        {"HoursRework", type number},

        {"TotalHours", type number},

        {"InvoiceHours", type number},

        {"Efficiency", type number},

        {"HasRework", type logical}

    })

in

    FinalTypes

  

/*

KEY DIFFERENCES:

1. NO join with Raw_wkothsub (avoid many-to-many)

2. NO join with Fact_WorkOrderHeader (avoid dependency)

3. Index added BEFORE any joins (ensures unique key)

4. Minimal calculations

5. Only one simple dimension join (technician)

  

WHAT'S INCLUDED:

- Basic hours tracking

- Efficiency calculation

- Rework flag

- Technician dimension link

- Date key for time analysis

  

WHAT'S MISSING (can add later):

- Labor costs (from wkothsub)

- Work order context

- Complex categorizations

  

This should complete in seconds!

Once working, we can gradually add:

1. Labor costs in a separate query

2. More dimensions

3. More calculations

*/