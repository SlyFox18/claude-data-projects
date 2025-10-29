let

    Source = AllJobCodes,

    // Clean and standardize job codes

    #"Clean JobCode" = Table.AddColumn(Source, "CleanJobCode", each

        Text.Upper(Text.Trim([JobCode] ?? ""))),

    // Define inspection job codes

    InspectionJobCodes = {

        "/COMBINE VIP INSPECT", "/CS690 INSPECTION", "/CS690 VIP INSPECTIO", "/INSPECTION",

        "/PLANTER INSPECTION", "/Rental Inspection", "/SPRAYER INSPECTION", "/TRACTOR INSPECTION",

        "/WINTER INSPECTION", "ALL/9001/LEG/590", "COMBINE INSPECTION", "IS-125", "IS-145",

        "IS-3E ANNUAL SERVICE", "IS-4X2", "IS-5E INSPECT", "IS-AMS DATA", "IS-AMS DATA SETUP",

        "IS-AMS OPTIMIZE", "IS-AMS SOFTWARE", "IS-COMBINE INSPECT", "IS-COMPACT INSPECT",

        "IS-CORN/DRAPER", "IS-CP690 INSPECT", "IS-CP770 INSPECT", "IS-CS690 INSPECT",

        "IS-CS770 INSPECT", "IS-D100", "IS-D105(-200000)", "IS-D105(200001-)", "IS-D110(-500000)",

        "IS-D110(500001-)", "IS-D120", "IS-D125", "IS-D130(-400000)", "IS-D130(400001-)",

        "IS-D140(-400000)", "IS-D140(400001-)", "IS-D155(700001-)", "IS-D160", "IS-D170",

        "IS-E100", "IS-E120", "IS-E120-QCD", "IS-E130-QCD", "IS-E170-QCD", "IS-E180-QCD",

        "IS-GATOR INSPECTION", "IS-HPX(-040000)", "IS-HPX(040001-)", "IS-L110", "IS-L130",

        "IS-LA115", "IS-LA125", "IS-LA135", "IS-LT150(039001-)", "IS-LT160", "IS-LT166",

        "IS-LT180", "IS-MOWER INSPECTION", "IS-PICKER INSPECT", "IS-PLANTER INSPECT",

        "IS-PLATFORM INSP", "IS-PRE R INSPECTION", "IS-R INSPECTION", "IS-S240",

        "IS-SKID STEER INSPEC", "IS-SPRAYER INSPECT", "IS-STRIPPER INSPECT", "IS-SWATHER INSPECT",

        "IS-TRACTOR INSPECT", "IS-TS4X2", "IS-X300(-180000)", "IS-X300(180001-)",

        "IS-X300R(120001-)", "IS-X304(180001-)", "IS-X310", "IS-X320(-180000)",

        "IS-X324(-180000)", "IS-X350", "IS-X354", "IS-X360(-180000)", "IS-X380", "IS-X500",

        "IS-X570", "IS-XUV550", "IS-XUV560", "IS-XUV590I", "IS-XUV590M", "IS-XUV835R",

        "IS-XUV855D", "IS-Z225(-060000)", "IS-Z225(100001-12000", "IS-Z255", "IS-Z335E",

        "IS-Z345M", "IS-Z345R", "IS-Z355E", "IS-Z355R", "IS-Z375R", "IS-Z425(-040000)",

        "IS-Z425(100001-)", "IS-Z425(40001-100000", "IS-Z435", "IS-Z445(-100000)",

        "IS-Z445(100000-14000", "IS-Z445(140001-)", "IS-Z515E", "IS-Z525E", "IS-Z535M",

        "IS-Z540M", "IS-Z540R"

    },

    // Add inspection indicator

    #"Add IsInspection" = Table.AddColumn(#"Clean JobCode", "IsInspection", each

        List.Contains(InspectionJobCodes, [CleanJobCode]), type logical),

    // Add job code category

    #"Add JobCodeCategory" = Table.AddColumn(#"Add IsInspection", "JobCodeCategory", each

        let Code = [CleanJobCode]

        in if [IsInspection] then "Inspection"

        else if Text.Contains(Code, "REPAIR") or Text.Contains(Code, "FIX") then "Repair"

        else if Text.Contains(Code, "SERVICE") or Text.Contains(Code, "MAINT") then "Service"

        else if Text.Contains(Code, "SETUP") or Text.Contains(Code, "CONFIG") then "Setup"

        else if Text.Contains(Code, "INSTALL") or Text.Contains(Code, "MOUNT") then "Installation"

        else if Text.Contains(Code, "DIAGNOS") or Text.Contains(Code, "TROUBL") then "Diagnostic"

        else if Text.Contains(Code, "WARR") then "Warranty"

        else if Text.Contains(Code, "RECALL") then "Recall"

        else "Other"),

    // Add equipment type

    #"Add EquipmentType" = Table.AddColumn(#"Add JobCodeCategory", "EquipmentType", each

        let Code = [CleanJobCode]

        in if Text.Contains(Code, "COMBINE") or Text.Contains(Code, "HARVESTER") then "Combine"

        else if Text.Contains(Code, "TRACTOR") or Text.Contains(Code, "TRACT") then "Tractor"

        else if Text.Contains(Code, "PLANTER") or Text.Contains(Code, "PLANT") then "Planter"

        else if Text.Contains(Code, "SPRAYER") or Text.Contains(Code, "SPRAY") then "Sprayer"

        else if Text.Contains(Code, "MOWER") or Text.Contains(Code, "MOW") then "Mower"

        else if Text.Contains(Code, "GATOR") then "Gator"

        else if Text.Contains(Code, "SKID") or Text.Contains(Code, "LOADER") then "Skid Steer"

        else if Text.Contains(Code, "XUV") or Text.Contains(Code, "UTV") then "Utility Vehicle"

        else if Text.Contains(Code, "PICKER") or Text.Contains(Code, "PICK") then "Picker"

        else if Text.Contains(Code, "SWATHER") or Text.Contains(Code, "WINDROWER") then "Swather"

        else if Text.Contains(Code, "DRILL") or Text.Contains(Code, "SEEDER") then "Drill/Seeder"

        else if Text.Contains(Code, "DISC") or Text.Contains(Code, "TILLAGE") then "Tillage"

        else if Text.Contains(Code, "BALER") or Text.Contains(Code, "HAY") then "Hay Equipment"

        else if Text.Contains(Code, "ENGINE") or Text.Contains(Code, "MOTOR") then "Engine/Power"

        else "General"),

    // Add equipment category

    #"Add EquipmentCategory" = Table.AddColumn(#"Add EquipmentType", "EquipmentCategory", each

        let EquipType = [EquipmentType]

        in if List.Contains({"Combine", "Picker"}, EquipType) then "Harvest Equipment"

        else if List.Contains({"Tractor", "Engine/Power"}, EquipType) then "Power Units"

        else if List.Contains({"Planter", "Drill/Seeder"}, EquipType) then "Planting Equipment"

        else if List.Contains({"Sprayer"}, EquipType) then "Application Equipment"

        else if List.Contains({"Mower", "Swather", "Baler", "Hay Equipment"}, EquipType) then "Hay/Forage Equipment"

        else if List.Contains({"Disc", "Tillage"}, EquipType) then "Tillage Equipment"

        else if List.Contains({"Gator", "Utility Vehicle"}, EquipType) then "Utility Vehicles"

        else if List.Contains({"Skid Steer"}, EquipType) then "Construction Equipment"

        else "Other Equipment"),

    // Add service complexity

    #"Add ServiceComplexity" = Table.AddColumn(#"Add EquipmentCategory", "ServiceComplexity", each

        if [IsInspection] then "Low"

        else if List.Contains({"Setup", "Installation"}, [JobCodeCategory]) then "High"

        else if List.Contains({"Diagnostic", "Repair"}, [JobCodeCategory]) then "Medium"

        else if [JobCodeCategory] = "Service" then "Low"

        else "Medium"),

    // Add business flags

    #"Add IsSeasonalWork" = Table.AddColumn(#"Add ServiceComplexity", "IsSeasonalWork", each

        let Code = [CleanJobCode]

        in Text.Contains(Code, "HARVEST") or Text.Contains(Code, "PLANT") or

           Text.Contains(Code, "SPRING") or Text.Contains(Code, "FALL") or

           List.Contains({"Planting Equipment", "Harvest Equipment", "Application Equipment"}, [EquipmentCategory]), type logical),

    #"Add IsWarrantyWork" = Table.AddColumn(#"Add IsSeasonalWork", "IsWarrantyWork", each

        Text.Contains([CleanJobCode], "WARR") or Text.Contains([CleanJobCode], "RECALL"), type logical),

    #"Add IsUrgentWork" = Table.AddColumn(#"Add IsWarrantyWork", "IsUrgentWork", each

        let Code = [CleanJobCode]

        in Text.Contains(Code, "EMERG") or Text.Contains(Code, "URGENT") or

           Text.Contains(Code, "PRIORITY") or Text.Contains(Code, "RUSH"), type logical),

    // Add display names

    #"Add JobCodeDisplayName" = Table.AddColumn(#"Add IsUrgentWork", "JobCodeDisplayName", each

        [CleanJobCode] & " (" & [JobCodeCategory] & ")"),

    #"Add JobCodeShortDesc" = Table.AddColumn(#"Add JobCodeDisplayName", "JobCodeShortDesc", each

        [JobCodeCategory] & " - " & [EquipmentType]),

    // Select final columns for deduplication

    #"Select Columns" = Table.SelectColumns(#"Add JobCodeShortDesc", {

        "CleanJobCode", "JobCodeDisplayName", "JobCodeShortDesc", "JobCodeCategory",

        "EquipmentType", "EquipmentCategory", "ServiceComplexity", "IsInspection",

        "IsWarrantyWork", "IsSeasonalWork", "IsUrgentWork"

    }),

    // CRITICAL: Remove duplicates BEFORE adding surrogate key

    #"Remove Duplicates" = Table.Distinct(#"Select Columns", {"CleanJobCode"}),

    // NOW add the surrogate key - each unique JobCode gets exactly one key

    #"Add JobCodeKey" = Table.AddIndexColumn(#"Remove Duplicates", "JobCodeKey", 1, 1, Int64.Type),

    // Reorder columns

    #"Reorder Columns" = Table.ReorderColumns(#"Add JobCodeKey", {

        "JobCodeKey", "CleanJobCode", "JobCodeDisplayName", "JobCodeShortDesc", "JobCodeCategory",

        "EquipmentType", "EquipmentCategory", "ServiceComplexity", "IsInspection",

        "IsWarrantyWork", "IsSeasonalWork", "IsUrgentWork"

    }),

    // Rename CleanJobCode to JobCode

    #"Rename JobCode" = Table.RenameColumns(#"Reorder Columns", {{"CleanJobCode", "JobCode"}}),

    // Set data types

    #"Set Data Types" = Table.TransformColumnTypes(#"Rename JobCode", {

        {"JobCodeKey", Int64.Type}, {"JobCode", type text}, {"JobCodeDisplayName", type text},

        {"JobCodeShortDesc", type text}, {"JobCodeCategory", type text}, {"EquipmentType", type text},

        {"EquipmentCategory", type text}, {"ServiceComplexity", type text}, {"IsInspection", type logical},

        {"IsWarrantyWork", type logical}, {"IsSeasonalWork", type logical}, {"IsUrgentWork", type logical}

    }),

    // Final sort

    #"Sort Rows" = Table.Sort(#"Set Data Types", {

        {"JobCodeCategory", Order.Ascending},

        {"EquipmentType", Order.Ascending},

        {"JobCode", Order.Ascending}

    })

in

    #"Sort Rows"