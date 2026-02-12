let
    // Reference the raw parts information table
    Source = Raw_jdis_Part_Information,
    
    // Add flag columns to identify issue types
    AddIssueFlags = Table.AddColumn(
        Table.AddColumn(
            Source,
            "HasNegativeBinQty",
            each [BinQty] < 0,
            type logical
        ),
        "HasBinQtyNoBin",
        each [BinQty] > 0 and ([Bin] = "" or [Bin] = null),
        type logical
    ),
    
    // Add combined issue type column for easy filtering
    AddIssueType = Table.AddColumn(
        AddIssueFlags,
        "IssueType",
        each if [HasNegativeBinQty] and [HasBinQtyNoBin] then "Both Issues"
             else if [HasNegativeBinQty] then "Negative Bin Qty"
             else if [HasBinQtyNoBin] then "On Hand No Bin"
             else "No Issue",
        type text
    ),
    
    // Filter to only include records with issues
    FilterIssuesOnly = Table.SelectRows(
        AddIssueType,
        each [HasNegativeBinQty] = true or [HasBinQtyNoBin] = true
    ),
    
    // Add severity indicator based on bin qty magnitude
    AddSeverity = Table.AddColumn(
        FilterIssuesOnly,
        "IssueSeverity",
        each if [HasNegativeBinQty] then
                if [BinQty] <= -10 then "Critical"
                else if [BinQty] <= -5 then "High"
                else "Medium"
             else if [BinQty] >= 100 then "High Volume"
             else "Standard",
        type text
    ),
    
    // Add inventory value at risk (for negative quantities)
    AddValueAtRisk = Table.AddColumn(
        AddSeverity,
        "InventoryValueAtRisk",
        each if [HasNegativeBinQty] then 
                Number.Abs([BinQty]) * [Cost]
             else 0,
        type number
    ),
    
    // Calculate total available inventory for context
    AddTotalAvailable = Table.AddColumn(
        AddValueAtRisk,
        "TotalAvailableQty",
        each [QuantityOnHand] + [BulkBinQty] - [PendingQty],
        type number
    ),
    
    // Add days since last requested (for priority analysis)
    AddDaysSinceRequested = Table.AddColumn(
        AddTotalAvailable,
        "DaysSinceLastRequest",
        each if [DateLastRequested] <> null then
                Duration.Days(DateTime.LocalNow() - [DateLastRequested])
             else null,
        Int64.Type
    ),
    
    // Select and rename columns for the fact table
    SelectColumns = Table.SelectColumns(
        AddDaysSinceRequested,
        {
            "Branch",
            "PartNumber",
            "Description",
            "Franchise",
            "Source",
            "CommodityCode",
            "Bin",
            "BulkBin",
            "BinQty",
            "QuantityOnHand",
            "BulkBinQty",
            "PendingQty",
            "BackOrderQty",
            "OnOrder",
            "TotalAvailableQty",
            "Cost",
            "SellPrice1",
            "InventoryCost",
            "Current12MoSales",
            "Current12MoDollars",
            "DateCreated",
            "DateLastRequested",
            "DaysSinceLastRequest",
            "VendorCode",
            "HasNegativeBinQty",
            "HasBinQtyNoBin",
            "IssueType",
            "IssueSeverity",
            "InventoryValueAtRisk"
        }
    ),
    
    // Set data types
    SetTypes = Table.TransformColumnTypes(
        SelectColumns,
        {
            {"BinQty", type number},
            {"QuantityOnHand", type number},
            {"BulkBinQty", type number},
            {"PendingQty", type number},
            {"BackOrderQty", type number},
            {"OnOrder", type number},
            {"TotalAvailableQty", type number},
            {"Cost", Currency.Type},
            {"SellPrice1", Currency.Type},
            {"InventoryCost", Currency.Type},
            {"Current12MoSales", type number},
            {"Current12MoDollars", Currency.Type},
            {"InventoryValueAtRisk", Currency.Type}
        }
    )
in
    SetTypes