# Customer Dimension Fix (dim_CustomerList)

## Summary

Fixed many-to-many relationship warning when creating relationship: `Fact_InTrans[CustomerNo]` → `dim_CustomerList[AccountNumber]`

## The Problem

**Error Message:** "This relationship has cardinality Many-Many"

**Root Cause:** dim_CustomerList had duplicate AccountNumber values due to multiple INNER JOINs creating cartesian products in the source query.

---

## Investigation Process

### Initial Attempt
Tried joining on `CustomerNumber` field - got many-to-many warning.

### Second Attempt
Switched to `AccountNumber` field - still got many-to-many warning!

### Root Cause Analysis

The Lakehouse query for dim_CustomerList had multiple INNER JOINs on `ContactID`:

```powerquery
// Multiple JOINs create cartesian products:
JoinArMasterContact = Table.NestedJoin(ArMaster, {"ContactID"}, Raw_Contact, {"ContactID"}, ...)
JoinCustomerMaster = Table.NestedJoin(ExpandContact, {"ContactID"}, Raw_ArMaster_Customer, {"ContactID"}, ...)
JoinContactClass = Table.NestedJoin(ExpandCustomerMaster, {"ContactID"}, Raw_ArMaster_Contact, {"ContactID"}, ...)

// Then CustomerKey added AFTER joins:
AddSurrogateKey = Table.AddIndexColumn(ExpandContactClass, "CustomerKey", 1, 1, Int64.Type)
```

If a single ContactID appears in multiple rows of the joined tables, you get duplicate AccountNumbers before the CustomerKey is assigned.

---

## The Fix

Add deduplication on AccountNumber **BEFORE** adding the CustomerKey:

```powerquery
// After all JOINs, BEFORE adding CustomerKey:
SortByAccountNumber = Table.Sort(ExpandContactClass, {{"AccountNumber", Order.Ascending}}),
DeduplicateAccounts = Table.Distinct(SortByAccountNumber, {"AccountNumber"}),

// THEN add CustomerKey
AddSurrogateKey = Table.AddIndexColumn(DeduplicateAccounts, "CustomerKey", 1, 1, Int64.Type)
```

### Why This Works

1. **Sort first** - Ensures consistent deduplication behavior
2. **Deduplicate on AccountNumber** - Keeps one row per account
3. **Then add surrogate key** - CustomerKey is now unique per AccountNumber
4. **Result** - AccountNumber and CustomerKey both unique, enabling many-to-one relationship

---

## Implementation

### Option A: Update Lakehouse Query

1. Open the Lakehouse pipeline
2. Edit the dim_CustomerList query
3. Add the sorting and deduplication steps before AddSurrogateKey
4. Save and run the pipeline
5. Refresh Power BI report

### Option B: Add Deduplication in Power BI

If you can't modify the Lakehouse query, add deduplication in Power BI:

```powerquery
let
    Source = Lakehouse.dim_CustomerList,
    SortByAccount = Table.Sort(Source, {{"AccountNumber", Order.Ascending}}),
    RemoveDuplicates = Table.Distinct(SortByAccount, {"AccountNumber"})
in
    RemoveDuplicates
```

**Note:** Option A (Lakehouse fix) is preferred because it fixes the dimension for all reports.

---

## Validation

After applying the fix:

### Check for Duplicates
```dax
// Create a test measure
Test Duplicate AccountNumbers =
VAR AllAccounts = VALUES(dim_CustomerList[AccountNumber])
VAR UniqueAccounts = DISTINCTCOUNT(dim_CustomerList[AccountNumber])
VAR RowCount = COUNTROWS(dim_CustomerList)
RETURN
"Total Rows: " & RowCount &
" | Unique Accounts: " & UniqueAccounts &
" | Match: " & IF(RowCount = UniqueAccounts, "YES", "NO")
```

Should show "Match: YES"

### Create Relationship
1. Go to Model View
2. Drag `Fact_InTrans[CustomerNo]` to `dim_CustomerList[AccountNumber]`
3. Should create Many-to-One relationship without warning
4. Delete the test relationship (not needed for this report)

---

## Why dim_CustomerList Isn't Used in This Report

This report doesn't actually use customer dimension filtering, so the relationship isn't created. But the fix ensures it COULD be created if needed in the future.

The old report also didn't use customer dimension - it just had the customer number in the transaction table.

---

## Files

- **Lakehouse Query**: `queries/dimensions/dim_CustomerList.pq` (read-only reference)
- **Fixed Version**: `queries/dimensions/dim_CustomerList_FIXED.pq` (for Lakehouse update)

---

**Status:** Issue identified, fix created, not applied (not needed for this report)
**Impact:** Low (customer dimension not used)
**Priority:** Fix in Lakehouse when convenient
