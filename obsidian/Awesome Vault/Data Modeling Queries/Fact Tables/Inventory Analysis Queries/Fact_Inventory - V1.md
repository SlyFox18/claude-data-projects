let

  Source = Lakehouse.Contents([]),

  #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],

  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],

  #"Navigation 3" = #"Navigation 2"{[Id = "jdis_Part_Information", ItemKind = "Table"]}[Data],

  #"Choose columns" = Table.SelectColumns(#"Navigation 3", {"Branch", "Franchise", "PartNumber", "Source", "SLC", "DealerGroupCode", "Description", "CommodityCode", "VendorCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "Returnable", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "ListPrice", "DateCreated", "DateLastRequested"}),

  #"Filtered rows" = Table.SelectRows(#"Choose columns", each [InventoryCost] <> 0),

  #"Reordered columns" = Table.ReorderColumns(#"Filtered rows", {"Branch", "PartNumber", "Description", "Franchise", "VendorCode", "Source", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  // Branch dimension lookup - added here

  #"Trimmed Branch" = Table.TransformColumns(#"Reordered columns", {{"Branch", each Text.Trim(_), type nullable text}}),

  #"Cleaned Branch" = Table.TransformColumns(#"Trimmed Branch", {{"Branch", each Text.Clean(_), type nullable text}}),

  #"Merged Branch" = Table.NestedJoin(#"Cleaned Branch", {"Branch"}, dim_BranchLocation, {"BranchID"}, "dim_BranchLocation", JoinKind.LeftOuter),

  #"Expanded BranchLocation" = Table.ExpandTableColumn(#"Merged Branch", "dim_BranchLocation", {"BranchKey"}, {"BranchKey"}),

  #"Reordered with Branch" = Table.ReorderColumns(#"Expanded BranchLocation", {"Branch", "BranchKey", "PartNumber", "Description", "Franchise", "VendorCode", "Source", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  // Continue with existing transformations

  #"Trimmed text" = Table.TransformColumns(#"Reordered with Branch", {{"PartNumber", each Text.Trim(_), type nullable text}}),

  #"Cleaned text" = Table.TransformColumns(#"Trimmed text", {{"PartNumber", each Text.Clean(_), type nullable text}}),

  #"Uppercased text" = Table.TransformColumns(#"Cleaned text", {{"PartNumber", each Text.Upper(_), type nullable text}}),

  #"Merged queries" = Table.NestedJoin(#"Uppercased text", {"PartNumber"}, dim_Parts, {"PartNumber"}, "dim_Parts", JoinKind.LeftOuter),

  #"Expanded dim_Parts" = Table.ExpandTableColumn(#"Merged queries", "dim_Parts", {"PartNumberKey"}, {"PartNumberKey"}),

  #"Reordered columns 1" = Table.ReorderColumns(#"Expanded dim_Parts", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "VendorCode", "Source", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Trimmed text 1" = Table.TransformColumns(#"Reordered columns 1", {{"Franchise", each Text.Trim(_), type nullable text}}),

  #"Cleaned text 1" = Table.TransformColumns(#"Trimmed text 1", {{"Franchise", each Text.Clean(_), type nullable text}}),

  #"Uppercased text 1" = Table.TransformColumns(#"Cleaned text 1", {{"Franchise", each Text.Upper(_), type nullable text}}),

  #"Merged queries 1" = Table.NestedJoin(#"Uppercased text 1", {"Franchise"}, dim_Franchise, {"Franchise"}, "dim_Franchise", JoinKind.LeftOuter),

  #"Expanded dim_Franchise" = Table.ExpandTableColumn(#"Merged queries 1", "dim_Franchise", {"FranchiseKey"}, {"FranchiseKey"}),

  #"Reordered columns 2" = Table.ReorderColumns(#"Expanded dim_Franchise", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "Source", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Merged queries 2" = Table.NestedJoin(#"Reordered columns 2", {"VendorCode"}, dim_VendorCode, {"VendorCode"}, "dim_VendorCode", JoinKind.LeftOuter),

  #"Expanded dim_VendorCode" = Table.ExpandTableColumn(#"Merged queries 2", "dim_VendorCode", {"VendorCodeKey"}, {"VendorCodeKey"}),

  #"Reordered columns 3" = Table.ReorderColumns(#"Expanded dim_VendorCode", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "VendorCodeKey", "Source", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Replaced value" = Table.ReplaceValue(#"Reordered columns 3", "", "UNKNOWN", Replacer.ReplaceValue, {"Source"}),

  #"Trimmed text 2" = Table.TransformColumns(#"Replaced value", {{"Source", each Text.Trim(_), type nullable text}}),

  #"Cleaned text 2" = Table.TransformColumns(#"Trimmed text 2", {{"Source", each Text.Clean(_), type nullable text}}),

  #"Merged queries 3" = Table.NestedJoin(#"Cleaned text 2", {"Source"}, dim_Source, {"Source"}, "dim_Source", JoinKind.LeftOuter),

  #"Expanded dim_Source" = Table.ExpandTableColumn(#"Merged queries 3", "dim_Source", {"SourceKey"}, {"SourceKey"}),

  #"Reordered columns 4" = Table.ReorderColumns(#"Expanded dim_Source", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "VendorCodeKey", "Source", "SourceKey", "SLC", "DealerGroupCode", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Trimmed text 3" = Table.TransformColumns(#"Reordered columns 4", {{"DealerGroupCode", each Text.Trim(_), type nullable text}}),

  #"Cleaned text 3" = Table.TransformColumns(#"Trimmed text 3", {{"DealerGroupCode", each Text.Clean(_), type nullable text}}),

  #"Replaced value 1" = Table.ReplaceValue(#"Cleaned text 3", "", "UNKNOWN", Replacer.ReplaceValue, {"DealerGroupCode"}),

  #"Merged queries 4" = Table.NestedJoin(#"Replaced value 1", {"DealerGroupCode"}, dim_DealerGroupCode, {"DealerGroupCode"}, "dim_DealerGroupCode", JoinKind.LeftOuter),

  #"Expanded dim_DealerGroupCode" = Table.ExpandTableColumn(#"Merged queries 4", "dim_DealerGroupCode", {"DealerGroupKey"}, {"DealerGroupKey"}),

  #"Reordered columns 5" = Table.ReorderColumns(#"Expanded dim_DealerGroupCode", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "VendorCodeKey", "Source", "SourceKey", "SLC", "DealerGroupCode", "DealerGroupKey", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Trimmed text 4" = Table.TransformColumns(#"Reordered columns 5", {{"SLC", each Text.Trim(_), type nullable text}}),

  #"Cleaned text 4" = Table.TransformColumns(#"Trimmed text 4", {{"SLC", each Text.Clean(_), type nullable text}}),

  #"Replaced value 2" = Table.ReplaceValue(#"Cleaned text 4", "", "UNKNOWN", Replacer.ReplaceValue, {"SLC"}),

  #"Merged queries 5" = Table.NestedJoin(#"Replaced value 2", {"SLC"}, dim_SLC, {"SLC"}, "dim_SLC", JoinKind.LeftOuter),

  #"Expanded dim_SLC" = Table.ExpandTableColumn(#"Merged queries 5", "dim_SLC", {"SLCKey"}, {"SLCKey"}),

  #"Reordered columns 6" = Table.ReorderColumns(#"Expanded dim_SLC", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "VendorCodeKey", "Source", "SourceKey", "SLC", "SLCKey", "DealerGroupCode", "DealerGroupKey", "CommodityCode", "InventoryCost", "BinQty", "QuantityOnHand", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Trimmed text 5" = Table.TransformColumns(#"Reordered columns 6", {{"CommodityCode", each Text.Trim(_), type nullable text}}),

  #"Cleaned text 5" = Table.TransformColumns(#"Trimmed text 5", {{"CommodityCode", each Text.Clean(_), type nullable text}}),

  #"Replaced value 3" = Table.ReplaceValue(#"Cleaned text 5", "", "UNKNOWN", Replacer.ReplaceValue, {"CommodityCode"}),

  #"Merged queries 6" = Table.NestedJoin(#"Replaced value 3", {"CommodityCode"}, dim_CommodityCode, {"CommodityCode"}, "dim_CommodityCode", JoinKind.LeftOuter),

  #"Expanded dim_CommodityCode" = Table.ExpandTableColumn(#"Merged queries 6", "dim_CommodityCode", {"CommodityCodeKey"}, {"CommodityCodeKey"}),

  #"Reordered columns 7" = Table.ReorderColumns(#"Expanded dim_CommodityCode", {"Branch", "BranchKey", "PartNumber", "PartNumberKey", "Description", "Franchise", "FranchiseKey", "VendorCode", "VendorCodeKey", "Source", "SourceKey", "SLC", "SLCKey", "DealerGroupCode", "DealerGroupKey", "CommodityCode", "CommodityCodeKey", "InventoryCost", "BinQty", "QuantityOnHand", "Returnable", "BackOrderQty", "SellPrice1", "Cost", "Current12MoSales", "Current12MoDollars", "Previous12MoSales", "Previous12MoDollars", "DateCreated", "DateLastRequested"}),

  #"Removed columns" = Table.RemoveColumns(#"Reordered columns 7", {"CommodityCode", "DealerGroupCode", "SLC", "Source", "VendorCode", "Franchise", "Branch"})

in

  #"Removed columns"