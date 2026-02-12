/*
============================================================================
TEST VERSION - dim_Parts WITHOUT InMaster JOIN
============================================================================
Purpose: Test if the InMaster JOIN is the performance bottleneck
Use this to compare preview times and isolate the slow operation
============================================================================
*/

let
    Source = jdis_Part_Information,

    // Remove blank part numbers FIRST
    RemoveBlankPartsEarly = Table.SelectRows(Source, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Deduplicate EARLY
    DeduplicateEarly = Table.Distinct(RemoveBlankPartsEarly, {"PartNumber"}),

    SelectColumns = Table.SelectColumns(DeduplicateEarly, {
        "PartNumber", "Description", "Franchise",
        "Source", "SLC", "DealerGroupCode", "CommodityCode", "VendorCode",
        "QuantityOnHand", "BackOrderQty", "Returnable",
        "InventoryCost", "SellPrice1", "ListPrice",
        "Current12MoSales"
    }),

    // Consolidated text cleaning - ALL in one pass
    CleanAllTextFields = Table.TransformColumns(SelectColumns, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Description", each Text.Proper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Source", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"SLC", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"DealerGroupCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"CommodityCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"VendorCode", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Returnable", each Text.Upper(Text.Trim(Text.From(_ ?? "N"))), type text}
    }),

    // Add calculated columns
    AddStockStatus = Table.AddColumn(CleanAllTextFields, "StockStatus", each
        if ([QuantityOnHand] ?? 0) > 0 then "In Stock"
        else if ([BackOrderQty] ?? 0) > 0 then "Backordered"
        else "Out of Stock",
        type text
    ),

    AddIsAvailable = Table.AddColumn(AddStockStatus, "IsAvailable", each
        ([QuantityOnHand] ?? 0) > 0,
        type logical
    ),

    AddHasRecentSales = Table.AddColumn(AddIsAvailable, "HasRecentSales", each
        ([Current12MoSales] ?? 0) > 0,
        type logical
    ),

    AddActivityStatus = Table.AddColumn(AddHasRecentSales, "ActivityStatus", each
        if [HasRecentSales] then "Active" else "No Recent Sales",
        type text
    ),

    AddIsReturnable = Table.AddColumn(AddActivityStatus, "IsReturnable", each
        [Returnable] = "Y",
        type logical
    ),

    AddIsHighValue = Table.AddColumn(AddIsReturnable, "IsHighValue", each
        ([InventoryCost] ?? 0) >= 500,
        type logical
    ),

    SortByPartNumber = Table.Sort(AddIsHighValue, {{"PartNumber", Order.Ascending}}),

    AddSurrogateKey = Table.AddIndexColumn(SortByPartNumber, "PartNumberKey", 1, 1, Int64.Type)

in
    AddSurrogateKey

/*
============================================================================
TEST INSTRUCTIONS:
============================================================================

1. Preview this query and time how long it takes
2. Compare to v2 query (with InMaster JOIN)
3. This will tell us if the InMaster JOIN is the bottleneck

Expected results:
- If this is MUCH faster (< 1 minute): InMaster JOIN is the bottleneck
- If this is similar speed (~2.5 min): The AddColumn operations are the bottleneck
- If this is slower: Something else is wrong

============================================================================
*/
