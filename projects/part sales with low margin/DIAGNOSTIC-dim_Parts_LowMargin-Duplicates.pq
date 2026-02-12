/*
============================================================================
DIAGNOSTIC: Find Duplicate PartNumbers in dim_Parts_LowMargin Source
============================================================================
Purpose: Identify which PartNumbers have duplicates after Branch+Franchise join
Usage: Run this in Power Query to see what's causing duplicates
============================================================================
*/

let
    Source_InMaster = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_InMaster = Source_InMaster{[Schema="dbo",Item="InMaster"]}[Data],

    InMaster_Fields = Table.SelectColumns(dbo_InMaster, {
        "PartNumber", "Franchise", "Branch", "LowMarginFlag", "StockOrderPrice"
    }),

    Source_jdis = Source_InMaster,
    dbo_jdis = Source_jdis{[Schema="dbo",Item="jdis_Part_Information"]}[Data],

    jdis_Fields = Table.SelectColumns(dbo_jdis, {
        "PartNumber", "Franchise", "Branch",
        "ListPrice", "SellPrice1", "QuantityOnHand", "BulkBinQty", "InventoryCost"
    }),

    MergeInMaster = Table.NestedJoin(
        jdis_Fields,
        {"PartNumber", "Branch", "Franchise"},
        InMaster_Fields,
        {"PartNumber", "Branch", "Franchise"},
        "InMasterData",
        JoinKind.LeftOuter
    ),

    ExpandInMaster = Table.ExpandTableColumn(
        MergeInMaster,
        "InMasterData",
        {"LowMarginFlag", "StockOrderPrice"},
        {"LowMarginFlag", "StockOrderPrice"}
    ),

    CleanFields = Table.TransformColumns(ExpandInMaster, {
        {"PartNumber", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Franchise", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"Branch", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text},
        {"LowMarginFlag", each Text.Upper(Text.Trim(Text.From(_ ?? ""))), type text}
    }),

    RemoveBlankParts = Table.SelectRows(CleanFields, each
        [PartNumber] <> null and [PartNumber] <> ""
    ),

    // Group by PartNumber + Branch + Franchise to find duplicates
    GroupByKey = Table.Group(
        RemoveBlankParts,
        {"PartNumber", "Branch", "Franchise"},
        {
            {"DuplicateCount", each Table.RowCount(_), Int64.Type},
            {"ListPrices", each Text.Combine(List.Transform([ListPrice], each Text.From(_)), ", "), type text},
            {"StockOrderPrices", each Text.Combine(List.Transform([StockOrderPrice], each Text.From(_ ?? "null")), ", "), type text},
            {"InventoryCosts", each Text.Combine(List.Transform([InventoryCost], each Text.From(_)), ", "), type text}
        }
    ),

    // Filter to only duplicates
    FilterToDuplicates = Table.SelectRows(GroupByKey, each [DuplicateCount] > 1),

    // Sort by duplicate count descending
    SortByCount = Table.Sort(FilterToDuplicates, {{"DuplicateCount", Order.Descending}})

in
    SortByCount

/*
============================================================================
INTERPRETATION:
============================================================================

If this returns rows, it means the same PartNumber + Branch + Franchise
combination appears multiple times in jdis_Part_Information.

Possible causes:
1. Multiple inventory locations (Bin vs Bulk Bin as separate rows)
2. Multiple pricing records for same part
3. Historical records not filtered out
4. Data quality issue in source

Look at the columns:
- DuplicateCount: How many times this combination appears
- ListPrices: Are they the same or different?
- StockOrderPrices: Are they the same or different?
- InventoryCosts: Are they the same or different?

If values are all the same: Safe to deduplicate
If values differ: Need to aggregate (SUM, AVG, MIN, MAX, etc.)

============================================================================
*/
