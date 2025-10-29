let

    Source = ref_InTrans,

    // CREATE customer lookup from ArMaster

    CustomerLookup = Table.SelectRows(ref_ArMaster_Customer, each

        [TradeType] = "D" or [TradeType] = "T"

    ),

    // Convert CustomerNumber to text to match InTrans CustomerNo

    ConvertCustomerNumber = Table.TransformColumns(CustomerLookup, {{"CustomerNumber", each Text.From(_), type text}}),

    CustomerDedup = Table.Distinct(Table.SelectColumns(ConvertCustomerNumber, {"CustomerNumber", "TradeType"})),

    // JOIN InTrans (text) to ArMaster (converted to text)

    JoinCustomer = Table.NestedJoin(Source, {"CustomerNo"}, CustomerDedup, {"CustomerNumber"}, "CustomerInfo", JoinKind.Inner),

    ExpandCustomer = Table.ExpandTableColumn(JoinCustomer, "CustomerInfo", {"TradeType"}, {"Customer_TradeType"}),

    // Filter out Type P transactions (inventory purchases)

    FilteredRows = Table.SelectRows(ExpandCustomer, each [Type] <> "P"),

// Add CustomerKey using CUSTOMER Trade Type and Branch

AddCustomerKey = Table.AddColumn(FilteredRows, "CustomerKey", each

    if [Customer_TradeType] = "D" then 1  // Pearsall

    else if [Customer_TradeType] = "T" and [Branch] = "2" then 3  // Tornillo

    else if [Customer_TradeType] = "T" and [Branch] <> "2" then 2  // Dell City

    else null, Int64.Type

),

    // Add Sales Type logic

    AddSalesType = Table.AddColumn(AddCustomerKey, "SalesType", each

        if Text.Contains([Description] ?? "", "Inv No.") then "Work Order"

        else "Over the Counter", type text

    ),

    // JOIN to get BranchKey from dimension

    JoinBranch = Table.NestedJoin(AddSalesType, {"Branch"}, ref_dim_BranchLocation, {"BranchID"}, "BranchInfo", JoinKind.LeftOuter),

    ExpandBranch = Table.ExpandTableColumn(JoinBranch, "BranchInfo", {"BranchKey"}, {"BranchKey"}),

    // DATE KEY for Star Schema

    AddDateKey = Table.AddColumn(ExpandBranch, "DateKey", each

        Date.Year(DateTime.Date([TransDatetime])) * 10000 +

        Date.Month(DateTime.Date([TransDatetime])) * 100 +

        Date.Day(DateTime.Date([TransDatetime])), Int64.Type),

    // TIME INTELLIGENCE ENHANCEMENTS

    AddYear = Table.AddColumn(AddDateKey, "TransactionYear", each Date.Year([TransDatetime]), Int64.Type),

    AddMonth = Table.AddColumn(AddYear, "TransactionMonth", each Date.Month([TransDatetime]), Int64.Type),

    AddQuarter = Table.AddColumn(AddMonth, "TransactionQuarter", each Date.QuarterOfYear([TransDatetime]), Int64.Type),

    AddYearMonth = Table.AddColumn(AddQuarter, "TransactionYearMonth", each Date.Year([TransDatetime]) * 100 + Date.Month([TransDatetime]), Int64.Type),

    // BUSINESS CALCULATIONS

    AddMarginAmount = Table.AddColumn(AddYearMonth, "MarginAmount", each [SaleValue] - [CostValue], type number),

    AddMarginPercent = Table.AddColumn(AddMarginAmount, "MarginPercent", each

        if [SaleValue] <> 0 then ([SaleValue] - [CostValue]) / [SaleValue] else 0, type number),

    // UNIQUE TRANSACTION KEY (for incremental refresh)

    AddTransactionKey = Table.AddColumn(AddMarginPercent, "TransactionKey", each

        Text.Combine({

            Text.From([Branch]),

            Text.From([DateKey]),

            [RONumber] ?? "",

            [PartNumber] ?? "",

            Text.From([CustomerNo])

        }, "_"), type text),

    // Select final columns

    SelectedColumns = Table.SelectColumns(AddTransactionKey, {

        "TransactionKey", "DateKey", "TransDatetime",

        "TransactionYear", "TransactionMonth", "TransactionQuarter", "TransactionYearMonth",

        "Branch", "BranchKey", "CustomerNo", "CustomerKey",

        "Franchise", "PartNumber", "Description", "Qty", "Type", "TradeType",

        "RONumber", "SaleValue", "CostValue", "MarginAmount", "MarginPercent",

        "SellPrice1", "ListPrice", "SalesType"

    })

in

    SelectedColumns