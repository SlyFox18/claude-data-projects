/*
============================================================================
DIAGNOSTIC: Check for Duplicate AccountNumbers in dim_CustomerList
============================================================================
Purpose: Verify if AccountNumber has duplicates in the Lakehouse dimension
Source: Direct query against dbo.dim_CustomerList in Lakehouse
Output: List of AccountNumbers with duplicate counts
============================================================================
*/

let
    // Connect to Lakehouse dim_CustomerList
    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_dim_CustomerList = Source{[Schema="dbo",Item="dim_CustomerList"]}[Data],

    // Remove special system customers (negative CustomerKey values)
    RemoveSpecialCustomers = Table.SelectRows(dbo_dim_CustomerList, each [CustomerKey] > 0),

    // Group by AccountNumber and count occurrences
    GroupByAccountNumber = Table.Group(
        RemoveSpecialCustomers,
        {"AccountNumber"},
        {
            {"DuplicateCount", each Table.RowCount(_), Int64.Type},
            {"FirstCustomerKey", each List.Min([CustomerKey]), Int64.Type},
            {"LastCustomerKey", each List.Max([CustomerKey]), Int64.Type},
            {"UniqueCustomerNames", each Text.Combine(List.Distinct([CustomerName]), " | "), type text},
            {"UniqueTradeTypes", each Text.Combine(List.Distinct([TradeType]), ", "), type text}
        }
    ),

    // Filter to only duplicates (count > 1)
    FilterToDuplicates = Table.SelectRows(GroupByAccountNumber, each [DuplicateCount] > 1),

    // Sort by duplicate count descending (worst offenders first)
    SortByCount = Table.Sort(FilterToDuplicates, {{"DuplicateCount", Order.Descending}}),

    // Add summary metrics
    TotalDuplicateAccounts = Table.RowCount(SortByCount),
    TotalAffectedRecords = List.Sum(SortByCount[DuplicateCount])

in
    SortByCount

/*
============================================================================
HOW TO INTERPRET RESULTS:
============================================================================

If this query returns:
- 0 rows: No duplicates in AccountNumber! Issue is elsewhere
- >0 rows: AccountNumber has duplicates - needs deduplication in Lakehouse query

Columns returned:
- AccountNumber: The duplicate account number
- DuplicateCount: How many times it appears
- FirstCustomerKey: Lowest CustomerKey (will be kept after deduplication)
- LastCustomerKey: Highest CustomerKey (will be removed after deduplication)
- UniqueCustomerNames: All associated names (check for inconsistencies)
- UniqueTradeTypes: All associated trade types

============================================================================
ROOT CAUSE ANALYSIS:
============================================================================

If duplicates exist, the issue is in the dim_CustomerList.pq query:

PROBLEM: Multiple INNER JOINs on ContactID can create cartesian products

Example scenario:
1. ArMaster has ContactID = "C123" with AccountNumber = "41859"
2. Raw_ArMaster_Customer has TWO rows for ContactID = "C123"
3. After INNER JOIN, you get TWO rows with AccountNumber = "41859"
4. CustomerKey is added AFTER joins, so you get:
   - CustomerKey = 1, AccountNumber = "41859"
   - CustomerKey = 2, AccountNumber = "41859"

SOLUTION: Add deduplication BEFORE adding CustomerKey

============================================================================
*/
