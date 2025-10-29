let

    Source = Raw_BranchOperational,

  #"Replaced value" = Table.ReplaceValue(Source, null, "11", Replacer.ReplaceValue, {"LocationID"}),

  #"Capitalized each word" = Table.TransformColumns(#"Replaced value", {{"City", each Text.Proper(_), type nullable text}}),

  #"Replaced value 1" = Table.ReplaceValue(#"Capitalized each word", "Odonnell", "O'Donnell", Replacer.ReplaceValue, {"City"}),

  #"Added custom" = Table.AddColumn(#"Replaced value 1", "Branch", each [LocationID] & " - " & [City]),

  #"Replaced value 2" = Table.ReplaceValue(#"Added custom", "01 - Seminole", "1 - Seminole", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 3" = Table.ReplaceValue(#"Replaced value 2", "02 - Tornillo", "2 - Tornillo", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 4" = Table.ReplaceValue(#"Replaced value 3", "03 - Denver City", "3 - Denver City", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 5" = Table.ReplaceValue(#"Replaced value 4", "04 - Mesquite", "4 - Mesquite", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 6" = Table.ReplaceValue(#"Replaced value 5", "04 - Las Cruces", "4 - Las Cruces", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 7" = Table.ReplaceValue(#"Replaced value 6", "05 - Deming", "5 - Deming", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 8" = Table.ReplaceValue(#"Replaced value 7", "06 - San Angelo", "6 - San Angelo", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 9" = Table.ReplaceValue(#"Replaced value 8", "07 - Ballinger", "7 - Ballinger", Replacer.ReplaceValue, {"Branch"}),

  #"Replaced value 10" = Table.ReplaceValue(#"Replaced value 9", "08 - Big Spring", "8 - Big Spring", Replacer.ReplaceValue, {"Branch"}),

  #"Sorted rows" = Table.Sort(#"Replaced value 10", {{"Branch", Order.Ascending}}),

  #"Removed top rows" = Table.Skip(#"Sorted rows", 30),

  #"Added custom 1" = Table.AddColumn(#"Removed top rows", "BranchType", each let

    Name = Text.Upper([BranchName]),

    Code = [BranchID]

in

    if Text.Contains(Name, "IS SHOP") or Text.EndsWith(Code, "I") then "IS Shop"

    else if Text.Contains(Name, "SET-UP SHOP") or Text.EndsWith(Code, "S") then "Set-Up Shop"

    else if Text.Contains(Name, "CP SHOP") or Text.EndsWith(Code, "C") then "CP Shop"

    else "Main Branch"),

  #"Added index" = Table.AddIndexColumn(#"Added custom 1", "Index", 1, 1, Int64.Type),

  #"Renamed columns" = Table.RenameColumns(#"Added index", {{"Index", "BranchKey"}}),

  #"Reordered columns" = Table.ReorderColumns(#"Renamed columns", {"BranchKey", "Branch", "BranchType", "BranchID", "BranchName", "LocationID", "State", "City"}),

  #"Changed column type" = Table.TransformColumnTypes(#"Reordered columns", {{"Branch", type text}, {"BranchType", type text}})

in

    #"Changed column type"