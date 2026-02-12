/*
============================================================================
DIM_CUSTOMERLIST - FIXED WITH DEDUPLICATION
============================================================================
Purpose: Customer dimension with guaranteed unique CustomerNumber
Source: dim_CustomerList from Lakehouse
Issue: CustomerNumber contains duplicates, causing many-to-many relationship
Fix: Add final deduplication on CustomerNumber to ensure one row per customer
============================================================================
*/

let
    // ========================================================================
    // STEP 1: CONNECT TO DIM_CUSTOMERLIST FROM LAKEHOUSE
    // ========================================================================

    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
    dbo_dim_CustomerList = Source{[Schema="dbo",Item="dim_CustomerList"]}[Data],

    // ========================================================================
    // STEP 2: REMOVE BLANK CUSTOMER NUMBERS
    // ========================================================================
    /*
    DATA QUALITY: Remove any records with null or empty CustomerNumber
    These cannot be joined to fact table anyway
    */

    RemoveBlankCustomers = Table.SelectRows(dbo_dim_CustomerList, each
        [CustomerNumber] <> null and [CustomerNumber] <> ""
    ),

    // ========================================================================
    // STEP 3: CLEAN CUSTOMER NUMBER
    // ========================================================================
    /*
    DATA QUALITY: Standardize CustomerNumber for consistent joins
    - Trim whitespace
    - Convert to uppercase for case-insensitive matching
    */

    CleanCustomerNumber = Table.TransformColumns(RemoveBlankCustomers, {
        {"CustomerNumber", each Text.Upper(Text.Trim(_)), type text}
    }),

    // ========================================================================
    // STEP 4: SORT BY CUSTOMERKEY (LOWEST FIRST)
    // ========================================================================
    /*
    DEDUPLICATION STRATEGY: Sort by CustomerKey ascending
    When we deduplicate, we'll keep the FIRST occurrence
    This preserves the lowest CustomerKey for each CustomerNumber
    Consistent with dim_Parts deduplication pattern
    */

    SortByKey = Table.Sort(CleanCustomerNumber, {{"CustomerKey", Order.Ascending}}),

    // ========================================================================
    // STEP 5: FINAL DEDUPLICATION
    // ========================================================================
    /*
    CRITICAL FIX: Ensure absolutely no duplicate CustomerNumber values exist
    REASON: CustomerNumber is on the "one" side of relationship - must be unique
    APPROACH: Keep first occurrence of each CustomerNumber (preserves lowest CustomerKey)
    PERFORMANCE: Minimal impact on refresh time
    */

    FinalDeduplication = Table.Distinct(SortByKey, {"CustomerNumber"})

in
    FinalDeduplication

/*
============================================================================
RELATIONSHIP TO CREATE IN POWER BI:
============================================================================

Fact_InTrans[CustomerNo] → dim_CustomerList[CustomerNumber] (ACTIVE, Many-to-One)

NOTE: Column names don't match exactly:
- Fact table uses: CustomerNo
- Dim table uses: CustomerNumber

This is intentional - the relationship will still work correctly.

============================================================================
VALIDATION QUERIES:
============================================================================

-- Check for duplicates in source (expect > 0):
SELECT CustomerNumber, COUNT(*) as Cnt
FROM dbo.dim_CustomerList
WHERE CustomerNumber IS NOT NULL AND CustomerNumber <> ''
GROUP BY CustomerNumber
HAVING COUNT(*) > 1
ORDER BY Cnt DESC

-- After deduplication (expect 0):
-- Should have exactly one row per CustomerNumber

============================================================================
TRADE TYPE COLUMN:
============================================================================

The TradeType column is already in dim_CustomerList (line 109-115 in TMDL).
This matches what was in the old report's ArMaster_Customer_Low table.
No additional work needed for TradeType.

============================================================================
*/
