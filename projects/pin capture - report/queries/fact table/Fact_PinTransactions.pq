let
    // Connect to Lakehouse
    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InTrans_Incremental = Source{[Schema="dbo",Item="InTrans_Incremental"]}[Data],
    
    // Filter to last 24 months (rolling window) - DO THIS EARLY!
    TwoYearsAgo = DateTime.From(Date.AddMonths(Date.StartOfMonth(DateTime.Date(DateTime.LocalNow())), -24)),
    FilteredDate = Table.SelectRows(dbo_InTrans_Incremental, each [TransDatetime] >= TwoYearsAgo),
    
    // Filter to Invoice (I) and Credit (C) transactions only
    FilteredType = Table.SelectRows(FilteredDate, each [Type] = "I" or [Type] = "C"),
    
    // Add calculated Margin column
    AddMargin = Table.AddColumn(FilteredType, "Margin", each [SaleValue] - [CostValue], type number),
    
    // *** ADD JOIN KEY TO INTRANS ***
    AddInTransKey = Table.AddColumn(AddMargin, "JoinKey",
        each Text.From([RONumber]) & "|" & [Branch],
        type text),
    
    // *** LOAD AND PREPARE WKOTHSUB LOOKUP (DISTINCT INVOICE NUMBERS ONLY) ***
    dbo_wkothsub = Source{[Schema="dbo",Item="wkothsub"]}[Data],
    
    // Filter to only records with invoice numbers (reduces dataset significantly)
    WkOthSubWithInvoices = Table.SelectRows(dbo_wkothsub, 
        each [InvoiceNumber] <> null and [InvoiceNumber] <> ""),
    
    // Get distinct Invoice|Branch combinations only (reduces from 103K to ~38K rows)
    DistinctWorkOrders = Table.Distinct(
        Table.SelectColumns(WkOthSubWithInvoices, {"InvoiceNumber", "Branch"}),
        {"InvoiceNumber", "Branch"}
    ),
    
    // Add join key to work orders
    AddWOKey = Table.AddColumn(DistinctWorkOrders, "JoinKey",
        each Text.From([InvoiceNumber]) & "|" & [Branch],
        type text),
    
    // Add flag column to identify work orders
    AddWOFlag = Table.AddColumn(AddWOKey, "IsWorkOrder", each true, type logical),
    
    // *** LEFT JOIN TO IDENTIFY WORK ORDERS (MUCH FASTER THAN LIST LOOKUP) ***
    MergeWorkOrders = Table.NestedJoin(
        AddInTransKey,
        {"JoinKey"},
        AddWOFlag,
        {"JoinKey"},
        "WorkOrderMatch",
        JoinKind.LeftOuter
    ),
    
    // *** EXPAND TO GET WORK ORDER FLAG ***
    ExpandWorkOrder = Table.ExpandTableColumn(MergeWorkOrders, "WorkOrderMatch", 
        {"IsWorkOrder"}, 
        {"IsWorkOrder"}),
    
    // *** CREATE INVOICE_TYPE COLUMN ***
    AddInvoiceType = Table.AddColumn(ExpandWorkOrder, "Invoice_Type",
        each if [IsWorkOrder] = true then "Work Order" else "Invoice",
        type text),
    
    // Remove temporary columns
    RemoveTempColumns = Table.RemoveColumns(AddInvoiceType, {"JoinKey", "IsWorkOrder"}),
    
    // Select only columns needed
    SelectColumns = Table.SelectColumns(RemoveTempColumns, {
        "TransDatetime",
        "Branch",
        "Franchise",
        "RONumber",
        "FileNo",
        "PartNumber",
        "Description",
        "SaleValue",
        "CostValue",
        "Margin",
        "PinNo",
        "Notation",
        "Qty",
        "CustomerNo",
        "TradeType",
        "JobCode",
        "JobType",
        "Type",
        "Invoice_Type"
    }),
    
    // Set data types
    TypedColumns = Table.TransformColumnTypes(SelectColumns, {
        {"TransDatetime", type datetime},
        {"Branch", type text},
        {"Franchise", type text},
        {"RONumber", type text},
        {"FileNo", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"SaleValue", type number},
        {"CostValue", type number},
        {"Margin", type number},
        {"PinNo", type text},
        {"Notation", type text},
        {"Qty", type number},
        {"CustomerNo", type text},
        {"TradeType", type text},
        {"JobCode", type text},
        {"JobType", type text},
        {"Type", type text},
        {"Invoice_Type", type text}
    }),
    
    // *** REMOVE DUPLICATE ROWS ***
    RemoveDuplicates = Table.Distinct(TypedColumns, {
        "TransDatetime",
        "RONumber", 
        "PartNumber",
        "Branch",
        "Qty",
        "SaleValue",
        "CostValue"
    }),
    
    #"Extracted Date" = Table.TransformColumns(RemoveDuplicates,{{"TransDatetime", DateTime.Date, type date}})
in
    #"Extracted Date"