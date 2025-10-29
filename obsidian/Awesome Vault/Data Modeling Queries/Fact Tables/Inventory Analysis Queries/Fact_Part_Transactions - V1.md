let

  Source = Lakehouse.Contents([]),

  #"Navigation 1" = Source{[workspaceId = "b48cdb35-7ce3-46de-96df-d70db77649cb"]}[Data],

  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "3e74497b-8c51-4a1a-91a1-888c59118f48"]}[Data],

  #"Navigation 3" = #"Navigation 2"{[Id = "InTrans", ItemKind = "Table"]}[Data],

  // Existing transformations - rename TradeType from raw source to avoid conflict with customer dimension

  #"Renamed columns" = Table.RenameColumns(#"Navigation 3", {{"TransDatetime", "TransactionDate"}, {"Qty", "Quantity"}, {"SaleValue", "SaleAmount"}, {"CostValue", "CostAmount"}, {"Description", "TransactionDescription"}, {"TradeType", "TransactionTradeType"}}),

  // Add the new columns from raw source (TRADE_TYPE and SELL_PRICE1 should now be available)

  #"Added custom" = Table.AddColumn(#"Renamed columns", "Margin", each [SaleAmount] - [CostAmount]),

  #"Changed column type" = Table.TransformColumnTypes(#"Added custom", {{"Margin", Currency.Type}, {"CostAmount", Currency.Type}, {"SaleAmount", Currency.Type}}),

  #"Added custom 1" = Table.AddColumn(#"Changed column type", "MarginPct", each if [SaleAmount] <> 0 then ([SaleAmount] - [CostAmount]) / [SaleAmount] else null),

  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom 1", {{"MarginPct", Percentage.Type}}),

  #"Renamed columns 1" = Table.RenameColumns(#"Changed column type 1", {{"MarginPct", "MarginPercent"}}),

  // Time intelligence columns

  #"Inserted year" = Table.AddColumn(#"Renamed columns 1", "Year", each Date.Year([TransactionDate]), type nullable number),

  #"Inserted month" = Table.AddColumn(#"Inserted year", "Month", each Date.Month([TransactionDate]), type nullable number),

  #"Renamed columns 2" = Table.RenameColumns(#"Inserted month", {{"Month", "MonthNumber"}}),

  #"Changed column type 2" = Table.TransformColumnTypes(#"Renamed columns 2", {{"TransactionDate", type date}}),

  // Part number cleanup and lookup

  #"Trimmed text" = Table.TransformColumns(#"Changed column type 2", {{"PartNumber", each Text.Trim(_), type nullable text}}),

  #"Cleaned text" = Table.TransformColumns(#"Trimmed text", {{"PartNumber", each Text.Clean(_), type nullable text}}),

  #"Uppercased text" = Table.TransformColumns(#"Cleaned text", {{"PartNumber", each Text.Upper(_), type nullable text}}),

  #"Merged queries" = Table.NestedJoin(#"Uppercased text", {"PartNumber"}, dim_Parts, {"PartNumber"}, "dim_Parts", JoinKind.LeftOuter),

  #"Expanded dim_Parts" = Table.ExpandTableColumn(#"Merged queries", "dim_Parts", {"PartNumberKey"}, {"PartNumberKey"}),

  // Franchise lookup

  #"Uppercased text 1" = Table.TransformColumns(#"Expanded dim_Parts", {{"Franchise", each Text.Upper(_), type nullable text}}),

  #"Merged queries 1" = Table.NestedJoin(#"Uppercased text 1", {"Franchise"}, dim_Franchise, {"Franchise"}, "dim_Franchise", JoinKind.LeftOuter),

  #"Expanded dim_Franchise" = Table.ExpandTableColumn(#"Merged queries 1", "dim_Franchise", {"FranchiseKey"}, {"FranchiseKey"}),

  // NEW: Branch lookup

  #"Standardize Branch ID" = Table.TransformColumns(#"Cleaned Branch", {

    {"Branch", each Text.TrimStart(_, "0"), type text}

}),

  #"Trimmed Branch" = Table.TransformColumns(#"Expanded dim_Franchise", {{"Branch", each Text.Trim(_), type nullable text}}),

  #"Cleaned Branch" = Table.TransformColumns(#"Trimmed Branch", {{"Branch", each Text.Clean(_), type nullable text}}),

  #"Merged Branch" = Table.NestedJoin(#"Standardize Branch ID", {"Branch"}, dim_BranchLocation, {"BranchID"}, "dim_BranchLocation", JoinKind.LeftOuter),

  #"Expanded BranchLocation" = Table.ExpandTableColumn(#"Merged Branch", "dim_BranchLocation", {"BranchKey"}, {"BranchKey"}),

  // Customer lookup (existing)

  #"Merged with Customer" = Table.NestedJoin(#"Expanded BranchLocation", {"CustomerNo"}, dim_CustomerList, {"AccountNumber"}, "CustomerInfo", JoinKind.LeftOuter),

  #"Expanded CustomerKey" = Table.ExpandTableColumn(#"Merged with Customer", "CustomerInfo", {"CustomerKey", "TradeType", "Territory", "PrimaryName"}, {"CustomerKey", "TradeType", "Territory", "PrimaryName"}),

  // NEW: Advanced Calculations from your stakeholder requirements

  // Step 1: Calculate ListSaleVal (what sale would be at list price)

  #"Added custom - ListSaleVal" = Table.AddColumn(#"Expanded BranchLocation", "ListSaleVal", each [ListPrice] * [Quantity]),

  // Step 2: Calculate SellPrice1SaleVal (what sale would be at sell price)

  #"Added custom - SellPriceSaleVal" = Table.AddColumn(#"Added custom - ListSaleVal", "SellPrice1SaleVal", each [SellPrice1] * [Quantity]),

  // Step 3: Calculate % Change (discount from list to sell price)

  #"Added custom - % Change" = Table.AddColumn(#"Added custom - SellPriceSaleVal", "% Change", each

    if [SellPrice1SaleVal] <> 0 then ([SellPrice1SaleVal] - [ListSaleVal]) / [SellPrice1SaleVal] else 0

  ),

  // Step 4: Calculate EffectiveListSalVal with TRADE_TYPE condition

  #"Added custom - EffectiveListSalVal" = Table.AddColumn(#"Added custom - % Change", "EffectiveListSalVal", each

    if [TransactionTradeType] = "W" then

      [SaleAmount]

    else

      [SaleAmount] * (1 - [#"% Change"])

  ),

  // Step 5: Calculate EffectiveListMargin (margin if sold at effective list price)

  #"Added custom - EffectiveListMargin" = Table.AddColumn(#"Added custom - EffectiveListSalVal", "EffectiveListMargin", each [EffectiveListSalVal] - [CostAmount]),

  // Step 6: Calculate EffectiveListMargin% (margin % at effective list price)

  #"Added custom - EffectiveListMargin%" = Table.AddColumn(#"Added custom - EffectiveListMargin", "EffectiveListMargin%", each

    if [EffectiveListSalVal] <> 0 then [EffectiveListMargin] / [EffectiveListSalVal] else 0

  ),

  // Step 7: Calculate MatrixSaleGained (additional sales revenue from pricing)

  #"Added custom - MatrixSaleGained" = Table.AddColumn(#"Added custom - EffectiveListMargin%", "MatrixSaleGained", each [SaleAmount] - [EffectiveListSalVal]),

  // Step 8: Calculate MatrixMarginGained (additional margin from pricing)

  #"Added custom - MatrixMarginGained" = Table.AddColumn(#"Added custom - MatrixSaleGained", "MatrixMarginGained", each [Margin] - [EffectiveListMargin]),

  // Step 9: Set proper data types

  #"Changed column type advanced" = Table.TransformColumnTypes(#"Added custom - MatrixMarginGained", {

    {"ListSaleVal", type number},

    {"SellPrice1SaleVal", type number},

    {"% Change", type number},

    {"EffectiveListSalVal", type number},

    {"EffectiveListMargin", type number},

    {"EffectiveListMargin%", type number},

    {"MatrixSaleGained", type number},

    {"MatrixMarginGained", type number}

  }),

  

  // Add CustomerKey lookup from the SQL-based customer dimension

  #"Merged queries 2" = Table.NestedJoin(#"Changed column type advanced", {"CustomerNo"}, dim_CustomerList, {"AccountNumber"}, "dim_CustomerList", JoinKind.LeftOuter),

  #"Expanded dim_CustomerList" = Table.ExpandTableColumn(#"Merged queries 2", "dim_CustomerList", {"CustomerKey", "TradeType", "Territory", "PrimaryName"}, {"CustomerKey", "TradeType", "Territory", "PrimaryName"}),

  // Rename the customer TradeType to avoid conflict with transaction TradeType

  #"Renamed columns 3" = Table.RenameColumns(#"Expanded dim_CustomerList", {{"TradeType", "CustomerTradeType"}}),

  // Add other calculated fields

  #"Add Sales Type" = Table.AddColumn(#"Renamed columns 3", "SalesType", each

    if Text.Contains([TransactionDescription] ?? "", "Inv No.") then "Work Order"

    else "Over the Counter"

  ),

  #"Add Unique Customer Flag" = Table.AddColumn(#"Add Sales Type", "IsUniqueCustomer", each

    [CustomerTradeType] = "D" or [CustomerTradeType] = "T"

  ),

  #"Add Unique Customer Type" = Table.AddColumn(#"Add Unique Customer Flag", "UniqueCustomerType", each

    if [CustomerTradeType] = "D" then "Pearsall"

    else if [CustomerTradeType] = "T" then "Dell City/Tornillo"

    else null

  ),

  // Time intelligence fields

  #"Add Quarter" = Table.AddColumn(#"Add Unique Customer Type", "Quarter", each Date.QuarterOfYear([TransactionDate])),

  #"Add YearMonth" = Table.AddColumn(#"Add Quarter", "YearMonth", each Date.Year([TransactionDate]) * 100 + Date.Month([TransactionDate])),

  // Final reordering to include all fields including customer dimension

  #"Final Reorder" = Table.ReorderColumns(#"Add YearMonth", {

    "TransactionDate",

    "Branch",

    "BranchKey",           // NEW

    "CustomerNo",

    "CustomerKey",         // From customer dimension

    "CustomerTradeType",   // From customer dimension (renamed to avoid conflict)

    "Territory",           // From customer dimension

    "PrimaryName",         // From customer dimension

    "IsUniqueCustomer",    // Calculated field based on customer dimension

    "UniqueCustomerType",  // Calculated field based on customer dimension

    "SalesType",

    "FranchiseKey",

    "PartNumber",

    "PartNumberKey",

    "Quantity",

    "Type",

    "TransactionTradeType", // From raw source (renamed to avoid conflict)

    "RONumber",

    "TransactionDescription",

    "SaleAmount",

    "CostAmount",

    "Margin",

    "MarginPercent",

    "SellPrice1",          // From raw source

    "ListPrice",           // From raw source

    "ListSaleVal",         // Calculated

    "SellPrice1SaleVal",   // Calculated

    "% Change",            // Calculated

    "EffectiveListSalVal", // Calculated with warranty condition

    "EffectiveListMargin", // Calculated

    "EffectiveListMargin%", // Calculated

    "MatrixSaleGained",    // Calculated

    "MatrixMarginGained",  // Calculated

    "Year",

    "MonthNumber",

    "Quarter",

    "YearMonth"

  }),

  // Clean up - remove original dimension columns if needed

  #"Removed columns" = Table.RemoveColumns(#"Final Reorder", {"Franchise", "Branch"}) // Keep keys, remove original text fields

in

  #"Removed columns"