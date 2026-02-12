let
    Source = InTrans_Incremental,
    
    FilterLast7Days = Table.SelectRows(Source, each 
        [TransDatetime] >= DateTime.From(Date.AddDays(Date.From(DateTime.LocalNow()), -7))
    ),
    
    FilterFranchiseD = Table.SelectRows(FilterLast7Days, each 
        [Franchise] = "D"
    ),
    
    SelectColumns = Table.SelectColumns(FilterFranchiseD, {
        "TransDatetime",
        "Branch",
        "PartNumber",
        "Description",
        "Qty",
        "RONumber",
        "Type",
        "Franchise"
    }),
    
    RenameColumns = Table.RenameColumns(SelectColumns, {
        {"Qty", "QtySold"},
        {"RONumber", "InvoiceNumber"}
    }),
    
    RemoveNullParts = Table.SelectRows(RenameColumns, each 
        [PartNumber] <> null and [PartNumber] <> ""
    ),
    
    // DEDUPLICATION: Remove duplicate transactions
    // Keep unique combinations of Branch + PartNumber + TransDatetime + InvoiceNumber
    RemoveDuplicateTransactions = Table.Distinct(RemoveNullParts, {
        "Branch", "PartNumber", "TransDatetime", "InvoiceNumber"
    }),
    
    SetDataTypes = Table.TransformColumnTypes(RemoveDuplicateTransactions, {
        {"TransDatetime", type datetime},
        {"Branch", type text},
        {"PartNumber", type text},
        {"Description", type text},
        {"QtySold", type number},
        {"InvoiceNumber", type text},
        {"Type", type text},
        {"Franchise", type text}
    })
in
    SetDataTypes