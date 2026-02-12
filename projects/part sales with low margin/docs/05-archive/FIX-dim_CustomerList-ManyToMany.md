# FIX: dim_CustomerList Many-to-Many Relationship Warning

## Problem

When creating a relationship between `Fact_InTrans[CustomerNo]` and `dim_CustomerList[CustomerNumber]`, Power BI warns that the cardinality is **Many-to-Many** instead of the expected **Many-to-One**.

**Root Cause**: `CustomerNumber` contains duplicate values in `dim_CustomerList`, violating the requirement that the "one" side of a many-to-one relationship must have unique values.

## Error Screenshot

User reported: "it want to make it a many to many relationship"

## Solution

Add **deduplication** to the `dim_CustomerList` Power Query to ensure `CustomerNumber` is unique, following the same pattern we used for `dim_Parts`.

### Changes Applied

1. **Remove blank CustomerNumbers** - Filter out null or empty values
2. **Clean CustomerNumber** - Trim whitespace and convert to uppercase for consistent joins
3. **Sort by CustomerKey** - Ascending order (lowest first)
4. **Final deduplication** - Keep first occurrence per CustomerNumber (preserves lowest CustomerKey)

### Updated Query

See: `dim_CustomerList_FIXED.pq`

Key changes:
```powerquery
// Remove blanks
RemoveBlankCustomers = Table.SelectRows(dbo_dim_CustomerList, each
    [CustomerNumber] <> null and [CustomerNumber] <> ""
),

// Clean and standardize
CleanCustomerNumber = Table.TransformColumns(RemoveBlankCustomers, {
    {"CustomerNumber", each Text.Upper(Text.Trim(_)), type text}
}),

// Sort by key
SortByKey = Table.Sort(CleanCustomerNumber, {{"CustomerKey", Order.Ascending}}),

// Deduplicate (CRITICAL FIX)
FinalDeduplication = Table.Distinct(SortByKey, {"CustomerNumber"})
```

## How to Apply

1. **Close Power BI Desktop** (critical - prevents file lock/overwrite)
2. Open Power Query Editor in Power BI Desktop
3. Find `dim_CustomerList` query
4. Replace the query with content from `dim_CustomerList_FIXED.pq`
5. Click "Close & Apply"
6. Verify refresh succeeds
7. Create the relationship: `Fact_InTrans[CustomerNo]` → `dim_CustomerList[CustomerNumber]`
8. Verify relationship is now **Many-to-One** (not Many-to-Many)

## Relationship Details

**From**: `Fact_InTrans[CustomerNo]` (Many side)
**To**: `dim_CustomerList[CustomerNumber]` (One side)
**Cardinality**: Many-to-One
**Cross Filter Direction**: Single (from fact to dimension)
**Active**: Yes

**Note**: Column names don't match exactly (`CustomerNo` vs `CustomerNumber`), but this is intentional and the relationship works correctly.

## TradeType Column

The `TradeType` column is already present in `dim_CustomerList` (line 109-115 in the TMDL file). This matches what was in the old report's `ArMaster_Customer_Low` table. No additional work needed.

## Performance Impact

Deduplication adds minimal refresh time (<5 seconds), similar to the `dim_Parts` fix. This is essential for data quality and relationship integrity.

## Validation

After applying the fix:

1. **Check row count** - Should decrease if duplicates existed
2. **Verify relationship** - Should show Many-to-One, not Many-to-Many
3. **Test visuals** - Customer name and TradeType should display correctly
4. **Compare to old report** - Verify customer-related metrics match

## Related Files

- `dim_CustomerList_FIXED.pq` - Updated Power Query with deduplication
- `dim_CustomerList.tmdl` - Current table definition (lines 29-35 show CustomerNumber column)
- `Fact_InTrans.tmdl` - Fact table with CustomerNo column (line 54)

## Pattern

This fix follows the exact same pattern as the `dim_Parts` duplicate fix:
1. Remove blanks
2. Clean/standardize key column
3. Sort by surrogate key
4. Deduplicate on business key

This ensures dimension integrity across all reports using these tables.
