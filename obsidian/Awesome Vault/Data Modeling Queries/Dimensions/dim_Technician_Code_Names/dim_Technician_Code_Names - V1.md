let

    Source = Raw_Technician,

    #"Sorted rows" = Table.Sort(Source, {{"techniciancode", Order.Ascending}}),

    #"Added index" = Table.AddIndexColumn(#"Sorted rows", "TechnicianKey", 1, 1, Int64.Type),

    // Enhanced cleaning and standardization

    #"Added TechnicianCode" = Table.AddColumn(#"Added index", "TechnicianCode", each

        Text.Upper(Text.Trim([techniciancode] ?? ""))),

    #"Added TechnicianFirstName" = Table.AddColumn(#"Added TechnicianCode", "TechnicianFirstName", each

        Text.Proper(Text.Trim([firstname] ?? ""))),

    #"Added TechnicianLastName" = Table.AddColumn(#"Added TechnicianFirstName", "TechnicianLastName", each

        Text.Proper(Text.Trim([lastname] ?? ""))),

    // Enhanced full name logic with better null handling

    #"Added TechnicianFullName" = Table.AddColumn(#"Added TechnicianLastName", "TechnicianFullName", each

        let

            first = [TechnicianFirstName],

            last = [TechnicianLastName]

        in

            if first <> "" and last <> "" then first & " " & last

            else if last <> "" then last

            else if first <> "" then first

            else "Technician " & [TechnicianCode]),

    // Enhanced display name (matches format from original complex query)

    #"Added TechnicianDisplayName" = Table.AddColumn(#"Added TechnicianFullName", "TechnicianDisplayName", each

        [TechnicianCode] & " - " & [TechnicianFullName]),

    // Add short name for space-constrained reports

    #"Added TechnicianShortName" = Table.AddColumn(#"Added TechnicianDisplayName", "TechnicianShortName", each

        let

            first = [TechnicianFirstName],

            last = [TechnicianLastName]

        in

            if first <> "" and last <> "" then Text.Start(first, 1) & ". " & last

            else [TechnicianCode]),

    // Enhanced status logic (could be expanded based on business rules)

    #"Added TechnicianStatus" = Table.AddColumn(#"Added TechnicianShortName", "TechnicianStatus", each "Active"),

    // Enhanced type classification

    #"Added TechnicianType" = Table.AddColumn(#"Added TechnicianStatus", "TechnicianType", each "Technician"),

    // Add business flags for analytics

    #"Added IsActive" = Table.AddColumn(#"Added TechnicianType", "IsActive", each

        [TechnicianStatus] = "Active", type logical),

    #"Added HasFullName" = Table.AddColumn(#"Added IsActive", "HasFullName", each

        [TechnicianFirstName] <> "" and [TechnicianLastName] <> "", type logical),

    // Final column selection

    #"Select Final Columns" = Table.SelectColumns(#"Added HasFullName", {

        "TechnicianKey", "TechnicianCode", "TechnicianFirstName", "TechnicianLastName",

        "TechnicianFullName", "TechnicianDisplayName", "TechnicianShortName",

        "TechnicianStatus", "TechnicianType", "IsActive", "HasFullName"

    }),

    // Set proper data types

    #"Set Data Types" = Table.TransformColumnTypes(#"Select Final Columns", {

        {"TechnicianKey", Int64.Type}, {"TechnicianCode", type text}, {"TechnicianFirstName", type text},

        {"TechnicianLastName", type text}, {"TechnicianFullName", type text}, {"TechnicianDisplayName", type text},

        {"TechnicianShortName", type text}, {"TechnicianStatus", type text}, {"TechnicianType", type text},

        {"IsActive", type logical}, {"HasFullName", type logical}

    }),

    // Final sort

   #"Sort by Code" = Table.Sort(#"Set Data Types", {{"TechnicianCode", Order.Ascending}}),

    // ADD THIS: Create special technician record for unknown/missing technicians

    SpecialTechnicians = Table.FromRows({

        {-1, "UNKNOWN", "", "", "Unknown Technician", "UNKNOWN - Unknown Technician",

         "Unknown", "Unknown", "Unknown", false, false}

    },

    {"TechnicianKey", "TechnicianCode", "TechnicianFirstName", "TechnicianLastName",

     "TechnicianFullName", "TechnicianDisplayName", "TechnicianShortName",

     "TechnicianStatus", "TechnicianType", "IsActive", "HasFullName"}),

    // Convert types for special records

    SpecialTechniciansTyped = Table.TransformColumnTypes(SpecialTechnicians, {

        {"TechnicianKey", Int64.Type}, {"TechnicianCode", type text},

        {"TechnicianFirstName", type text}, {"TechnicianLastName", type text},

        {"TechnicianFullName", type text}, {"TechnicianDisplayName", type text},

        {"TechnicianShortName", type text}, {"TechnicianStatus", type text},

        {"TechnicianType", type text}, {"IsActive", type logical},

        {"HasFullName", type logical}

    }),

    // Combine special records with regular technicians

    CombinedTechnicians = Table.Combine({SpecialTechniciansTyped, #"Sort by Code"}),

    // Final sort to put special record at top

    FinalSort = Table.Sort(CombinedTechnicians, {{"TechnicianKey", Order.Ascending}})

in

    FinalSort