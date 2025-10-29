let

    // Incremental refresh parameters (if your source tables support it)

    RangeStart = #datetime(2023, 1, 1, 0, 0, 0),

    RangeEnd = DateTime.LocalNow(),

    CurrentYear = Date.Year(DateTime.Date(DateTime.LocalNow())),

    // Enhance Raw_VehicleFleet with lookup keys (VehicleSource already exists)

    FleetEnhanced = Table.AddColumn(Raw_VehicleFleet, "LookupKey", each [Registration]),

    // Enhance Raw_VehicleStock with lookup keys (VehicleSource already exists)  

    StockEnhanced = Table.AddColumn(Raw_VehicleStock, "LookupKey", each "Stk# " & Text.From([StockNumber] ?? "")),

    // Combine the tables

    CombinedTables = Table.Combine({FleetEnhanced, StockEnhanced}),

    // Remove duplicates based on the most comprehensive identifier

    #"Removed duplicates" = Table.Distinct(CombinedTables, {"VehicleIdentifier"}),

    // Remove blank rows but be more specific about what constitutes a valid record

    #"Removed blank rows" = Table.SelectRows(#"Removed duplicates", each

        ([Registration] <> null and [Registration] <> "") or

        ([StockNumber] <> null and [StockNumber] <> "")

    ),

    // Add surrogate key

    #"Added index" = Table.AddIndexColumn(#"Removed blank rows", "VehicleKey", 1, 1, Int64.Type),

    // Enhanced cleaning and standardization

    #"Clean Registration" = Table.TransformColumns(#"Added index", {{"Registration", each Text.Upper(Text.Trim(_ ?? "")), type text}}),

    #"Clean StockNumber" = Table.TransformColumns(#"Clean Registration", {{"StockNumber", each Text.Trim(_ ?? ""), type text}}),

    #"Clean Make" = Table.TransformColumns(#"Clean StockNumber", {{"Make", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}}),

    #"Clean Model" = Table.TransformColumns(#"Clean Make", {{"Model", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}}),

    #"Clean VIN" = Table.TransformColumns(#"Clean Model", {{"VIN", each Text.Upper(Text.Trim(_ ?? "")), type text}}),

    #"Clean Engine" = Table.TransformColumns(#"Clean VIN", {{"Engine", each Text.Trim(_ ?? ""), type text}}),

    #"Clean Status" = Table.TransformColumns(#"Clean Engine", {{"Status", each Text.Proper(Text.Trim(_ ?? "Unknown")), type text}}),

    // Create primary lookup field (matches your complex query logic)

    #"Add Primary Lookup" = Table.AddColumn(#"Clean Status", "PrimaryLookup", each

        if [Registration] <> "" then [Registration]

        else if [StockNumber] <> "" then "Stk# " & [StockNumber]

        else [VehicleIdentifier]),

    // Enhanced calculated fields

    #"Add Vehicle Age" = Table.AddColumn(#"Add Primary Lookup", "VehicleAge", each

        if [Year] <> null and [Year] > 1900 then CurrentYear - [Year]

        else null, type number),

    #"Add Age Category" = Table.AddColumn(#"Add Vehicle Age", "AgeCategory", each

        if [VehicleAge] = null then "Unknown"

        else if [VehicleAge] <= 2 then "New (0-2 years)"

        else if [VehicleAge] <= 5 then "Recent (3-5 years)"

        else if [VehicleAge] <= 10 then "Mature (6-10 years)"

        else "Older (10+ years)"),

    #"Add Make Model" = Table.AddColumn(#"Add Age Category", "MakeModel", each

        [Make] & " " & [Model]),

    #"Add Vehicle Type Enhanced" = Table.AddColumn(#"Add Make Model", "VehicleTypeEnhanced", each

        if [VehicleSource] = "Fleet" then "Fleet Vehicle"

        else if [VehicleSource] = "Stock" then "Stock Vehicle"  

        else "Unknown"),

    #"Add Has VIN" = Table.AddColumn(#"Add Vehicle Type Enhanced", "HasVIN", each

        [VIN] <> null and [VIN] <> "", type logical),

    #"Add Is Active" = Table.AddColumn(#"Add Has VIN", "IsActive", each

        [Status] <> "Inactive" and [Status] <> "Disposed" and [Status] <> "Sold", type logical),

    // Enhanced display name with better formatting

    #"Add Display Name" = Table.AddColumn(#"Add Is Active", "VehicleDisplayName", each

        let

            YearText = if [Year] <> null and [Year] > 1900 then Text.From([Year]) & " " else "",

            MakeModel = [Make] & " " & [Model],

            Identifier = if [Registration] <> "" then " (" & [Registration] & ")"

                        else if [StockNumber] <> "" then " (Stk# " & [StockNumber] & ")"

                        else " (" & [VehicleIdentifier] & ")"

        in

            YearText & MakeModel & Identifier),

    // Add short display name for space-constrained reports

    #"Add Short Display Name" = Table.AddColumn(#"Add Display Name", "VehicleShortName", each

        if [Registration] <> "" then [Registration]

        else if [StockNumber] <> "" then "S" & [StockNumber]  

        else Text.Start([VehicleIdentifier], 10)),

    // Add vehicle category based on make (common fleet categorization)

    #"Add Vehicle Category" = Table.AddColumn(#"Add Short Display Name", "VehicleCategory", each

        let MakeUpper = Text.Upper([Make])

        in if List.Contains({"FORD", "CHEVROLET", "GMC", "DODGE", "RAM"}, MakeUpper) then "Domestic"

        else if List.Contains({"TOYOTA", "HONDA", "NISSAN", "SUBARU", "MAZDA"}, MakeUpper) then "Import"

        else if List.Contains({"CATERPILLAR", "JOHN DEERE", "CASE", "NEW HOLLAND"}, MakeUpper) then "Heavy Equipment"

        else if List.Contains({"FREIGHTLINER", "PETERBILT", "KENWORTH", "VOLVO", "MACK"}, MakeUpper) then "Commercial Truck"

        else "Other"),

    // Final column selection with enhanced fields

    #"Select Final Columns" = Table.SelectColumns(#"Add Vehicle Category", {

        "VehicleKey", "VehicleIdentifier", "PrimaryLookup", "Registration", "StockNumber",

        "VehicleSource", "Make", "Model", "MakeModel", "VIN", "Year", "VehicleAge",

        "AgeCategory", "Engine", "Status", "IsActive", "VehicleTypeEnhanced", "VehicleCategory",

        "HasVIN", "VehicleDisplayName", "VehicleShortName"

    }),

    // Rename columns for consistency

    #"Rename Columns" = Table.RenameColumns(#"Select Final Columns", {

        {"VehicleTypeEnhanced", "VehicleType"}

    }),

    // Set final data types

    #"Set Data Types" = Table.TransformColumnTypes(#"Rename Columns", {

        {"VehicleKey", Int64.Type}, {"VehicleIdentifier", type text}, {"PrimaryLookup", type text},

        {"Registration", type text}, {"StockNumber", type text}, {"VehicleSource", type text},

        {"Make", type text}, {"Model", type text}, {"MakeModel", type text}, {"VIN", type text},

        {"Year", Int64.Type}, {"VehicleAge", Int64.Type}, {"AgeCategory", type text},

        {"Engine", type text}, {"Status", type text}, {"IsActive", type logical},

        {"VehicleType", type text}, {"VehicleCategory", type text}, {"HasVIN", type logical},

        {"VehicleDisplayName", type text}, {"VehicleShortName", type text}

    }),

    // Final sort for consistency

    #"Sort Rows" = Table.Sort(#"Set Data Types", {{"Make", Order.Ascending}, {"Model", Order.Ascending}, {"Year", Order.Descending}})

in

    #"Sort Rows"