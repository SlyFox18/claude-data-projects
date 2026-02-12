# Analysis: CustomerNo Mapping in Fact_InTrans

## Problem Statement

When creating relationship `Fact_InTrans[CustomerNo]` → `dim_CustomerList[CustomerNumber]`, Power BI warns about Many-to-Many cardinality.

This doesn't happen in other reports using dim_CustomerList.

## Root Cause Analysis

### dim_CustomerList Structure

The dim_CustomerList has TWO customer identifier columns:

1. **`AccountNumber`** (Line 434)
   - Source: `Raw_ARMaster.AccountNumber`
   - Description: "Primary business account identifier"
   - **UNIQUE** - One per customer account
   - This is the AR (Accounts Receivable) account number

2. **`CustomerNumber`** (Line 436)
   - Source: `Raw_ArMaster_Customer.CustomerNumber` (Line 124)
   - Description: "Secondary customer identifier"
   - **NOT UNIQUE** - Can have duplicates
   - This is from a separate customer details table

### Why CustomerNumber Has Duplicates

The query uses **INNER JOINs** on `ContactID`:
```powerquery
// Line 96-99: ArMaster → Contact
JoinArMasterContact = Table.NestedJoin(
    ArMaster, {"ContactID"},
    Raw_Contact, {"ContactID"},
    "ContactInfo", JoinKind.Inner),

// Line 117-120: → ArMaster_Customer
JoinCustomerMaster = Table.NestedJoin(
    ExpandContact, {"ContactID"},
    Raw_ArMaster_Customer, {"ContactID"},
    "CustomerInfo", JoinKind.Inner),
```

If multiple `ContactID` records have the same `CustomerNumber` in `Raw_ArMaster_Customer`, the dimension will have duplicate `CustomerNumber` values.

### Fact_InTrans CustomerNo Source

From `InTrans_Incremental.pq` (Line 20):
```sql
customer_no AS CustomerNo
```

**Key Question**: Does `customer_no` in the raw InTrans table correspond to:
- Option A: `AccountNumber` (unique AR account)
- Option B: `CustomerNumber` (non-unique customer detail)

## Why Other Reports Don't Have This Issue

Other reports likely use one of these approaches:
1. **Join on AccountNumber**: `Fact_XXX[CustomerNo]` → `dim_CustomerList[AccountNumber]` ✅
2. **Join on CustomerKey**: `Fact_XXX[CustomerKey]` → `dim_CustomerList[CustomerKey]` ✅
3. **Use AccountNumberText**: Text-based joins on account numbers

## Solution Options

### Option 1: Change Relationship Column (RECOMMENDED)

**If `Fact_InTrans[CustomerNo]` = `AccountNumber`**:

Change the relationship to:
- `Fact_InTrans[CustomerNo]` → `dim_CustomerList[AccountNumber]`

This is likely correct because:
- AccountNumber is unique (one per AR account)
- InTrans transactions are tied to AR accounts
- Matches pattern from other reports

### Option 2: Fix dim_CustomerList Query (NOT RECOMMENDED)

Add deduplication on CustomerNumber in the Lakehouse query.

**Why NOT recommended**:
- CustomerNumber might legitimately have duplicates in source data
- Would lose valid customer records
- Doesn't fix the underlying mapping issue

### Option 3: Investigate Source Data

Check the InTrans raw table to understand what `customer_no` actually represents:
```sql
SELECT DISTINCT customer_no
FROM InTrans_Incremental
WHERE customer_no IS NOT NULL
LIMIT 100
```

Compare against:
```sql
SELECT AccountNumber, CustomerNumber
FROM dbo.ArMaster
LIMIT 100
```

## Recommended Action

1. **Check existing relationships** in other reports that use dim_CustomerList
2. **Verify** which column they join on (likely AccountNumber)
3. **Change this report's relationship** to match the working pattern
4. **Test** that customer names appear correctly in the report

## Validation Query

After fixing, verify the relationship:
```dax
CustomerCount = DISTINCTCOUNT(Fact_InTrans[CustomerNo])
// Should match distinct count in dim_CustomerList[AccountNumber]
// Should NOT match distinct count in dim_CustomerList[CustomerNumber]
```

## Files Referencing This

- `dim_CustomerList.pq` (Lines 124, 434, 436)
- `Fact_InTrans_PowerBI.pq` (Line 20 source mapping)
- `InTrans_Incremental.pq` (Line 20: customer_no source)
