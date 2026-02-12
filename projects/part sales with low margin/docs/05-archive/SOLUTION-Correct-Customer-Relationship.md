# Solution: Correct Customer Relationship Configuration

## Issue Summary

You got a many-to-many relationship warning when trying to join:
- `Fact_InTrans[CustomerNo]` → `dim_CustomerList[CustomerNumber]`

However, **your dim_CustomerList is correctly built and does NOT need deduplication**.

## Root Cause

You're joining on the **wrong column**. The `CustomerNo` in your fact table corresponds to `AccountNumber`, not `CustomerNumber`.

### Understanding the Two Columns

**dim_CustomerList** has two customer identifier columns:

1. **`AccountNumber`** ✅ CORRECT CHOICE
   - Source: AR Master account number
   - **UNIQUE** - One per customer account
   - This is what `Fact_InTrans[CustomerNo]` contains
   - Used in invoice transactions

2. **`CustomerNumber`** ❌ WRONG CHOICE
   - Source: `Raw_ArMaster_Customer.CustomerNumber`
   - **NOT UNIQUE** - Can have duplicates (multiple contacts per customer)
   - This is a secondary identifier from customer details
   - NOT used in transactional systems

## Evidence from Old Report

Your old report (archive) used this relationship:
```
fromColumn: InTrans_Low_Margin.'Customer No'
toColumn: ArMaster_Customer_Low.Customer_No
```

In AR/ERP systems, `customer_no` always refers to the **Account Number** (AR account), which is unique per customer.

## Correct Solution

**Change the relationship to:**
```
Fact_InTrans[CustomerNo] → dim_CustomerList[AccountNumber]
```

### Steps to Fix

1. **Delete the existing relationship** (if you already created it)
   - Go to Model view in Power BI Desktop
   - Find the line between Fact_InTrans and dim_CustomerList
   - Right-click → Delete

2. **Create the correct relationship:**
   - Drag `Fact_InTrans[CustomerNo]`
   - Drop on `dim_CustomerList[AccountNumber]`
   - Verify:
     - Cardinality: **Many-to-One** (*:1)
     - Cross filter direction: Single
     - Make this relationship active: ✅ Checked

3. **Verify the relationship works:**
   - Create a table visual with:
     - `Fact_InTrans[RONumber]`
     - `dim_CustomerList[CustomerName]`
     - `[Sale $]`
   - Customer names should populate correctly

## Why This Works

- `Fact_InTrans[CustomerNo]` contains AR account numbers from invoice transactions
- `dim_CustomerList[AccountNumber]` contains unique AR account numbers
- These match perfectly in a many-to-one relationship

## No Changes Needed to Lakehouse

**Important**: Your `dim_CustomerList` query in the Lakehouse is **correctly built**. Do NOT add deduplication.

The query properly:
- ✅ Creates unique `CustomerKey` surrogate keys
- ✅ Includes both `AccountNumber` (unique) and `CustomerNumber` (can have duplicates)
- ✅ Adds special system customers
- ✅ Provides comprehensive customer attributes

The "duplicates" in `CustomerNumber` are **expected and correct** - they represent customers with multiple contact records.

## Files Created (Can be Ignored)

These files were created based on the initial assumption that CustomerNumber needed deduplication:
- ❌ `dim_CustomerList_FIXED.pq` - NOT NEEDED
- ❌ `FIX-dim_CustomerList-ManyToMany.md` - NOT NEEDED
- ❌ `DIAGNOSTIC-dim_CustomerList-Duplicates.pq` - NOT NEEDED

You can delete these files. The actual solution is simply using the correct column in the relationship.

## Validation

After fixing the relationship:

```dax
// Count distinct customers in transactions
Distinct Customers = DISTINCTCOUNT(Fact_InTrans[CustomerNo])

// This should match:
Distinct Accounts = DISTINCTCOUNT(dim_CustomerList[AccountNumber])

// And NOT match:
Distinct CustomerNumbers = DISTINCTCOUNT(dim_CustomerList[CustomerNumber])
// ^ This will be larger due to multiple contacts per account
```

## Summary

- ✅ **dim_CustomerList is correct** - no changes needed in Lakehouse
- ✅ **Join on AccountNumber**, not CustomerNumber
- ✅ **Relationship will be Many-to-One** (no warning)
- ❌ **Do NOT add deduplication** to the Lakehouse query
