/*
============================================================================
DIAGNOSTIC: Find Duplicate CustomerNumbers in dim_CustomerList
============================================================================
Purpose: Identify which CustomerNumbers have duplicate records
Usage: Run this query in Power BI to see the extent of duplication
Output: List of CustomerNumbers with duplicate counts
============================================================================
*/

let
    // Connect to source
    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_dim_CustomerList = Source{[Schema="dbo",Item="dim_CustomerList"]}[Data],

    // Remove blanks
    RemoveBlankCustomers = Table.SelectRows(dbo_dim_CustomerList, each
        [CustomerNumber] <> null and [CustomerNumber] <> ""
    ),

    // Clean CustomerNumber
    CleanCustomerNumber = Table.TransformColumns(RemoveBlankCustomers, {
        {"CustomerNumber", each Text.Upper(Text.Trim(_)), type text}
    }),

    // Group by CustomerNumber and count occurrences
    GroupedRows = Table.Group(
        CleanCustomerNumber,
        {"CustomerNumber"},
        {
            {"DuplicateCount", each Table.RowCount(_), Int64.Type},
            {"FirstCustomerKey", each List.Min([CustomerKey]), Int64.Type},
            {"LastCustomerKey", each List.Max([CustomerKey]), Int64.Type},
            {"CustomerNames", each Text.Combine(List.Distinct([CustomerName]), ", "), type text}
        }
    ),

    // Filter to only duplicates (count > 1)
    FilterToDuplicates = Table.SelectRows(GroupedRows, each [DuplicateCount] > 1),

    // Sort by duplicate count descending (worst offenders first)
    SortByCount = Table.Sort(FilterToDuplicates, {{"DuplicateCount", Order.Descending}}),

    // Add total row count for context
    TotalDuplicates = Table.RowCount(SortByCount),
    TotalAffectedRecords = List.Sum(SortByCount[DuplicateCount])

in
    SortByCount

/*
============================================================================
HOW TO INTERPRET RESULTS:
============================================================================

If this query returns:
- 0 rows: No duplicates! (Unexpected - means the source table is already clean)
- <10 rows: Minor duplication, easy to review manually
- 10-100 rows: Moderate duplication, deduplication fix is essential
- >100 rows: Significant duplication, deduplication fix is critical

Columns returned:
- CustomerNumber: The duplicate customer number
- DuplicateCount: How many times it appears
- FirstCustomerKey: Lowest CustomerKey for this CustomerNumber (will be kept after deduplication)
- LastCustomerKey: Highest CustomerKey for this CustomerNumber (will be removed after deduplication)
- CustomerNames: All associated customer names (to check for data inconsistencies)

============================================================================
NEXT STEPS:
============================================================================

1. Review the top 10-20 duplicate CustomerNumbers
2. Check if CustomerNames are consistent (same CustomerNumber should have same name)
3. Apply the dim_CustomerList_FIXED.pq query to resolve duplicates
4. After applying fix, re-run this diagnostic (should return 0 rows)

============================================================================
*/
