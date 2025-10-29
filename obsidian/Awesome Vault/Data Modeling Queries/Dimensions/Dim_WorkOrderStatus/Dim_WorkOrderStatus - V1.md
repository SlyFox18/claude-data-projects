let

    Source = Raw_WorkOrderFile,

    #"Sorted rows" = Table.Sort(Source, {{"ProgressStatus", Order.Ascending}}),

    #"Added index" = Table.AddIndexColumn(#"Sorted rows", "StatusKey", 1, 1, Int64.Type),

    #"Reordered columns" = Table.ReorderColumns(#"Added index", {"StatusKey", "ProgressStatus"}),

    // Clean and standardize status code

    #"Added StatusCode" = Table.AddColumn(#"Reordered columns", "StatusCode", each

        Text.Lower(Text.Trim([ProgressStatus] ?? ""))),

    // Enhanced status name mapping (includes all statuses from your complex query)

    #"Added StatusName" = Table.AddColumn(#"Added StatusCode", "StatusName", each

        let Code = [StatusCode]

        in if Code = "bi" then "Booked-In"

        else if Code = "va" then "Equipment Arrived"

        else if Code = "wip" then "Work Commenced"

        else if Code = "wf" then "Work Finished"

        else if Code = "iv" then "Equipment Invoiced"

        else if Code = "ca" then "Customer Advised"

        else if Code = "vp" then "Equipment Picked-up"

        else if Code = "wp" then "Work in Progress"  // Handle both wip and wp

        else if Code = "" then "Unknown"

        else Text.Proper(Code)),

    // Enhanced status category with complete workflow

    #"Added StatusCategory" = Table.AddColumn(#"Added StatusName", "StatusCategory", each

        let Code = [StatusCode]

        in if Code = "bi" then "Intake"

        else if List.Contains({"va", "wip", "wp", "wf"}, Code) then "In Progress"

        else if List.Contains({"iv", "ca"}, Code) then "Billing"

        else if Code = "vp" then "Closed"

        else "Other"),

    // Enhanced workflow ordering

    #"Added StatusOrder" = Table.AddColumn(#"Added StatusCategory", "StatusOrder", each

        let Code = [StatusCode]

        in if Code = "bi" then 1      // Booked-In

        else if Code = "va" then 2    // Equipment Arrived

        else if Code = "wip" then 3   // Work Commenced

        else if Code = "wp" then 3    // Work in Progress (same as wip)

        else if Code = "wf" then 4    // Work Finished

        else if Code = "iv" then 5    // Equipment Invoiced

        else if Code = "ca" then 6    // Customer Advised

        else if Code = "vp" then 7    // Equipment Picked-up

        else 99, type number),        // Keep as number for proper sorting

    // Enhanced display name

    #"Added StatusDisplayName" = Table.AddColumn(#"Added StatusOrder", "StatusDisplayName", each

        Text.Upper([StatusCode]) & " - " & [StatusName]),

    // Business flags with proper logical types

    #"Added IsActive" = Table.AddColumn(#"Added StatusDisplayName", "IsActive", each

        [StatusCode] <> "vp", type logical),  // Only picked-up is inactive

    #"Added IsCompleted" = Table.AddColumn(#"Added IsActive", "IsCompleted", each

        List.Contains({"iv", "ca", "vp"}, [StatusCode]), type logical),

    #"Added IsBillable" = Table.AddColumn(#"Added IsCompleted", "IsBillable", each

        List.Contains({"iv", "ca", "vp"}, [StatusCode]), type logical),

    // Add workflow phase for higher-level grouping

    #"Added WorkflowPhase" = Table.AddColumn(#"Added IsBillable", "WorkflowPhase", each

        let Code = [StatusCode]

        in if Code = "bi" then "1-Intake"

        else if List.Contains({"va", "wip", "wp"}, Code) then "2-Service"

        else if Code = "wf" then "3-Complete"

        else if List.Contains({"iv", "ca", "vp"}, Code) then "4-Closed"

        else "5-Other"),

    // Add status type classification

    #"Added StatusType" = Table.AddColumn(#"Added WorkflowPhase", "StatusType", each

        let Code = [StatusCode]

        in if List.Contains({"bi", "va"}, Code) then "Administrative"

        else if List.Contains({"wip", "wp", "wf"}, Code) then "Operational"

        else if List.Contains({"iv", "ca", "vp"}, Code) then "Financial"

        else "Other"),

    // Final column selection

    #"Select Final Columns" = Table.SelectColumns(#"Added StatusType", {

        "StatusKey", "StatusCode", "StatusName", "StatusDisplayName", "StatusCategory",

        "WorkflowPhase", "StatusType", "StatusOrder", "IsActive", "IsCompleted", "IsBillable"

    }),

    // Set proper data types

    #"Set Data Types" = Table.TransformColumnTypes(#"Select Final Columns", {

        {"StatusKey", Int64.Type}, {"StatusCode", type text}, {"StatusName", type text},

        {"StatusDisplayName", type text}, {"StatusCategory", type text}, {"WorkflowPhase", type text},

        {"StatusType", type text}, {"StatusOrder", Int64.Type}, {"IsActive", type logical},

        {"IsCompleted", type logical}, {"IsBillable", type logical}

    }),

    // Sort by workflow order for consistency

    #"Sort by Order" = Table.Sort(#"Set Data Types", {{"StatusOrder", Order.Ascending}})

in

    #"Sort by Order"